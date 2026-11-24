<?php

namespace App\Console\Commands;

use App\Models\PurchaseItem;
use App\Models\PurchaseReturnItem;
use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class ReconcilePurchaseReturns extends Command
{
    protected $signature = 'hisbah:reconcile-purchase-returns
                            {--invoice= : Reconcile only this purchase invoice ID}
                            {--apply : Apply only missing returned_quantity corrections}';

    protected $description = 'Report purchase-return accounting discrepancies without changing financial records';

    public function handle(): int
    {
        $invoiceId = $this->option('invoice');
        $apply = (bool) $this->option('apply');

        $query = PurchaseItem::query()->with(['product', 'invoice', 'invoice.returns.items']);
        if ($invoiceId !== null) {
            $query->where('purchase_invoice_id', (int) $invoiceId);
        }

        $items = $query->orderBy('purchase_invoice_id')->orderBy('id')->get();
        $discrepancies = [];

        foreach ($items as $item) {
            $postedQuantity = PurchaseReturnItem::query()
                ->where('purchase_item_id', $item->id)
                ->sum('quantity');
            $postedValue = PurchaseReturnItem::query()
                ->where('purchase_item_id', $item->id)
                ->sum('total');
            $actualQuantity = Quantity::of((string) $postedQuantity);
            $actualValue = Money::of((string) $postedValue);
            $remainingQuantity = Quantity::sub($item->quantity, $actualQuantity);
            $remainingValue = Money::sub($item->line_total, $actualValue);

            $quantityMismatch = Quantity::compare($item->returned_quantity, $actualQuantity) !== 0;
            $ifFullyReturned = Quantity::isZero($remainingQuantity) && Money::compare($actualValue, $item->line_total) !== 0;

            if (!$quantityMismatch && !$ifFullyReturned) {
                continue;
            }

            $beforeQuantity = Quantity::of($item->returned_quantity);
            $row = [
                'purchase_invoice_id' => $item->purchase_invoice_id,
                'purchase_item_id' => $item->id,
                'purchased_quantity' => Quantity::format($item->quantity, $item->product?->unit),
                'recorded_returned_quantity' => Quantity::format($beforeQuantity, $item->product?->unit),
                'actual_returned_quantity' => Quantity::format($actualQuantity, $item->product?->unit),
                'remaining_quantity' => Quantity::format($remainingQuantity, $item->product?->unit),
                'line_total' => Money::of($item->line_total),
                'actual_returned_value' => $actualValue,
                'remaining_line_value' => $remainingValue,
            ];

            if ($apply && $quantityMismatch) {
                DB::transaction(function () use ($item, $actualQuantity): void {
                    $locked = PurchaseItem::query()->whereKey($item->id)->lockForUpdate()->firstOrFail();
                    $derived = PurchaseReturnItem::query()
                        ->where('purchase_item_id', $locked->id)
                        ->sum('quantity');
                    $locked->update(['returned_quantity' => Quantity::of((string) $derived)]);
                });
                $row['applied'] = true;
            } else {
                $row['applied'] = false;
            }

            $discrepancies[] = $row;
        }

        $this->table(
            array_keys($discrepancies[0] ?? [
                'purchase_invoice_id' => null,
                'purchase_item_id' => null,
                'purchased_quantity' => null,
                'recorded_returned_quantity' => null,
                'actual_returned_quantity' => null,
                'remaining_quantity' => null,
                'line_total' => null,
                'actual_returned_value' => null,
                'remaining_line_value' => null,
                'applied' => null,
            ]),
            $discrepancies,
        );

        $this->line(count($discrepancies) === 0
            ? 'No purchase-line quantity discrepancies found.'
            : count($discrepancies) . ' purchase-line discrepancy/discrepancies found.');

        if ($apply && $discrepancies !== []) {
            $this->warn('Only returned_quantity fields were corrected. No return invoices, stock movements, or supplier balances were created or rewritten.');
        } elseif (!$apply && $discrepancies !== []) {
            $this->warn('Dry run only. Re-run with --apply only after the exact repair is approved.');
        }

        return self::SUCCESS;
    }
}
