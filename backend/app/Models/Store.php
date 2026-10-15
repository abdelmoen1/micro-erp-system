<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Models\User;

class Store extends Model
{
    protected $fillable = [
        'name',
        'phone',
        'address',
        'timezone',
    ];

    /** D-23 / CR-14: Gaza pilot default; each store may use its own zone. */
    public const DEFAULT_TIMEZONE = 'Asia/Gaza';

    public function businessTimezone(): string
    {
        return $this->timezone ?: self::DEFAULT_TIMEZONE;
    }

    public function users()
    {
        return $this->hasMany(User::class);
    }

    public function invitations()
    {
        return $this->hasMany(StoreInvitation::class);
    }
}
