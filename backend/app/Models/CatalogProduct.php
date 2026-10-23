<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * The platform-wide identity of a barcoded item, shared by every store (no store_id, no prices,
 * no stock). A store sells it through its own `products` row (price, cost, stock, its own name).
 * Written once by the store that first saves the barcode; store edits never change it.
 */
class CatalogProduct extends Model
{
    protected $fillable = [
        'barcode',
        'name',
        'unit',
        'created_by_store_id',
        'created_by',
    ];

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }
}
