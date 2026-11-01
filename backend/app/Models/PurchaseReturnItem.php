<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PurchaseReturnItem extends Model
{
    protected $fillable = ['purchase_return_id', 'purchase_item_id', 'product_id', 'quantity', 'total', 'from_stock'];

    protected function casts(): array
    {
        return [
            'quantity' => 'decimal:3',
            'total' => 'decimal:2',
            'from_stock' => 'boolean',
        ];
    }

    public function purchaseItem(): BelongsTo
    {
        return $this->belongsTo(PurchaseItem::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
