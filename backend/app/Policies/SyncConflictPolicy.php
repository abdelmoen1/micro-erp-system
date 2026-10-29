<?php

namespace App\Policies;

use App\Models\SyncConflict;
use App\Models\User;
use App\Policies\Concerns\ChecksRoles;

/** 05 §6: resolving sync conflicts is Owner / Manager (R2, US-1106). */
class SyncConflictPolicy
{
    use ChecksRoles;

    public function viewAny(User $user): bool
    {
        return $this->isOwnerOrManager($user);
    }

    public function resolve(User $user, SyncConflict $conflict): bool
    {
        return $this->isOwnerOrManager($user) && $this->sameStore($user, $conflict);
    }
}
