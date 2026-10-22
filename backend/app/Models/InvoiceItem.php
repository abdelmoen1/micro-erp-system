<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A sale line. `unit_price`, `unit` and `total` (the line total) are snapshots taken at the sale,
 * so later product edits never change history. Legacy lines have no product.
 */
class InvoiceItem extends Model
{
    protected $fillable = [
        'invoice_id',
        'product_id',
        'item_name',
        'unit',
        'quantity',
        'returned_quantity',
        'unit_price',
        'total',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'decimal:3',
            'returned_quantity' => 'decimal:3',
            'unit_price' => 'decimal:2',
            'total' => 'decimal:2',
        ];
    }

    public function invoice()
    {
        return $this->belongsTo(Invoice::class);
    }

    public function product()
    {
        return $this->belongsTo(Product::class);
    }
}
