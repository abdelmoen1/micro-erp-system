<?php

namespace App\Services;

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
                    'buy_price' => $line['buy_price'],
                    'line_total' => $line['line_total'],
                ]);
            }

            // Apps from before payments moved to each product still send what was paid.
            $this->payLines($user, $supplier, $invoice, $paid, $data['method'] ?? 'cash');

            $this->audit->record('purchase.recorded', $invoice, [
                'supplier_id' => $supplier->id,
                'total' => $total,
                'paid' => $paid,
                'lines' => count($lines),
            ]);

            return $invoice->load(['supplier', 'items.product', 'payments']);
        });
    }

    /** A payment on one product's account with this supplier. */
    public function pay(User $user, Supplier $supplier, int $productId, string $amount, string $method): SupplierPayment
    {
        return DB::transaction(function () use ($user, $supplier, $productId, $amount, $method) {
            $locked = Supplier::query()->whereKey($supplier->id)->lockForUpdate()->firstOrFail();

            if (Money::compare($amount, $locked->productBalance($productId)) > 0) {
                throw ValidationException::withMessages(['amount' => ['الدفعة أكبر من المبلغ المتبقي.']]);
            }

            $payment = SupplierPayment::create([
                'store_id' => $user->store_id,
                'supplier_id' => $locked->id,
                'product_id' => $productId,
                'amount' => Money::of($amount),
                'method' => $method,
                'created_by' => $user->id,
            ]);
            $this->audit->record('supplier.paid', $payment, ['supplier_id' => $locked->id, 'product_id' => $productId, 'amount' => $payment->amount, 'method' => $method]);

            return $payment;
        });
    }

    /** What was paid with the invoice, line by line in order: payments belong to a product. */
    private function payLines(User $user, Supplier $supplier, PurchaseInvoice $invoice, string $paid, string $method): void
    {
        foreach ($invoice->items as $item) {
            if (!Money::isPositive($paid)) {
                return;
            }
            $amount = Money::compare($paid, $item->line_total) > 0 ? Money::of($item->line_total) : $paid;
            SupplierPayment::create([
                'store_id' => $user->store_id,
                'supplier_id' => $supplier->id,
                'purchase_invoice_id' => $invoice->id,
                'product_id' => $item->product_id,
                'amount' => $amount,
                'method' => $method,
                'created_by' => $user->id,
            ]);
            $paid = Money::sub($paid, $amount);
        }
    }

    /** An existing supplier by id, or by name typed in the goods flow (created the first time). */
    private function supplierFor(User $user, array $data): Supplier
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
                'line_total' => Money::times($buyPrice, $quantity),
                'unit_cost' => $buyPrice,
            ]);
        }

        $packSize = (int) ($line['pack_size'] ?? $existing?->pack_size ?? 1);
        $cartons = (int) $line['cartons'];

        return array_merge($line, [
            'existing' => $existing,
            'unit' => $unit,
            'quantity' => Pack::baseQuantity((string) $cartons, $packSize),
            'cartons' => $cartons,
            'pack_size' => $packSize,
            'line_total' => Money::times($buyPrice, $cartons),
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
