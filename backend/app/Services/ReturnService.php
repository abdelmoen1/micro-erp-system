<?php

namespace App\Services;

use App\Enums\InvoiceSource;
use App\Exceptions\ApiException;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\InvoiceItem;
use App\Models\Product;
use App\Models\SaleReturn;
use App\Models\StockMovement;
use App\Models\User;
use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * US-0601 (D-05, CR-05): return lines of a sale. The return value first reduces the sale's open
 * debt (as `return_credit`), and only what exceeds the debt is refunded in cash. Stock goes back
 * with a `sale_return` movement, except a line marked damaged, which never returns to the shelf;
 * nothing is ever deleted.
 *
 * Lock order matches the sale path: invoice, debt, then products by id.
 */
class ReturnService
{
    public function __construct(
        private readonly StockService $stock,
        private readonly DebtLedger $ledger,
        private readonly AuditService $audit,
    ) {}

    /**
     * @param list<array{invoice_item_id: int, quantity: int|float|string, damaged?: bool}> $lines
     */
    public function create(User $actor, Invoice $invoice, array $lines, string $reason): SaleReturn
    {
        return DB::transaction(function () use ($actor, $invoice, $lines, $reason) {
            $locked = Invoice::query()
                ->forStore($actor->store_id)
                ->whereKey($invoice->id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($locked->isVoided()) {
                throw ApiException::businessRule('INVOICE_VOIDED', 'لا يمكن إرجاع أصناف من فاتورة ملغاة.', [
                    'invoice' => ['لا يمكن إرجاع أصناف من فاتورة ملغاة.'],
                ]);
            }

            if ($locked->source !== InvoiceSource::SALE) {
                throw ApiException::businessRule('INVOICE_NOT_RETURNABLE', 'هذا السجل دين افتتاحي وليس عملية بيع.', [
                    'invoice' => ['هذا السجل دين افتتاحي وليس عملية بيع.'],
                ]);
            }

            $debt = Debt::query()->where('invoice_id', $locked->id)->lockForUpdate()->first();
            $items = InvoiceItem::query()->where('invoice_id', $locked->id)->lockForUpdate()->get()->keyBy('id');
            $priced = $this->priceLines($items, $lines);

            $value = $this->afterDiscount($locked, Money::sum(array_column($priced, 'total')));
            $debtOpen = $debt && $debt->status !== Debt::STATUS_CANCELLED ? Money::of($debt->remaining_amount) : '0.00';
            $toDebt = Money::compare($value, $debtOpen) <= 0 ? $value : $debtOpen;
            $refund = Money::sub($value, $toDebt);

            $return = SaleReturn::create([
                'store_id' => $actor->store_id,
                'invoice_id' => $locked->id,
                'customer_id' => $locked->customer_id,
                'total_amount' => $value,
                'debt_reduction' => $toDebt,
                'refund_amount' => $refund,
                'reason' => $reason,
                'created_by' => $actor->id,
            ]);

            $products = Product::query()
                ->forStore($actor->store_id)
                ->whereIn('id', array_filter(array_map(fn($line) => $line['item']->product_id, $priced)))
                ->orderBy('id')
                ->lockForUpdate()
                ->get()
                ->keyBy('id');

            foreach ($priced as $line) {
                /** @var InvoiceItem $item */
                $item = $line['item'];
                $return->items()->create([
                    'invoice_item_id' => $item->id,
                    'product_id' => $item->product_id,
                    'quantity' => $line['quantity'],
                    'unit_price' => Money::of($item->unit_price),
                    'total' => $line['total'],
                    'damaged' => $line['damaged'],
                ]);
                $item->update(['returned_quantity' => Quantity::add($item->returned_quantity ?? '0', $line['quantity'])]);

                if (!$line['damaged'] && $item->product_id && $products->has($item->product_id)) {
                    // A carton line is returned in whole cartons (its own unit) and puts back the
                    // pieces of its snapshot size, even if the product's carton changed since.
                    $this->stock->move(
                        $products->get($item->product_id),
                        StockMovement::TYPE_SALE_RETURN,
                        $item->baseQuantity($line['quantity']),
                        $actor,
                        reason: $reason,
                        referenceType: 'sale_return',
                        referenceId: $return->id,
                    );
                }
            }

            if ($debt && Money::isPositive($toDebt)) {
                $debt->return_credit = Money::add($debt->return_credit, $toDebt);
                $debt->save();
                $this->ledger->recalculate($debt);
            }

            $this->audit->record('sale.returned', $locked, [
                'sale_return_id' => $return->id,
                'total_amount' => $value,
                'debt_reduction' => $toDebt,
                'refund_amount' => $refund,
                'reason' => $reason,
                'lines' => array_map(fn($line) => [
                    'invoice_item_id' => $line['item']->id,
                    'quantity' => Quantity::format($line['quantity'], $line['item']->unit ?? Quantity::UNIT_PIECE),
                    'damaged' => $line['damaged'],
                ], $priced),
            ], $actor);

            return $return->load(['items', 'creator']);
        });
    }

    /**
     * Cancels a return made by mistake and reverses exactly what it did: the stock it put back
     * leaves again (a `sale_return_void` movement per product), the debt gets its return credit
     * back, and the lines' returned quantities drop. The return row stays, marked voided with the
     * reason, time and user. A second cancel is a 409, so nothing is reversed twice.
     *
     * Blocked (409, nothing written) when the returned goods are no longer on the shelf — selling
     * or adjusting them since would push the stock below zero — or when the sale's debt was
     * cancelled since. Lock order matches create(): invoice, return, debt, lines, products.
     */
    public function void(User $actor, SaleReturn $return, string $reason): SaleReturn
    {
        return DB::transaction(function () use ($actor, $return, $reason) {
            $invoice = Invoice::query()
                ->forStore($actor->store_id)
                ->whereKey($return->invoice_id)
                ->lockForUpdate()
                ->firstOrFail();

            $locked = SaleReturn::query()
                ->forStore($actor->store_id)
                ->whereKey($return->id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($locked->isVoided()) {
                throw ApiException::conflict('RETURN_ALREADY_VOIDED', 'هذا المرتجع ملغى مسبقًا.');
            }

            if ($invoice->isVoided()) {
                throw ApiException::conflict('RETURN_NOT_VOIDABLE', 'لا يمكن إلغاء مرتجع على فاتورة ملغاة.');
            }

            $debt = Debt::query()->where('invoice_id', $invoice->id)->lockForUpdate()->first();
            $reduction = Money::of($locked->debt_reduction);

            if (Money::isPositive($reduction) && (!$debt || $debt->status === Debt::STATUS_CANCELLED)) {
                throw ApiException::conflict('RETURN_NOT_VOIDABLE', 'دين الفاتورة لم يعد قائمًا، فلا يمكن إعادة المبلغ إليه.');
            }

            $lines = $locked->items()->get();
            $items = InvoiceItem::query()
                ->whereIn('id', $lines->pluck('invoice_item_id'))
                ->lockForUpdate()
                ->get()
                ->keyBy('id');

            $taken = $this->takeBackStock($actor, $locked, $reason);

            foreach ($lines as $line) {
                $item = $items->get($line->invoice_item_id);
                $item->update(['returned_quantity' => Quantity::sub($item->returned_quantity ?? '0', $line->quantity)]);
            }

            if ($debt && Money::isPositive($reduction)) {
                $debt->return_credit = Money::maxZero(Money::sub($debt->return_credit, $reduction));
                $debt->save();
                $this->ledger->recalculate($debt);
            }

            $locked->markVoided($actor, $reason);

            $this->audit->record('sale_return.voided', $locked, [
                'invoice_id' => $invoice->id,
                'customer_id' => $locked->customer_id,
                'reason' => $reason,
                'total_amount' => Money::of($locked->total_amount),
                'debt_restored' => $reduction,
                // Cash paid back at the return: the customer owes it back to the till.
                'refund_to_collect' => Money::of($locked->refund_amount),
                'stock_taken_back' => $taken,
            ], $actor);

            return $locked->load(['items.invoiceItem', 'creator', 'voider', 'customer']);
        });
    }

    /**
     * Takes back off the shelf what the return put on it (its own `sale_return` movements, so a
     * damaged line moves nothing). Products are locked by id; a shortfall stops the whole cancel.
     *
     * @return list<array{product_id: int, quantity: string}>
     */
    private function takeBackStock(User $actor, SaleReturn $return, string $reason): array
    {
        $put = StockMovement::query()
            ->where('store_id', $actor->store_id)
            ->where('reference_type', 'sale_return')
            ->where('reference_id', $return->id)
            ->where('type', StockMovement::TYPE_SALE_RETURN)
            ->orderBy('product_id')
            ->get()
            ->groupBy('product_id');

        $taken = [];

        foreach ($put as $productId => $movements) {
            $quantity = Quantity::negate($movements->reduce(fn(string $sum, StockMovement $m) => Quantity::add($sum, $m->quantity), '0'));
            $product = Product::query()->forStore($actor->store_id)->findOrFail($productId);

            try {
                $this->stock->move(
                    $product,
                    StockMovement::TYPE_SALE_RETURN_VOID,
                    $quantity,
                    $actor,
                    reason: $reason,
                    referenceType: 'sale_return',
                    referenceId: $return->id,
                );
            } catch (ApiException $e) {
                throw self::stockConsumed($product, $e);
            }

            $taken[] = ['product_id' => (int) $productId, 'quantity' => Quantity::format($quantity, $product->unit)];
        }

        return $taken;
    }

    /** The shelf no longer holds the returned goods: say which product, and leave everything as it was. */
    public static function stockConsumed(Product $product, ApiException $cause): ApiException
    {
        $available = Quantity::format($product->fresh()->current_stock, $product->unit);

        return new ApiException(409, 'RETURN_STOCK_CONSUMED',
            "لا يمكن إلغاء المرتجع: الكمية المرتجعة من «{$product->name}» لم تعد في المخزون (المتوفر الآن {$available}). صحّح المخزون أولًا ثم أعد المحاولة.",
            details: ['product_id' => $product->id, 'cause' => $cause->errorCode],
        );
    }

    /**
     * A discounted sale gives back what was charged: the lines' value less the same share of the
     * discount, and never more than the sale has left after its earlier returns.
     */
    private function afterDiscount(Invoice $invoice, string $value): string
    {
        $discount = Money::of($invoice->discount_amount);
        if (!Money::isPositive($discount)) {
            return $value;
        }

        $subtotal = Money::add($invoice->total_amount, $discount);
        $share = Money::of(bcdiv(bcmul($discount, $value, 4), $subtotal, 6));
        $left = Money::sub($invoice->total_amount, Money::sum(SaleReturn::query()->where('invoice_id', $invoice->id)->notVoided()->pluck('total_amount')));
        $charged = Money::sub($value, $share);

        return Money::compare($charged, $left) > 0 ? Money::maxZero($left) : $charged;
    }

    /**
     * Each line: an item of this invoice, a positive quantity that fits its unit and does not
     * exceed sold − already returned (AC4: otherwise 422 and nothing is written).
     *
     * @return list<array{item: InvoiceItem, quantity: string, total: string, damaged: bool}>
     */
    private function priceLines($items, array $lines): array
    {
        $priced = [];
        $errors = [];
        $seen = [];

        foreach ($lines as $index => $line) {
            $item = $items->get((int) $line['invoice_item_id']);
            if (!$item || isset($seen[$item->id])) {
                $errors["items.{$index}.invoice_item_id"] = [$item ? 'هذا الصنف مكرر في الطلب.' : 'هذا الصنف ليس من هذه الفاتورة.'];
                continue;
            }
            $seen[$item->id] = true;

            $quantity = Quantity::of((string) $line['quantity']);
            $unit = $item->unit ?? Quantity::UNIT_PIECE;
            $returnable = Quantity::sub($item->quantity, $item->returned_quantity ?? '0');

            if (Quantity::isNegative($quantity) || Quantity::isZero($quantity)) {
                $errors["items.{$index}.quantity"] = ['الكمية المرتجعة يجب أن تكون أكبر من صفر.'];
            } elseif (!Quantity::fitsUnit($quantity, $unit)) {
                $errors["items.{$index}.quantity"] = [$item->isPack()
                    ? 'هذا الصنف بيع بالكرتونة؛ أرجع كراتين كاملة.'
                    : 'هذا الصنف يباع بالقطعة؛ أدخل عددًا صحيحًا.'];
            } elseif (Quantity::compare($quantity, $returnable) > 0) {
                $max = Quantity::format($returnable, $unit);
                $errors["items.{$index}.quantity"] = ["الكمية المرتجعة أكبر من المتاح للإرجاع ({$max})."];
            } else {
                $priced[] = [
                    'item' => $item,
                    'quantity' => $quantity,
                    'total' => Money::times($item->unit_price, $quantity),
                    'damaged' => (bool) ($line['damaged'] ?? false),
                ];
            }
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        return $priced;
    }
}
