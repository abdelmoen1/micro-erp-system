<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use LogicException;

/**
 * Append-only record of a critical action (US-0103).
 */
class AuditLog extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = [
        'store_id',
        'user_id',
        'action',
        'entity_type',
        'entity_id',
        'metadata',
        'ip',
        'user_agent',
    ];

    protected function casts(): array
    {
        return [
            'metadata' => 'array',
            'created_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::updating(fn() => throw new LogicException('Audit log entries are immutable.'));
        static::deleting(fn() => throw new LogicException('Audit log entries cannot be deleted.'));
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
