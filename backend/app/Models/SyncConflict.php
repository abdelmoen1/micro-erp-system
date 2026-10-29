<?php

namespace App\Models;

use App\Traits\BelongsToStore;
use Illuminate\Database\Eloquent\Model;

/**
 * An offline item a manager must review (US-1101, US-1106, D-03): a `flagged` sale that was
 * recorded, a `conflict` payment that was held, or a `rejected` item that could not be applied.
 */
class SyncConflict extends Model
{
    use BelongsToStore;

    public const KIND_FLAGGED = 'flagged';

    public const KIND_CONFLICT = 'conflict';

    public const KIND_REJECTED = 'rejected';

    public const STATUS_OPEN = 'open';

    public const STATUS_RESOLVED = 'resolved';

    public const RESOLUTION_ACKNOWLEDGED = 'acknowledged';

    public const RESOLUTION_APPLIED = 'applied';

    public const RESOLUTION_REFUNDED = 'refunded';

    public const RESOLUTION_VOIDED = 'voided';

    protected $fillable = [
        'store_id',
        'device_id',
        'client_transaction_id',
        'seq',
        'type',
        'kind',
        'occurred_at',
        'user_id',
        'customer_id',
        'invoice_id',
        'amount',
        'payload',
        'flags',
        'reason',
        'message',
        'status',
        'resolution',
        'resolution_note',
        'resolved_by',
        'resolved_at',
    ];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
            'flags' => 'array',
            'amount' => 'decimal:2',
            'occurred_at' => 'datetime',
            'resolved_at' => 'datetime',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function customer()
    {
        return $this->belongsTo(Customer::class)->withTrashed();
    }

    public function invoice()
    {
        return $this->belongsTo(Invoice::class);
    }

    public function resolver()
    {
        return $this->belongsTo(User::class, 'resolved_by');
    }

    public function isOpen(): bool
    {
        return $this->status === self::STATUS_OPEN;
    }
}
