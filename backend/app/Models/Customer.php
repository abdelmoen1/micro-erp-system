<?php

namespace App\Models;

use App\Traits\BelongsToStore;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Customer extends Model
{
    use BelongsToStore, SoftDeletes;

    // US-0301 AC4: inactive customers are hidden from new sales; history stays payable.
    public const STATUS_ACTIVE = 'active';

    public const STATUS_INACTIVE = 'inactive';

    protected $fillable = [
        'name',
        'phone',
        'address',
        'notes',
        'credit_limit',
        'store_id',
    ];

    public function isActive(): bool
    {
        return ($this->status ?? self::STATUS_ACTIVE) === self::STATUS_ACTIVE;
    }

    protected function casts(): array
    {
        return [
            // US-0305: NULL = no limit (BR-01, D-26).
            'credit_limit' => 'decimal:2',
        ];
    }

    public function store()
    {
        return $this->belongsTo(Store::class);
    }

    public function invoices()
    {
        return $this->hasMany(Invoice::class);
    }

    /** Debts by their own customer_id (US-0701), the source of the customer's balance. */
    public function ledgerDebts()
    {
        return $this->hasMany(Debt::class, 'customer_id');
    }

    public function debts()
    {
        return $this->hasManyThrough(
            Debt::class,
            Invoice::class,
            'customer_id', // Foreign key on invoices
            'invoice_id',  // Foreign key on debts
            'id',          // Local key on customers
            'id'           // Local key on invoices
        );
    }
}
