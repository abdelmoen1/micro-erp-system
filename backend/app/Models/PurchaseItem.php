<?php

namespace App\Models;

use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PurchaseItem extends Model
{
    protected $fillable = [
        'purchase_invoice_id',
        'product_id',
        'quantity',
        'returned_quantity',
        'cartons',
        'pack_size',
        'loose_pieces',
        'buy_price',
        'line_total',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'decimal:3',
            'returned_quantity' => 'decimal:3',
            'cartons' => 'integer',
            'pack_size' => 'integer',
            'loose_pieces' => 'integer',
            'buy_price' => 'decimal:2',
            'line_total' => 'decimal:2',
        ];
    }

    public function invoice(): BelongsTo
    {
        return $this->belongsTo(PurchaseInvoice::class, 'purchase_invoice_id');
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    /** What is still on the invoice: bought − sent back. Zero once every piece went back. */
    public function remainingQuantity(): string
    {
        return Quantity::sub($this->quantity, $this->returned_quantity);
    }

    /** A line whose whole quantity went back to the supplier leaves the supplier's invoice. */
    public function isFullyReturned(): bool
    {
        return Quantity::compare($this->remainingQuantity(), '0') <= 0;
    }

    /**
     * The remaining quantity as whole cartons and loose pieces, for a line bought by the carton.
     *
     * @return array{0: ?int, 1: int} [cartons, or null when not bought by the carton; loose pieces]
     */
    public function remainingCartons(): array
    {
        $remaining = $this->remainingQuantity();
        if ($this->cartons === null || (int) $this->pack_size <= 0 || !Quantity::isWhole($remaining)) {
            return [null, 0];
        }
        $pieces = (int) substr(Quantity::of($remaining), 0, -4);

        return [intdiv($pieces, (int) $this->pack_size), $pieces % (int) $this->pack_size];
    }

    /**
     * Value sent back from each line by returns that are not voided, in one query.
     *
     * @param iterable<int> $ids
     * @return array<int, string> purchase_item_id => value
     */
    public static function returnedValues(iterable $ids): array
    {
        $ids = collect($ids)->map(fn($id) => (int) $id)->unique()->values();
        if ($ids->isEmpty()) {
            return [];
        }

        return PurchaseReturnItem::query()
            ->whereIn('purchase_item_id', $ids)
            ->whereHas('purchaseReturn', fn($q) => $q->notVoided())
            ->get(['purchase_item_id', 'total'])
            ->groupBy('purchase_item_id')
            ->map(fn($rows) => Money::sum($rows->pluck('total')))
            ->all();
    }
}
