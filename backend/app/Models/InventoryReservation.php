<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InventoryReservation extends Model
{
    public const STATUS_ACTIVE = 'active';
    public const STATUS_RELEASED = 'released';
    public const STATUS_DEDUCTED = 'deducted';

    protected $fillable = [
        'store_id', 'product_id', 'suspended_invoice_id', 'quantity',
        'status', 'released_at', 'deducted_at',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'decimal:3',
            'released_at' => 'datetime',
            'deducted_at' => 'datetime',
        ];
    }
}
