<?php

namespace App\Models;

use App\Enums\UserRole;
// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use App\Traits\BelongsToStore;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use BelongsToStore, HasApiTokens, HasFactory, Notifiable;

    public const STATUS_ACTIVE = 'active';
    public const STATUS_INACTIVE = 'inactive';
    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'phone',
        'password',
        'role',
    ];

    /** Matches the column default, so a just-created user serializes the flag too. */
    protected $attributes = [
        'is_platform_admin' => false,
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
        'google_id',
        // Accounts sign in with their phone only; an old e-mail is never shown or sent.
        'email',
        'email_verified_at',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'role' => UserRole::class,
            'deactivated_at' => 'datetime',
            'is_platform_admin' => 'boolean',
        ];
    }

    /**
     * The platform owner. Deliberately not fillable: only `php artisan hisbah:platform-admin`
     * grants it, never a registration or any other API request.
     */
    public function isPlatformAdmin(): bool
    {
        return (bool) $this->is_platform_admin;
    }

    public function isActive(): bool
    {
        return ($this->status ?? self::STATUS_ACTIVE) === self::STATUS_ACTIVE;
    }

    public function store()
    {
        return $this->belongsTo(Store::class);
    }

    public function invitations()
    {
        return $this->hasMany(StoreInvitation::class, 'invited_by');
    }

    public function hasRole(UserRole|string|array ...$roles): bool
    {
        $roles = count($roles) === 1 && is_array($roles[0])
            ? $roles[0]
            : $roles;

        return in_array($this->role instanceof UserRole ? $this->role->value : $this->role, array_map(
            fn(UserRole|string $role) => $role instanceof UserRole ? $role->value : $role,
            $roles,
        ), true);
    }
}
