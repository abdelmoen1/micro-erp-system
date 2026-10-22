<?php

namespace App\Models;

use App\Traits\ScopedThroughDebtStore;
use Illuminate\Database\Eloquent\Model;

class Payment extends Model
{
    use ScopedThroughDebtStore;
    protected $fillable = [
        'store_id',
        'debt_id',
        'customer_id',
        'amount',
        'notes',
        'method',
        'paid_at',
        'payment_group_id',
        'created_by',
        'is_reversed',
        'reversed_at',
        'reversed_by',
        'reversal_reason',
    ];
    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'is_reversed' => 'boolean',
            'paid_at' => 'datetime',
            'reversed_at' => 'datetime',
        ];
    }

    /** US-0703: a payment always carries its debt's store and customer, whichever path writes it. */
    protected static function booted(): void
    {
        static::creating(function (Payment $payment) {
            if ($payment->store_id === null || $payment->customer_id === null) {
                $debt = $payment->debt ?? Debt::query()->find($payment->debt_id);
                $payment->store_id ??= $debt?->store_id;
                $payment->customer_id ??= $debt?->customer_id;
            }
        });
    }

    public function debt()
    {
        return $this->belongsTo(Debt::class);
    }

    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function reverser()
    {
        return $this->belongsTo(User::class, 'reversed_by');
    }
}
