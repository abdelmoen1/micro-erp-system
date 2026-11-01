<?php

namespace App\Services;

use App\Models\Product;
use App\Models\PurchaseInvoice;
use App\Models\PurchaseItem;
use App\Models\PurchaseReturn;
use App\Models\PurchaseReturnItem;
use App\Models\StockMovement;
use App\Models\Supplier;
use App\Models\User;
use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Goods sent back to a supplier (damaged, wrong, or in dispute). Like a sale return (D-05), the
 * value first lowers what the store owes and only the excess comes back as a refund, so the
 * supplier's balance never goes below zero. Nothing is ever deleted.
 *
 * Lock order: supplier, the invoice's lines, then products by id.
 */
class PurchaseReturnService
{
    public function __construct(
        private readonly StockService $stock,
        private readonly AuditService $audit,
    ) {}

    /**
     * @param list<array{purchase_item_id: int, quantity: int|float|string, from_stock?: bool}> $lines
     */
    public function create(User $actor, PurchaseInvoice $invoice, array $lines, string $reason): PurchaseReturn
    {
        return DB::transaction(function () use ($actor, $invoice, $lines, $reason) {
            $supplier = Supplier::query()->whereKey($invoice->supplier_id)->lockForUpdate()->firstOrFail();
            $items = PurchaseItem::query()
                ->where('purchase_invoice_id', $invoice->id)
                ->with('product')
                ->lockForUpdate()
                ->get()
                ->keyBy('id');
            $priced = $this->priceLines($items, $lines);

            $value = Money::sum(array_column($priced, 'total'));
            $owed = Money::maxZero($supplier->balance());
            $toBalance = Money::compare($value, $owed) <= 0 ? $value : $owed;
            $refund = Money::sub($value, $toBalance);

            $return = PurchaseReturn::create([
                'store_id' => $actor->store_id,
                'supplier_id' => $supplier->id,
                'purchase_invoice_id' => $invoice->id,
                'total_amount' => $value,
                'balance_reduction' => $toBalance,
                'refund_amount' => $refund,
                'reason' => $reason,
                'created_by' => $actor->id,
            ]);

            $products = Product::query()
                ->forStore($actor->store_id)
                ->whereIn('id', array_map(fn($line) => $line['item']->product_id, $priced))
                ->orderBy('id')
                ->lockForUpdate()
                ->get()
                ->keyBy('id');

            foreach ($priced as $line) {
                /** @var PurchaseItem $item */
                $item = $line['item'];
                $return->items()->create([
                    'purchase_item_id' => $item->id,
                    'product_id' => $item->product_id,
                    'quantity' => $line['quantity'],
                    'total' => $line['total'],
                    'from_stock' => $line['from_stock'],
                ]);
                $item->update(['returned_quantity' => Quantity::add($item->returned_quantity, $line['quantity'])]);

                if ($line['from_stock']) {
                    $this->stock->move(
                        $products->get($item->product_id),
                        StockMovement::TYPE_PURCHASE_RETURN,
                        Quantity::negate($line['quantity']),
                        $actor,
                        reason: $reason,
                        referenceType: 'purchase_return',
                        referenceId: $return->id,
                    );
                }
            }

            $this->audit->record('purchase.returned', $invoice, [
                'purchase_return_id' => $return->id,
                'supplier_id' => $supplier->id,
                'total_amount' => $value,
                'balance_reduction' => $toBalance,
                'refund_amount' => $refund,
                'reason' => $reason,
                'lines' => array_map(fn($line) => [
                    'purchase_item_id' => $line['item']->id,
                    'quantity' => Quantity::format($line['quantity'], $line['item']->product?->unit),
                    'from_stock' => $line['from_stock'],
                ], $priced),
            ], $actor);

            return $return->load(['items.purchaseItem.product', 'creator', 'supplier']);
        });
    }

    /**
     * Each line: an item of this invoice, a positive quantity that fits the product's unit and does
     * not exceed bought − already returned. Its value is the line's own share, and the last return
     * of a line takes whatever is left of it, so rounding can never lose or add an agora.
     *
     * @param Collection<int, PurchaseItem> $items
     * @return list<array{item: PurchaseItem, quantity: string, total: string, from_stock: bool}>
     */
    private function priceLines(Collection $items, array $lines): array
    {
        $priced = [];
        $errors = [];
        $seen = [];

        foreach ($lines as $index => $line) {
            $item = $items->get((int) $line['purchase_item_id']);
            if (!$item || isset($seen[$item->id])) {
                $errors["items.{$index}.purchase_item_id"] = [$item ? 'هذا الصنف مكرر في الطلب.' : 'هذا الصنف ليس من هذه الفاتورة.'];
                continue;
            }
            $seen[$item->id] = true;

            $quantity = Quantity::of((string) $line['quantity']);
            $unit = $item->product?->unit ?? Quantity::UNIT_PIECE;
            $returnable = Quantity::sub($item->quantity, $item->returned_quantity);

            if (Quantity::isNegative($quantity) || Quantity::isZero($quantity)) {
                $errors["items.{$index}.quantity"] = ['الكمية المرتجعة يجب أن تكون أكبر من صفر.'];
            } elseif (!Quantity::fitsUnit($quantity, $unit)) {
                $errors["items.{$index}.quantity"] = ['هذا الصنف بالقطعة؛ أدخل عددًا صحيحًا.'];
            } elseif (Quantity::compare($quantity, $returnable) > 0) {
                $max = Quantity::format($returnable, $unit);
                $errors["items.{$index}.quantity"] = ["الكمية المرتجعة أكبر من المتاح للإرجاع ({$max})."];
            } else {
                $priced[] = [
                    'item' => $item,
                    'quantity' => $quantity,
                    'total' => $this->lineValue($item, $quantity, $returnable),
                    'from_stock' => (bool) ($line['from_stock'] ?? true),
                ];
            }
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        return $priced;
    }

    private function lineValue(PurchaseItem $item, string $quantity, string $returnable): string
    {
        if (Quantity::compare($quantity, $returnable) === 0) {
            $earlier = PurchaseReturnItem::query()->where('purchase_item_id', $item->id)->pluck('total');

            return Money::sub($item->line_total, Money::sum($earlier));
        }

        // Half-up to the agora: 12 decimals keep the share exact enough for any line total.
        $share = bcdiv(bcmul(Money::of($item->line_total), Quantity::of($quantity), 12), Quantity::of($item->quantity), 12);

        return Money::of($share);
    }
}
