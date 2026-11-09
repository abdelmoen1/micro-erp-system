<?php

namespace App\Models;

use App\Models\Concerns\AppendOnly;
use Illuminate\Database\Eloquent\Model;

/** A confirmed payment, refund or reversal of a subscription order. Append-only; never card data. */
class SubscriptionPayment extends Model
{
    use AppendOnly;

    public const UPDATED_AT = null;

    public const KIND_PAYMENT = 'payment';
    public const KIND_REFUND = 'refund';
    public const KIND_REVERSAL = 'reversal';

    public const SOURCE_MANUAL = 'manual';
    public const SOURCE_PROVIDER = 'provider';

    protected $fillable = ['subscription_order_id', 'kind', 'source', 'amount', 'currency', 'method', 'transaction_reference', 'provider', 'recorded_by', 'paid_at'];

    protected function casts(): array
    {
        return ['amount' => 'decimal:2', 'paid_at' => 'datetime'];
    }

    public function recorder()
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }
}
