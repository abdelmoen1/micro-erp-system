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
 * with a `sale_return` movement; nothing is ever deleted.
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
     * @param list<array{invoice_item_id: int, quantity: int|float|string}> $lines
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

            $value = Money::sum(array_column($priced, 'total'));
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
                ]);
                $item->update(['returned_quantity' => Quantity::add($item->returned_quantity ?? '0', $line['quantity'])]);

                if ($item->product_id && $products->has($item->product_id)) {
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
                ], $priced),
            ], $actor);

            return $return->load(['items', 'creator']);
        });
    }

    /**
     * Each line: an item of this invoice, a positive quantity that fits its unit and does not
     * exceed sold − already returned (AC4: otherwise 422 and nothing is written).
     *
     * @return list<array{item: InvoiceItem, quantity: string, total: string}>
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
                ];
            }
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        return $priced;
    }
}
