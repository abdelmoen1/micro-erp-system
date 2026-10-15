<?php

namespace App\Policies;

use App\Enums\UserRole;
use App\Models\User;

/**
 * Staff administration is owner-only. The owner role can never be assigned,
 * changed or deactivated through the API (DEF-04, D-13).
 */
class UserPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasRole(UserRole::OWNER);
    }

    public function invite(User $user): bool
    {
        return $user->hasRole(UserRole::OWNER);
    }

    public function updateRole(User $user, User $target): bool
    {
        return $this->manages($user, $target);
    }

    public function deactivate(User $user, User $target): bool
    {
        return $this->manages($user, $target);
    }

    private function manages(User $user, User $target): bool
    {
        return $user->hasRole(UserRole::OWNER)
            && $user->store_id === $target->store_id
            && $user->id !== $target->id
            && !$target->hasRole(UserRole::OWNER);
    }
}
