<?php

namespace App\Services;

use App\Enums\InvoiceSource;
use App\Enums\UserRole;
use App\Exceptions\ApiException;
use App\Models\Customer;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\User;
use App\Support\BusinessClock;
use App\Support\Money;
use App\Support\Pack;
use App\Support\Quantity;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The one sale path (US-0501, US-0502) and its only correction, the void (US-0503).
 *
 * A sale is one transaction: invoice, product-linked lines priced from the database, `sale` stock
 * movements, the debt for any unpaid remainder, and the audit entry. Rows are locked in a fixed
 * order (customer, then products by id) so concurrent sales cannot deadlock or overspend a
 * credit limit.
 */
class SaleService
{
    public const FLAG_NEGATIVE_STOCK = 'NEGATIVE_STOCK';

    public function __construct(
        private readonly StockService $stock,
        private readonly AuditService $audit,
    ) {}

    /**
     * @param array{customer_id?: ?int, items: list<array{product_id: int, quantity: int|float|string}>,
     *     paid_amount: int|float|string, payment_method?: ?string, due_date?: ?string, notes?: ?string,
     *     confirm_over_limit?: bool} $data validated input; client prices are never read
     * @return array{invoice: Invoice, warnings: list<array<string, mixed>>}
     */
    public function create(User $actor, array $data): array
    {
        return DB::transaction(function () use ($actor, $data) {
            $customer = $this->lockCustomer($actor, $data['customer_id'] ?? null);
            $products = $this->lockProducts($actor, $data['items']);

            $lines = $this->priceLines($data['items'], $products);
            $total = Money::sum(array_column($lines, 'total'));
            $paid = Money::of($data['paid_amount']);
            $debtAmount = Money::sub($total, $paid);

            $this->validatePayment($actor, $data, $customer, $total, $paid, $debtAmount);

            $override = Money::isPositive($debtAmount)
                ? $this->checkCreditLimit($actor, $customer, $debtAmount, (bool) ($data['confirm_over_limit'] ?? false))
                : null;

            $invoice = Invoice::create([
                'store_id' => $actor->store_id,
                'customer_id' => $customer?->id,
                'total_amount' => $total,
                'paid_amount' => $paid,
                'status' => Invoice::STATUS_ACTIVE,
                'has_debt' => Money::isPositive($debtAmount),
                'payment_method' => Money::isPositive($paid) ? $data['payment_method'] : null,
                'source' => InvoiceSource::SALE,
                'notes' => $data['notes'] ?? null,
                'created_by' => $actor->id,
            ]);

            $warnings = [];

            foreach ($lines as $line) {
                $product = $line['product'];

                $invoice->items()->create([
                    'product_id' => $product->id,
                    'item_name' => $product->name,
                    'unit' => $product->unit,
                    'quantity' => $line['quantity'],
                    // Snapshot: this line's quantity and unit price are per carton of this size.
                    'pack_size' => $line['pack_size'],
                    'unit_price' => $line['unit_price'],
                    'total' => $line['total'],
                ]);

                // D-27: a shortfall does not block the sale; it is flagged for the manager's review.
                // Stock is in pieces: a carton line takes quantity × pack_size of them.
                $movement = $this->stock->move(
                    $product,
                    StockMovement::TYPE_SALE,
                    Quantity::negate($line['base_quantity']),
                    $actor,
                    referenceType: 'invoice',
                    referenceId: $invoice->id,
                    allowNegative: true,
                );

                if (Quantity::isNegative($movement->balance_after)) {
                    $warnings[] = [
                        'code' => self::FLAG_NEGATIVE_STOCK,
                        'product_id' => $product->id,
                        'name' => $product->name,
                        'balance_after' => Quantity::format($movement->balance_after, $product->unit),
                    ];
                }
            }

            $debt = null;

            if (Money::isPositive($debtAmount)) {
                $debt = Debt::create([
                    'store_id' => $actor->store_id,
                    'invoice_id' => $invoice->id,
                    'customer_id' => $customer->id,
                    'amount' => $debtAmount,
                    'remaining_amount' => $debtAmount,
                    'status' => 'unpaid',
                    'due_date' => $data['due_date'] ?? null,
                ]);
            }

            $this->audit->record('sale.created', $invoice, [
                'customer_id' => $customer?->id,
                'total_amount' => $total,
                'paid_amount' => $paid,
                'debt_id' => $debt?->id,
                'debt_amount' => $debt ? $debtAmount : '0.00',
                'flags' => array_values(array_unique(array_column($warnings, 'code'))),
                'negative_stock_products' => array_column($warnings, 'product_id'),
            ], $actor);

            if ($override !== null) {
                $this->audit->record('sale.credit_limit_overridden', $invoice, $override + [
                    'customer_id' => $customer->id,
                ], $actor);
            }

            return [
                'invoice' => $invoice->load(['customer', 'items', 'debt.payments', 'creator', 'voider']),
                'warnings' => $warnings,
            ];
        });
    }

    /**
     * US-0503 (D-06): Owner / Manager void with a reason. Restores exactly the stock the sale took
     * (its `sale` movements), cancels the debt, keeps every row, and audits. A second void of the
     * same invoice is a 409, so stock and debt are reversed once.
     */
    public function void(User $actor, Invoice $invoice, string $reason): Invoice
    {
        return DB::transaction(function () use ($actor, $invoice, $reason) {
            $locked = Invoice::query()
                ->forStore($actor->store_id)
                ->whereKey($invoice->id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($locked->isVoided()) {
                throw ApiException::conflict('INVOICE_ALREADY_VOIDED', 'هذه الفاتورة ملغاة مسبقًا.');
            }

            if ($locked->source !== InvoiceSource::SALE) {
                throw ApiException::conflict('INVOICE_NOT_VOIDABLE', 'هذا السجل دين افتتاحي وليس عملية بيع، ولا يمكن إلغاؤه.');
            }

            $debt = Debt::query()->where('invoice_id', $locked->id)->lockForUpdate()->first();

            if ($debt && $debt->payments()->where('is_reversed', false)->exists()) {
                throw ApiException::conflict(
                    'INVOICE_HAS_PAYMENTS',
                    'لا يمكن إلغاء الفاتورة لأن على دينها دفعات قائمة. اعكس الدفعات أولًا.'
                );
            }

            if ($locked->items()->where('returned_quantity', '>', 0)->exists()) {
                throw ApiException::conflict('INVOICE_HAS_RETURNS', 'لا يمكن إلغاء الفاتورة لأن عليها مرتجعات.');
            }

            $restored = $this->restoreStock($actor, $locked);

            if ($debt) {
                $debt->update([
                    'status' => Debt::STATUS_CANCELLED,
                    'remaining_amount' => '0.00',
                ]);
            }

            $locked->update([
                'status' => Invoice::STATUS_VOIDED,
                'voided_at' => now(),
                'voided_by' => $actor->id,
                'void_reason' => $reason,
            ]);

            $this->audit->record('sale.voided', $locked, [
                'reason' => $reason,
                'total_amount' => Money::of($locked->total_amount),
                'paid_amount' => Money::of($locked->paid_amount),
                'debt_id' => $debt?->id,
                'debt_amount_cancelled' => $debt ? Money::of($debt->amount) : '0.00',
                'stock_restored' => $restored,
            ], $actor);

            return $locked->load(['customer', 'items', 'debt.payments', 'creator', 'voider']);
        });
    }

    private function lockCustomer(User $actor, ?int $customerId): ?Customer
    {
        if ($customerId === null) {
            return null;
        }

        // The request already checked the customer belongs to the store; the lock serializes
        // credit sales of one customer so two tills cannot both pass the limit check.
        $customer = Customer::query()
            ->where('store_id', $actor->store_id)
            ->whereKey($customerId)
            ->lockForUpdate()
            ->firstOrFail();

        // US-0301 AC4: an inactive customer is never offered for a new sale.
        if (!$customer->isActive()) {
            throw ValidationException::withMessages(['customer_id' => ['هذا العميل موقوف ولا يمكن البيع له. أعد تفعيله أولًا.']]);
        }

        return $customer;
    }

    /** @return Collection<int, Product> keyed by id, locked in id order */
    private function lockProducts(User $actor, array $items): Collection
    {
        $ids = collect($items)->pluck('product_id')->map(fn($id) => (int) $id)->unique()->sort()->values();

        $products = Product::query()
            ->forStore($actor->store_id)
            ->whereIn('id', $ids)
            ->orderBy('id')
            ->lockForUpdate()
            ->get()
            ->keyBy('id');

        $errors = [];

        foreach ($items as $index => $item) {
            $product = $products->get((int) $item['product_id']);

            if (!$product) {
                // Another store's product is reported exactly like an unknown one (05 §2: no leak).
                $errors["items.{$index}.product_id"] = ['المنتج غير موجود في متجرك.'];
            } elseif (!$product->isActive()) {
                $errors["items.{$index}.product_id"] = ['هذا المنتج موقوف ولا يمكن بيعه.'];
            }
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        return $products;
    }

    /** Prices come from products.selling_price (US-0501 AC1); line total is rounded half-up. */
    private function priceLines(array $items, Collection $products): array
    {
        $lines = [];
        $errors = [];

        foreach ($items as $index => $item) {
            $product = $products->get((int) $item['product_id']);
            $quantity = Quantity::of((string) $item['quantity']);
            $byPack = ($item['sale_unit'] ?? null) === Pack::SALE_UNIT;

            if ($byPack && !$product->hasPack()) {
                $errors["items.{$index}.sale_unit"] = ['هذا المنتج لا يُباع بالكرتونة.'];

                continue;
            }

            // A carton line counts whole cartons; otherwise the product's own unit decides.
            if (!Quantity::fitsUnit($quantity, $byPack ? Quantity::UNIT_PIECE : $product->unit)) {
                $errors["items.{$index}.quantity"] = [$byPack ? 'الكرتونة تُباع كاملة؛ أدخل عددًا صحيحًا من الكراتين.' : 'هذا المنتج يباع بالقطعة؛ أدخل عددًا صحيحًا.'];

                continue;
            }

            // The price of the unit actually sold: per carton for a carton line, never per piece.
            $unitPrice = Money::of($byPack ? $product->pack_price : $product->selling_price);
            $packSize = $byPack ? (int) $product->pack_size : null;

            $lines[] = [
                'product' => $product,
                'quantity' => $quantity,
                'pack_size' => $packSize,
                'base_quantity' => Pack::baseQuantity($quantity, $packSize),
                'unit_price' => $unitPrice,
                'total' => Money::times($unitPrice, $quantity),
            ];
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        return $lines;
    }

    private function validatePayment(
        User $actor,
        array $data,
        ?Customer $customer,
        string $total,
        string $paid,
        string $debtAmount,
    ): void {
        $errors = [];

        if (Money::compare($paid, $total) > 0) {
            $errors['paid_amount'] = ["المبلغ المدفوع أكبر من إجمالي الفاتورة ({$total})."];
        }

        if (Money::isPositive($paid) && empty($data['payment_method'])) {
            $errors['payment_method'] = ['يجب تحديد طريقة الدفع.'];
        }

        if (Money::isPositive($debtAmount)) {
            // D-07: only a fully paid sale may be a walk-in sale.
            if (!$customer) {
                $errors['customer_id'] = ['يجب اختيار العميل عند البيع بالدين أو الدفع الجزئي.'];
            }

            $dueDate = $data['due_date'] ?? null;
            $today = BusinessClock::forStore($actor->store)->now()->toDateString();

            if ($dueDate !== null && $dueDate < $today) {
                $errors['due_date'] = ['تاريخ الاستحقاق لا يمكن أن يكون في الماضي.'];
            }
        } elseif (($data['due_date'] ?? null) !== null) {
            $errors['due_date'] = ['تاريخ الاستحقاق يُحدد فقط عندما يبقى دين على الفاتورة.'];
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }
    }

    /**
     * D-26 as approved: over the limit, an Employee is refused; an Owner / Manager must confirm
     * (`confirm_over_limit=true`), and the override is audited with the sale.
     *
     * @return array<string, mixed>|null the confirmed override's facts, or null when within the limit
     */
    private function checkCreditLimit(User $actor, Customer $customer, string $debtAmount, bool $confirmed): ?array
    {
        if ($customer->credit_limit === null) {
            return null;
        }

        $outstanding = Money::sum(
            Debt::query()
                ->where('store_id', $actor->store_id)
                ->where('customer_id', $customer->id)
                ->where('remaining_amount', '>', 0)
                ->pluck('remaining_amount')
        );
        $after = Money::add($outstanding, $debtAmount);

        if (Money::compare($after, $customer->credit_limit) <= 0) {
            return null;
        }

        $details = [
            'credit_limit' => Money::of($customer->credit_limit),
            'outstanding' => $outstanding,
            'new_debt' => $debtAmount,
            'balance_after' => $after,
            'can_override' => $actor->hasRole(UserRole::OWNER, UserRole::MANAGER),
        ];
        $message = "تتجاوز هذه العملية سقف دين العميل ({$details['credit_limit']}): الرصيد الحالي {$outstanding} والدين الجديد {$debtAmount}.";

        if (!$details['can_override']) {
            throw ApiException::businessRule('CREDIT_LIMIT_EXCEEDED', $message, ['customer_id' => [$message]], $details);
        }

        if (!$confirmed) {
            throw ApiException::businessRule(
                'CREDIT_LIMIT_CONFIRMATION_REQUIRED',
                $message . ' أكّد التجاوز للمتابعة.',
                ['confirm_over_limit' => [$message]],
                $details,
            );
        }

        unset($details['can_override']);

        return $details;
    }

    /** @return list<array{product_id: int, quantity: string}> what was put back on the shelf */
    private function restoreStock(User $actor, Invoice $invoice): array
    {
        $taken = StockMovement::query()
            ->where('store_id', $actor->store_id)
            ->where('reference_type', 'invoice')
            ->where('reference_id', $invoice->id)
            ->where('type', StockMovement::TYPE_SALE)
            ->orderBy('product_id')
            ->get()
            ->groupBy('product_id');

        $restored = [];

        foreach ($taken as $productId => $movements) {
            $quantity = Quantity::negate(
                $movements->reduce(fn(string $sum, StockMovement $m) => Quantity::add($sum, $m->quantity), '0')
            );
            $product = Product::query()->forStore($actor->store_id)->findOrFail($productId);

            $this->stock->move(
                $product,
                StockMovement::TYPE_SALE_VOID,
                $quantity,
                $actor,
                referenceType: 'invoice',
                referenceId: $invoice->id,
            );

            $restored[] = ['product_id' => (int) $productId, 'quantity' => Quantity::format($quantity, $product->unit)];
        }

        return $restored;
    }
}
