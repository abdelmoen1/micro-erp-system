<?php

namespace App\Models;

use App\Enums\UserRole;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use App\Models\User;

/**
 * Account access (`status`) and the subscription are separate states: suspending a store never
 * touches its subscription, and a lapsed subscription never suspends the store. Both change only
 * through StoreAccessService (platform admin); neither is mass-assignable.
 */
class Store extends Model
{
    protected $fillable = [
        'name',
        'phone',
        'address',
        'timezone',
    ];

    /** The column defaults, so a just-created store reports both states. */
    protected $attributes = [
        'status' => self::STATUS_ACTIVE,
        'subscription_status' => self::SUBSCRIPTION_INACTIVE,
    ];

    /** Which platform admin changed a state stays out of what the store itself is sent. */
    protected $hidden = [
        'status_changed_by',
        'subscription_changed_by',
    ];

    /** D-23 / CR-14: Gaza pilot default; each store may use its own zone. */
    public const DEFAULT_TIMEZONE = 'Asia/Gaza';

    public const STATUS_ACTIVE = 'active';

    public const STATUS_SUSPENDED = 'suspended';

    public const SUBSCRIPTION_ACTIVE = 'active';

    public const SUBSCRIPTION_INACTIVE = 'inactive';

    /** Derived: an active subscription whose expiry date has passed. */
    public const SUBSCRIPTION_EXPIRED = 'expired';

    protected function casts(): array
    {
        return [
            'status_changed_at' => 'datetime',
            'subscription_started_at' => 'datetime',
            'subscription_expires_at' => 'datetime',
            'subscription_changed_at' => 'datetime',
        ];
    }

    public function businessTimezone(): string
    {
        return $this->timezone ?: self::DEFAULT_TIMEZONE;
    }

    public function isSuspended(): bool
    {
        return ($this->status ?? self::STATUS_ACTIVE) === self::STATUS_SUSPENDED;
    }

    /** active | expired | inactive, as of now. */
    public function subscriptionState(): string
    {
        if ($this->subscription_status !== self::SUBSCRIPTION_ACTIVE) {
            return self::SUBSCRIPTION_INACTIVE;
        }

        return $this->subscription_expires_at && $this->subscription_expires_at->isPast()
            ? self::SUBSCRIPTION_EXPIRED
            : self::SUBSCRIPTION_ACTIVE;
    }

    /** The same three states as subscriptionState(), as a query filter. */
    public function scopeSubscriptionState(Builder $query, string $state): Builder
    {
        $now = now();

        return match ($state) {
            self::SUBSCRIPTION_ACTIVE => $query->where('subscription_status', self::SUBSCRIPTION_ACTIVE)
                ->where(fn($q) => $q->whereNull('subscription_expires_at')->orWhere('subscription_expires_at', '>', $now)),
            self::SUBSCRIPTION_EXPIRED => $query->where('subscription_status', self::SUBSCRIPTION_ACTIVE)
                ->where('subscription_expires_at', '<=', $now),
            default => $query->where('subscription_status', '<>', self::SUBSCRIPTION_ACTIVE),
        };
    }

    public function users()
    {
        return $this->hasMany(User::class);
    }

    /** The store's first owner: the account that registered it. */
    public function owner()
    {
        return $this->hasOne(User::class)->ofMany(['id' => 'min'], fn($query) => $query->where('role', UserRole::OWNER->value));
    }

    public function products()
    {
        return $this->hasMany(Product::class);
    }

    public function invitations()
    {
        return $this->hasMany(StoreInvitation::class);
    }

    public function statusChangedBy()
    {
        return $this->belongsTo(User::class, 'status_changed_by');
    }

    public function subscriptionChangedBy()
    {
        return $this->belongsTo(User::class, 'subscription_changed_by');
    }
}
