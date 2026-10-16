<?php

namespace App\Models;

use App\Traits\BelongsToStore;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

/**
 * Append-only stock ledger entry (05: stock_movements). Rows are never updated or deleted;
 * corrections are new movements.
 */
class StockMovement extends Model
{
    use BelongsToStore;

    public const UPDATED_AT = null;

    public const TYPE_OPENING = 'opening';

    protected $fillable = [
        'store_id',
        'product_id',
        'type',
        'quantity',
        'balance_after',
        'reason',
        'reference_type',
        'reference_id',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'balance_after' => 'integer',
        ];
    }

    protected static function booted(): void
    {
        static::updating(fn() => throw new LogicException('Stock movements are append-only.'));
        static::deleting(fn() => throw new LogicException('Stock movements are append-only.'));
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
