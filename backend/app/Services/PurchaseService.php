<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\Product;
use App\Models\PurchaseInvoice;
use App\Models\StockMovement;
use App\Models\Supplier;
use App\Models\SupplierPayment;
use App\Models\User;
use App\Support\Money;
use App\Support\Pack;
use App\Support\Quantity;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Goods received from a supplier: one transaction creates the new products, adds the stock, writes
 * the invoice and its lines, and records what was paid. The total always comes from the lines.
 */
class PurchaseService
{
    public function __construct(
        private readonly ProductService $products,
        private readonly StockService $stock,
        private readonly AuditService $audit,
    ) {}

    public function record(User $user, array $data): PurchaseInvoice
    {
        return DB::transaction(function () use ($user, $data) {
            $supplier = $this->supplierFor($user, $data);
            $lines = array_map(fn(array $line) => $this->priced($line, $user), $data['lines']);
            $total = Money::sum(array_column($lines, 'line_total'));
            $paid = Money::of($data['paid_amount'] ?? 0);

            if (Money::compare($paid, $total) > 0) {
                throw ValidationException::withMessages(['paid_amount' => ['المدفوع أكبر من الإجمالي.']]);
            }

            $invoice = PurchaseInvoice::create([
                'store_id' => $user->store_id,
                'supplier_id' => $supplier->id,
                'total' => $total,
                'created_by' => $user->id,
            ]);

            foreach ($lines as $line) {
                $product = $this->productFor($user, $line);
                $this->stock->move(
                    $product,
                    StockMovement::TYPE_PURCHASE,
                    $line['quantity'],
                    $user,
                    "فاتورة مورد #{$invoice->id}",
                    'purchase_invoice',
                    $invoice->id,
                );
                $invoice->items()->create([
                    'product_id' => $product->id,
                    'quantity' => $line['quantity'],
                    'cartons' => $line['cartons'],
                    'pack_size' => $line['pack_size'],
                    'loose_pieces' => $line['loose_pieces'],
                    'buy_price' => $line['buy_price'],
                    'line_total' => $line['line_total'],
                ]);
            }

            // Older apps still send what was paid with the delivery.
            if (Money::isPositive($paid)) {
                SupplierPayment::create([
                    'store_id' => $user->store_id,
                    'supplier_id' => $supplier->id,
                    'purchase_invoice_id' => $invoice->id,
                    'amount' => $paid,
                    'method' => $data['method'] ?? 'cash',
                    'created_by' => $user->id,
                ]);
            }

            $this->audit->record('purchase.recorded', $invoice, [
                'supplier_id' => $supplier->id,
                'total' => $total,
                'paid' => $paid,
                'lines' => count($lines),
            ]);

            return $invoice->load(['supplier', 'items.product', 'payments']);
        });
    }

    /** A payment to the supplier: it lowers the total owed to them. */
    public function pay(User $user, Supplier $supplier, string $amount, string $method): SupplierPayment
    {
        return DB::transaction(function () use ($user, $supplier, $amount, $method) {
            $locked = Supplier::query()->whereKey($supplier->id)->lockForUpdate()->firstOrFail();

            if (Money::compare($amount, $locked->balance()) > 0) {
                throw ValidationException::withMessages(['amount' => ['الدفعة أكبر من المبلغ المتبقي.']]);
            }

            $payment = SupplierPayment::create([
                'store_id' => $user->store_id,
                'supplier_id' => $locked->id,
                'amount' => Money::of($amount),
                'method' => $method,
                'created_by' => $user->id,
            ]);
            $this->audit->record('supplier.paid', $payment, ['supplier_id' => $locked->id, 'amount' => $payment->amount, 'method' => $method]);

            return $payment;
        });
    }

    /**
     * Voids a delivery recorded by mistake. The goods it added leave the shelf again
     * (`purchase_void`), the payments made with it are voided, and the invoice leaves the
     * supplier's balance. Every row stays, marked voided with the reason, time and user.
     *
     * Refused (409, nothing written): a second void; returns still standing on it (cancel them
     * first); goods no longer on the shelf; or later payments that would leave the store having
     * paid the supplier more than it owes (void those payments first). Lock order: supplier,
     * invoice, its payments, then products by id.
     */
    public function void(User $actor, PurchaseInvoice $invoice, string $reason): PurchaseInvoice
    {
        return DB::transaction(function () use ($actor, $invoice, $reason) {
            $supplier = Supplier::query()->forStore($actor->store_id)->whereKey($invoice->supplier_id)->lockForUpdate()->firstOrFail();
            $locked = PurchaseInvoice::query()->forStore($actor->store_id)->whereKey($invoice->id)->lockForUpdate()->firstOrFail();

            if ($locked->isVoided()) {
                throw ApiException::conflict('PURCHASE_ALREADY_VOIDED', 'هذه الفاتورة ملغاة مسبقًا.');
            }

            if ($locked->returns()->notVoided()->exists()) {
                throw ApiException::conflict('PURCHASE_HAS_RETURNS', 'على هذه الفاتورة مرتجعات قائمة. ألغِ المرتجعات أولًا ثم ألغِ الفاتورة.');
            }

            $payments = $locked->payments()->notVoided()->lockForUpdate()->get();
            $paidWithIt = Money::sum($payments->pluck('amount'));
            $after = Money::add(Money::sub($supplier->balance(), $locked->total), $paidWithIt);

            if (Money::compare($after, '0') < 0) {
                throw ApiException::conflict(
                    'PURCHASE_VOID_OVERPAID',
                    'دفعات لاحقة للمورد تغطي هذه الفاتورة؛ إلغاؤها يجعل المدفوع أكثر من المستحق. ألغِ الدفعة الزائدة أولًا.'
                );
            }

            $removed = $this->takeBackStock($actor, $locked, $reason);

            foreach ($payments as $payment) {
                $payment->markVoided($actor, $reason);
            }
            $locked->markVoided($actor, $reason);

            $this->audit->record('purchase.voided', $locked, [
                'supplier_id' => $supplier->id,
                'reason' => $reason,
                'total' => Money::of($locked->total),
                'payments_voided' => $payments->pluck('id')->all(),
                'paid_voided' => $paidWithIt,
                'stock_removed' => $removed,
            ], $actor);

            return $locked->load(['supplier', 'creator', 'voider', 'items.product', 'payments']);
        });
    }

    /** Voids a supplier payment recorded by mistake: the amount is owed to the supplier again. */
    public function voidPayment(User $actor, SupplierPayment $payment, string $reason): SupplierPayment
    {
        return DB::transaction(function () use ($actor, $payment, $reason) {
            $supplier = Supplier::query()->forStore($actor->store_id)->whereKey($payment->supplier_id)->lockForUpdate()->firstOrFail();
            $locked = SupplierPayment::query()->forStore($actor->store_id)->whereKey($payment->id)->lockForUpdate()->firstOrFail();

            if ($locked->isVoided()) {
                throw ApiException::conflict('PAYMENT_ALREADY_VOIDED', 'هذه الدفعة ملغاة مسبقًا.');
            }

            $locked->markVoided($actor, $reason);

            $this->audit->record('supplier_payment.voided', $locked, [
                'supplier_id' => $supplier->id,
                'purchase_invoice_id' => $locked->purchase_invoice_id,
                'amount' => Money::of($locked->amount),
                'method' => $locked->method,
                'reason' => $reason,
            ], $actor);

            return $locked;
        });
    }

    /** @return list<array{product_id: int, quantity: string}> what left the shelf */
    private function takeBackStock(User $actor, PurchaseInvoice $invoice, string $reason): array
    {
        $added = StockMovement::query()
            ->where('store_id', $actor->store_id)
            ->where('reference_type', 'purchase_invoice')
            ->where('reference_id', $invoice->id)
            ->where('type', StockMovement::TYPE_PURCHASE)
            ->orderBy('product_id')
            ->get()
            ->groupBy('product_id');

        $removed = [];

        foreach ($added as $productId => $movements) {
            $quantity = Quantity::negate($movements->reduce(fn(string $sum, StockMovement $m) => Quantity::add($sum, $m->quantity), '0'));
            $product = Product::query()->forStore($actor->store_id)->findOrFail($productId);

            try {
                $this->stock->move($product, StockMovement::TYPE_PURCHASE_VOID, $quantity, $actor, $reason, 'purchase_invoice', $invoice->id);
            } catch (ApiException $e) {
                $available = Quantity::format($product->fresh()->current_stock, $product->unit);
                throw new ApiException(409, 'PURCHASE_STOCK_CONSUMED',
                    "لا يمكن إلغاء الفاتورة: بضاعة «{$product->name}» منها لم تعد كلها في المخزون (المتوفر الآن {$available}). صحّح المخزون أولًا ثم أعد المحاولة.",
                    details: ['product_id' => $product->id, 'cause' => $e->errorCode],
                );
            }

            $removed[] = ['product_id' => (int) $productId, 'quantity' => Quantity::format($quantity, $product->unit)];
        }

        return $removed;
    }

    /**
     * An existing supplier by id, or by name typed in the goods flow (created the first time).
     * A new delivery brings an archived supplier back to the list.
     */
    private function supplierFor(User $user, array $data): Supplier
    {
        $supplier = $this->findOrCreateSupplier($user, $data);

        if ($supplier->isArchived()) {
            $supplier->forceFill(['status' => Supplier::STATUS_ACTIVE])->save();
        }

        return $supplier;
    }

    private function findOrCreateSupplier(User $user, array $data): Supplier
    {
        if (!empty($data['supplier_id'])) {
            return Supplier::query()->forStore($user->store_id)->findOrFail($data['supplier_id']);
        }

        $attributes = ['store_id' => $user->store_id, 'name' => trim($data['supplier_name'])];

        try {
            return DB::transaction(fn() => Supplier::firstOrCreate($attributes));
        } catch (UniqueConstraintViolationException) {
            return Supplier::query()->where($attributes)->firstOrFail();
        }
    }

    /** The line with its stock quantity, its total and the cost of one unit. */
    private function priced(array $line, User $user): array
    {
        $existing = $this->existingProduct($user, $line);
        $unit = $existing?->unit ?? $line['unit'] ?? Quantity::UNIT_PIECE;
        $buyPrice = Money::of($line['buy_price']);

        if ($unit === Quantity::UNIT_KG) {
            $quantity = Quantity::of((string) $line['quantity']);

            return array_merge($line, [
                'existing' => $existing,
                'unit' => $unit,
                'quantity' => $quantity,
                'cartons' => null,
                'pack_size' => null,
                'loose_pieces' => 0,
                'line_total' => Money::times($buyPrice, $quantity),
                'unit_cost' => $buyPrice,
            ]);
        }

        $packSize = (int) ($line['pack_size'] ?? $existing?->pack_size ?? 1);
        $cartons = (int) $line['cartons'];
        // Pieces of an opened carton cost their share of the carton price.
        $loose = (int) ($line['loose_pieces'] ?? 0);
        $pieces = $cartons * $packSize + $loose;

        return array_merge($line, [
            'existing' => $existing,
            'unit' => $unit,
            'quantity' => Quantity::of((string) $pieces),
            'cartons' => $cartons,
            'pack_size' => $packSize,
            'loose_pieces' => $loose,
            'line_total' => Money::of(bcdiv(bcmul($buyPrice, (string) $pieces, 2), (string) $packSize, 6)),
            'unit_cost' => Money::of(bcdiv($buyPrice, (string) $packSize, 4)),
        ]);
    }

    private function existingProduct(User $user, array $line): ?Product
    {
        $query = Product::query()->forStore($user->store_id);

        return match (true) {
            !empty($line['product_id']) => $query->findOrFail($line['product_id']),
            !empty($line['barcode']) => $query->where('barcode', $line['barcode'])->first(),
            default => null,
        };
    }

    /** The new product, or the existing one with this delivery's prices and carton. */
    private function productFor(User $user, array $line): Product
    {
        $selling = $line['selling_price'] ?? $line['existing']?->selling_price;
        $carton = $this->carton($line, $selling);

        if ($line['existing'] === null) {
            return $this->products->create($user, [
                'name' => trim($line['name']),
                'barcode' => $line['barcode'] ?? null,
                'unit' => $line['unit'],
                'selling_price' => $selling,
                'cost_price' => $line['unit_cost'],
                'current_stock' => 0,
                ...$carton,
            ]);
        }

        /** @var Product $product */
        $product = $line['existing'];
        $product->update([
            'cost_price' => $line['unit_cost'],
            'selling_price' => $selling,
            'status' => Product::STATUS_ACTIVE,
            ...$carton,
        ]);

        return $product;
    }

    /**
     * A carton of 2 or more sells wholesale at the price typed on the supplier step. Without one
     * it keeps its price, or starts at the full piece price. One "carton" of 1 is a piece.
     */
    private function carton(array $line, mixed $selling): array
    {
        if ($line['unit'] === Quantity::UNIT_KG || $line['pack_size'] < Pack::MIN_SIZE) {
            return [];
        }

        if (!blank($line['carton_price'] ?? null)) {
            return ['pack_size' => $line['pack_size'], 'pack_price' => Money::of($line['carton_price'])];
        }

        $keeps = $line['existing']?->pack_size === $line['pack_size']
            && Pack::problems(Quantity::UNIT_PIECE, $line['pack_size'], $line['existing']->pack_price, $selling) === [];

        return [
            'pack_size' => $line['pack_size'],
            'pack_price' => $keeps ? $line['existing']->pack_price : Money::times($selling, $line['pack_size']),
        ];
    }
}
