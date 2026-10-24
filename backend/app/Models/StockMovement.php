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

    public const TYPE_ADJUSTMENT_IN = 'adjustment_in';

    public const TYPE_ADJUSTMENT_OUT = 'adjustment_out';

    public const TYPE_SALE = 'sale';

    public const TYPE_SALE_VOID = 'sale_void';

    // US-0601: stock put back by a sale return.
    public const TYPE_SALE_RETURN = 'sale_return';

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
            'quantity' => 'decimal:3',
            'balance_after' => 'decimal:3',
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

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
