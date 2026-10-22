<?php

namespace App\Models;

use App\Traits\BelongsToStore;
use Illuminate\Database\Eloquent\Model;
use App\Enums\InvoiceSource;

/**
 * A sale (or the carrier of an opening debt). Final at creation (D-06): only `notes` change
 * afterwards, and a mistake is corrected by a void, never by an edit or a delete.
 */
class Invoice extends Model
{
    use BelongsToStore;

    public const STATUS_ACTIVE = 'active';

    public const STATUS_VOIDED = 'voided';

    protected $fillable = [
        'store_id',
        'customer_id',
        'total_amount',
        'paid_amount',
        'status',
        'has_debt',
        'payment_method',
        'source',
        'notes',
        'created_by',
        'voided_at',
        'voided_by',
        'void_reason',
    ];

    protected function casts(): array
    {
        return [
            'total_amount' => 'decimal:2',
            'paid_amount' => 'decimal:2',
            'has_debt' => 'boolean',
            'source' => InvoiceSource::class,
            'voided_at' => 'datetime',
        ];
    }


    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }

    public function items()
    {
        return $this->hasMany(InvoiceItem::class);
    }

    public function debt()
    {
        return $this->hasOne(Debt::class);
    }

    /** US-0601: returns against this sale, oldest first. */
    public function returns()
    {
        return $this->hasMany(SaleReturn::class)->orderBy('id');
    }

    /** The seller (M-06 receipt «البائع»). */
    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function voider()
    {
        return $this->belongsTo(User::class, 'voided_by');
    }

    public function isVoided(): bool
    {
        return $this->status === self::STATUS_VOIDED;
    }
}
