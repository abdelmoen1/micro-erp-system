<?php

namespace App\Policies;

use App\Models\Debt;
use App\Models\User;
use App\Policies\Concerns\ChecksRoles;

/**
 * Opening (pre-existing) debts are created, edited and removed only by
 * owners and managers (05 §6).
 */
class DebtPolicy
{
    use ChecksRoles;

    public function create(User $user): bool
    {
        return $this->isOwnerOrManager($user);
    }

    public function update(User $user, Debt $debt): bool
    {
        return $this->isOwnerOrManager($user) && $this->sameStore($user, $debt);
    }

    public function delete(User $user, Debt $debt): bool
    {
        return $this->isOwnerOrManager($user) && $this->sameStore($user, $debt);
    }
}
