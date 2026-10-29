<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** A one-time SMS code (hashed) for one phone and one purpose; it works once, within its minutes. */
class PhoneOtp extends Model
{
    public const PURPOSE_REGISTER = 'register';

    public const PURPOSE_RESET = 'reset';

    public const PURPOSE_CHANGE_PHONE = 'change_phone';

    public const PURPOSES = [self::PURPOSE_REGISTER, self::PURPOSE_RESET, self::PURPOSE_CHANGE_PHONE];

    protected $fillable = ['phone', 'purpose', 'code_hash', 'attempts', 'expires_at', 'consumed_at', 'ip'];

    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
            'consumed_at' => 'datetime',
            'attempts' => 'integer',
        ];
    }
}
