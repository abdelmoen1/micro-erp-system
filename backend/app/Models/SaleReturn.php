<?php

namespace App\Models;

use App\Traits\BelongsToStore;
use Illuminate\Database\Eloquent\Model;

/** US-0601: one return against one sale. Never edited or deleted. */
class SaleReturn extends Model
{
    use BelongsToStore;

    protected $fillable = [
        'store_id',
        'invoice_id',
        'customer_id',
        'total_amount',
        'debt_reduction',
        'refund_amount',
        'reason',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'total_amount' => 'decimal:2',
            'debt_reduction' => 'decimal:2',
            'refund_amount' => 'decimal:2',
        ];
    }

    public function invoice()
    {
        return $this->belongsTo(Invoice::class);
    }

    public function items()
    {
        return $this->hasMany(SaleReturnItem::class);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
