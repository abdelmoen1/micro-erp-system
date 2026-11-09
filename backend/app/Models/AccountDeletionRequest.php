<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

/** A request to delete an account (staff) or a store (owner), and its outcome. No personal data beyond a masked number. */
class AccountDeletionRequest extends Model
{
    public const TYPE_STAFF = 'staff';
    public const TYPE_STORE = 'store';

    public const PENDING_REVIEW = 'pending_review';
    public const SCHEDULED = 'scheduled';
    public const COMPLETED = 'completed';
    public const CANCELLED = 'cancelled';
    public const REJECTED = 'rejected';

    protected $fillable = ['user_id', 'store_id', 'type', 'source', 'status', 'phone_masked', 'store_name', 'reason', 'scheduled_for', 'completed_at', 'processed_by', 'result'];

    protected function casts(): array
    {
        return ['scheduled_for' => 'datetime', 'completed_at' => 'datetime', 'result' => 'array'];
    }

    protected static function booted(): void
    {
        static::creating(fn(self $request) => $request->reference ??= (string) Str::uuid());
    }

    /** What the public status page may show: no names, no numbers. */
    public function publicView(): array
    {
        return [
            'reference' => $this->reference,
            'type' => $this->type,
            'status' => $this->status,
            'requested_at' => $this->created_at?->toIso8601String(),
            'scheduled_for' => $this->scheduled_for?->toIso8601String(),
            'completed_at' => $this->completed_at?->toIso8601String(),
        ];
    }
}
