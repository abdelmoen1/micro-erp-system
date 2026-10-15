<?php

namespace App\Policies\Concerns;

use App\Enums\UserRole;
use App\Models\User;

trait ChecksRoles
{
    private function isOwnerOrManager(User $user): bool
    {
        return $user->hasRole(UserRole::OWNER, UserRole::MANAGER);
    }

    private function sameStore(User $user, object $model): bool
    {
        return isset($model->store_id) && (int) $model->store_id === (int) $user->store_id;
    }
}
