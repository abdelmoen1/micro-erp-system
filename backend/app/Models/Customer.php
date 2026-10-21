<?php

namespace App\Models;

use App\Traits\BelongsToStore;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Customer extends Model
{
    use BelongsToStore, SoftDeletes;

    protected $fillable = [
        'name',
        'phone',
        'address',
        'notes',
        'credit_limit',
        'store_id',
    ];

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
