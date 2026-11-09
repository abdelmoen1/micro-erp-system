<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A store's request to buy a plan: manual (WhatsApp on the website, confirmed by a platform admin)
 * or online (a payment provider's verified notification). Only a confirmed payment activates it.
 */
class SubscriptionOrder extends Model
{
    public const CHANNEL_MANUAL = 'manual_whatsapp';
    public const CHANNEL_ONLINE = 'online';

    public const PENDING_CONTACT = 'pending_contact';
    public const AWAITING_PAYMENT = 'awaiting_payment';
    public const PAYMENT_VERIFICATION = 'payment_verification';
    public const PAID = 'paid';
    public const REJECTED = 'rejected';
    public const CANCELLED = 'cancelled';
    /** Online only: the provider reported a failed or abandoned payment. */
    public const FAILED = 'failed';

    public const OPEN = [self::PENDING_CONTACT, self::AWAITING_PAYMENT, self::PAYMENT_VERIFICATION];

    /** Status moves an admin may make by hand. `paid` is reached only through a confirmed payment. */
    public const MANUAL_TRANSITIONS = [
        self::PENDING_CONTACT => [self::AWAITING_PAYMENT, self::PAYMENT_VERIFICATION, self::REJECTED, self::CANCELLED],
        self::AWAITING_PAYMENT => [self::PAYMENT_VERIFICATION, self::PENDING_CONTACT, self::REJECTED, self::CANCELLED],
        self::PAYMENT_VERIFICATION => [self::AWAITING_PAYMENT, self::REJECTED, self::CANCELLED],
    ];

    protected $fillable = [
        'store_id', 'store_name', 'requested_by', 'subscription_plan_id', 'plan_snapshot', 'duration_months',
        'amount', 'currency', 'channel', 'provider', 'provider_reference', 'status',
    ];

    protected function casts(): array
    {
        return [
            'plan_snapshot' => 'array',
            'amount' => 'decimal:2',
            'duration_months' => 'integer',
            'reviewed_at' => 'datetime',
            'paid_at' => 'datetime',
            'activated_at' => 'datetime',
            'period_starts_at' => 'datetime',
            'period_ends_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (self $order) {
            $order->reference ??= self::newReference();
        });
    }

    /** HSB- + 10 unambiguous characters: short enough to read out on WhatsApp, not guessable. */
    public static function newReference(): string
    {
        $alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
        do {
            $code = '';
            for ($i = 0; $i < 10; $i++) {
                $code .= $alphabet[random_int(0, strlen($alphabet) - 1)];
            }
            $reference = 'HSB-' . $code;
        } while (self::where('reference', $reference)->exists());

        return $reference;
    }

    public function isOpen(): bool
    {
        return in_array($this->status, self::OPEN, true);
    }

    public function store()
    {
        return $this->belongsTo(Store::class);
    }

    public function plan()
    {
        return $this->belongsTo(SubscriptionPlan::class, 'subscription_plan_id');
    }

    public function requester()
    {
        return $this->belongsTo(User::class, 'requested_by');
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    public function payments()
    {
        return $this->hasMany(SubscriptionPayment::class)->orderBy('id');
    }

    public function events()
    {
        return $this->hasMany(SubscriptionOrderEvent::class)->orderBy('id');
    }
}
