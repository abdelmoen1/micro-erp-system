<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** The one free trial an owner mobile number has used. Only an HMAC of the number is stored. */
class TrialClaim extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['phone_hash', 'store_id', 'started_at', 'ends_at'];

    protected function casts(): array
    {
        return ['started_at' => 'datetime', 'ends_at' => 'datetime'];
    }

    public static function hashPhone(string $normalizedPhone): string
    {
        return hash_hmac('sha256', $normalizedPhone, (string) config('app.key'));
    }
}
