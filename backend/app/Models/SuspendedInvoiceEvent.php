<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SuspendedInvoiceEvent extends Model
{
    protected $fillable = [
        'store_id', 'suspended_invoice_id', 'user_id', 'from_status',
        'to_status', 'event', 'metadata',
    ];

    protected function casts(): array
    {
        return ['metadata' => 'array'];
    }
}
