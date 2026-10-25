<?php

namespace App\Models;

use App\Traits\BelongsToStore;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * US-0401. Never hard-deleted (BR-04): products are deactivated instead.
 * `current_stock` only changes together with a stock movement.
 * This is the store's own row (name, price, cost, stock). A barcoded item also links to the shared
 * CatalogProduct, which no store edit changes.
 */
class Product extends Model
{
    use BelongsToStore;

    public const STATUS_ACTIVE = 'active';

    public const STATUS_INACTIVE = 'inactive';

    protected $fillable = [
        'store_id',
        'catalog_product_id',
        'name',
        'barcode',
        'unit',
        'selling_price',
        'cost_price',
        'pack_size',
        'pack_price',
        'current_stock',
        'minimum_stock',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'selling_price' => 'decimal:2',
            'cost_price' => 'decimal:2',
            'pack_size' => 'integer',
            'pack_price' => 'decimal:2',
            // CR-13: DECIMAL(12,3); whole numbers for pieces (doc 15 §4).
            'current_stock' => 'decimal:3',
            'minimum_stock' => 'decimal:3',
        ];
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    /** The shared catalog identity, when the barcode is a global GTIN (null for store-only codes). */
    public function catalogProduct(): BelongsTo
    {
        return $this->belongsTo(CatalogProduct::class);
    }

    public function movements(): HasMany
    {
        return $this->hasMany(StockMovement::class);
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function isActive(): bool
    {
        return $this->status === self::STATUS_ACTIVE;
    }

    /** Sold and received by the carton too (pack_size pieces for pack_price). */
    public function hasPack(): bool
    {
        return $this->pack_size !== null && $this->pack_price !== null;
    }
}
