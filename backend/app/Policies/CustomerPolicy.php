<?php

namespace App\Policies;

use App\Models\Customer;
use App\Models\User;
use App\Policies\Concerns\ChecksRoles;

class CustomerPolicy
{
    use ChecksRoles;

    /** US-0305 AC1 (D-26: Owner / Manager set the limit). */
    public function setCreditLimit(User $user): bool
    {
        return $this->isOwnerOrManager($user);
    }

    public function delete(User $user, Customer $customer): bool
    {
        return $this->isOwnerOrManager($user) && $this->sameStore($user, $customer);
    }
}
