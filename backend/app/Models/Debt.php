<?php

namespace App\Models;

use App\Traits\BelongsToStore;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Debt extends Model
{
    use BelongsToStore, HasFactory, SoftDeletes;

    /** Set when the sale behind the debt is voided (US-0503); the remaining amount is then 0. */
    public const STATUS_CANCELLED = 'cancelled';

    protected $fillable = [
        'store_id',
        'invoice_id',
        'customer_id',
        'amount',
        'remaining_amount',
        'return_credit',
        'due_date',
        'status',
        'reversal_reason',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'remaining_amount' => 'decimal:2',
            'return_credit' => 'decimal:2',
            'due_date' => 'date:Y-m-d',
        ];
    }

    public function store()
    {
        return $this->belongsTo(Store::class);
    }

    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }

    public function invoice()
    {
        return $this->belongsTo(Invoice::class);
    }

    public function payments()
    {
        return $this->hasMany(Payment::class);
    }
}
