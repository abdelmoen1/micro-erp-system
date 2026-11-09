<?php

namespace App\Models;

use App\Models\Concerns\AppendOnly;
use Illuminate\Database\Eloquent\Model;

/** One line of an order's history (status change, note, payment, activation). Append-only. */
class SubscriptionOrderEvent extends Model
{
    use AppendOnly;

    public const UPDATED_AT = null;

    protected $fillable = ['subscription_order_id', 'actor_id', 'type', 'from_status', 'to_status', 'note', 'data'];

    protected function casts(): array
    {
        return ['data' => 'array'];
    }

    public function actor()
    {
        return $this->belongsTo(User::class, 'actor_id');
    }
}
