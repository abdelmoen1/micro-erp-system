<?php

namespace App\Models;

use App\Enums\UserRole;
// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;
    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
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
        ];
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
        $flattenedRoles = [];

        foreach ($roles as $role) {
            if (is_array($role)) {
                foreach ($role as $nestedRole) {
                    $flattenedRoles[] = $nestedRole;
                }

                continue;
            }

            $flattenedRoles[] = $role;
        }

        return in_array(
            $this->role instanceof UserRole ? $this->role->value : $this->role,
            array_map(
                fn (UserRole|string $role) => $role instanceof UserRole
                    ? $role->value
                    : $role,
                $flattenedRoles,
            ),
            true,
        );
    }
}
