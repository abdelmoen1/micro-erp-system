<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SuspendedInvoiceItem extends Model
{
    protected $fillable = [
        'suspended_invoice_id', 'product_id', 'item_name', 'unit',
        'quantity', 'sale_unit', 'pack_size', 'base_quantity', 'unit_price', 'total',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'decimal:3',
            'pack_size' => 'integer',
            'base_quantity' => 'decimal:3',
            'unit_price' => 'decimal:2',
            'total' => 'decimal:2',
        ];
    }

    public function product() { return $this->belongsTo(Product::class); }
    public function reservation() { return $this->hasOne(InventoryReservation::class); }
}
