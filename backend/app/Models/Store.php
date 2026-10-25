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
 *
 * Every new store starts a free trial (trial_ends_at = registration time + config hisbah.trial_days).
 * The store may use the business API while it has a valid paid subscription or a running trial
 * (hasAccess(), enforced by EnsureStoreSubscription); its data is kept either way.
 */
class Store extends Model
{
    protected $fillable = [
        'name',
        'phone',
        'address',
        'area',
        'latitude',
        'longitude',
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

    /** What the store's own clients need to route an expired store to the renewal screen. */
    protected $appends = [
        'subscription_state',
        'has_access',
    ];

    /** D-23 / CR-14: Gaza pilot default; each store may use its own zone. */
    public const DEFAULT_TIMEZONE = 'Asia/Gaza';

    public const STATUS_ACTIVE = 'active';

    public const STATUS_SUSPENDED = 'suspended';

    public const SUBSCRIPTION_ACTIVE = 'active';

    public const SUBSCRIPTION_INACTIVE = 'inactive';

    /** Derived: an active subscription whose expiry date has passed. */
    public const SUBSCRIPTION_EXPIRED = 'expired';

    /** Derived: no valid paid subscription, but the free trial has not ended. */
    public const SUBSCRIPTION_TRIAL = 'trial';

    protected function casts(): array
    {
        return [
            'status_changed_at' => 'datetime',
            'subscription_started_at' => 'datetime',
            'subscription_expires_at' => 'datetime',
            'subscription_changed_at' => 'datetime',
            'trial_ends_at' => 'datetime',
            'latitude' => 'float',
            'longitude' => 'float',
        ];
    }

    protected static function booted(): void
    {
        // The trial runs from the registration time itself, for every way a store is created.
        static::creating(function (Store $store) {
            $store->created_at ??= $store->freshTimestamp();
            $store->trial_ends_at ??= $store->created_at->copy()->addDays(self::trialDays());
        });
    }

    public static function trialDays(): int
    {
        return max(0, (int) config('hisbah.trial_days', 7));
    }

    public function businessTimezone(): string
    {
        return $this->timezone ?: self::DEFAULT_TIMEZONE;
    }

    public function isSuspended(): bool
    {
        return ($this->status ?? self::STATUS_ACTIVE) === self::STATUS_SUSPENDED;
    }

    /** A paid subscription the admin activated, with no expiry or one still ahead. */
    public function hasPaidSubscription(): bool
    {
        return $this->subscription_status === self::SUBSCRIPTION_ACTIVE
            && (!$this->subscription_expires_at || $this->subscription_expires_at->isFuture());
    }

    /** The trial is running until trial_ends_at, exclusive. */
    public function inTrial(): bool
    {
        return $this->trial_ends_at !== null && $this->trial_ends_at->isFuture();
    }

    /**
     * active (paid) | trial | expired (paid, past its expiry) | inactive (never paid, trial over), as of now.
     * A valid paid subscription wins over the trial; a running trial wins over a lapsed subscription.
     */
    public function subscriptionState(): string
    {
        if ($this->hasPaidSubscription()) {
            return self::SUBSCRIPTION_ACTIVE;
        }
        if ($this->inTrial()) {
            return self::SUBSCRIPTION_TRIAL;
        }

        return $this->subscription_status === self::SUBSCRIPTION_ACTIVE
            ? self::SUBSCRIPTION_EXPIRED
            : self::SUBSCRIPTION_INACTIVE;
    }

    /** Whether the store may use the business API (separate from account suspension). */
    public function hasAccess(): bool
    {
        return in_array($this->subscriptionState(), [self::SUBSCRIPTION_ACTIVE, self::SUBSCRIPTION_TRIAL], true);
    }

    public function getSubscriptionStateAttribute(): string
    {
        return $this->subscriptionState();
    }

    public function getHasAccessAttribute(): bool
    {
        return $this->hasAccess();
    }

    /** The same four states as subscriptionState(), as a query filter. */
    public function scopeSubscriptionState(Builder $query, string $state): Builder
    {
        $now = now();
        $paid = fn($q) => $q->where('subscription_status', self::SUBSCRIPTION_ACTIVE)
            ->where(fn($q) => $q->whereNull('subscription_expires_at')->orWhere('subscription_expires_at', '>', $now));
        $trialOver = fn($q) => $q->whereNull('trial_ends_at')->orWhere('trial_ends_at', '<=', $now);

        return match ($state) {
            self::SUBSCRIPTION_ACTIVE => $query->where($paid),
            self::SUBSCRIPTION_TRIAL => $query->whereNot($paid)->where('trial_ends_at', '>', $now),
            self::SUBSCRIPTION_EXPIRED => $query->where('subscription_status', self::SUBSCRIPTION_ACTIVE)
                ->where('subscription_expires_at', '<=', $now)
                ->where($trialOver),
            default => $query->where('subscription_status', '<>', self::SUBSCRIPTION_ACTIVE)->where($trialOver),
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
