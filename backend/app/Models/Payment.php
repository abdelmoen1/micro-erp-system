<?php

namespace App\Models;

use App\Traits\ScopedThroughDebtStore;
use Illuminate\Database\Eloquent\Model;

class Payment extends Model
{
    use ScopedThroughDebtStore;
    protected $fillable = [
        'debt_id',
        'amount',
        'notes',
        'method',
        'paid_at',
        'payment_group_id',
        'created_by',
        'is_reversed',
        'reversed_at',
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

    public function debt()
    {
        return $this->belongsTo(Debt::class);
    }
}
