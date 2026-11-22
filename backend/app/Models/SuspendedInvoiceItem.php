<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SuspendedInvoiceItem extends Model
{
    protected $fillable = [
        'suspended_invoice_id', 'product_id', 'item_name', 'unit',
        'quantity', 'sale_unit', 'pack_size', 'unit_price', 'total',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'decimal:3',
            'pack_size' => 'integer',
            'unit_price' => 'decimal:2',
            'total' => 'decimal:2',
        ];
    }

    public function product() { return $this->belongsTo(Product::class); }
}
