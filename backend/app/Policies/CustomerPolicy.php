<?php

namespace App\Policies;

use App\Models\Customer;
use App\Models\User;
use App\Policies\Concerns\ChecksRoles;

class CustomerPolicy
{
    use ChecksRoles;

    public function delete(User $user, Customer $customer): bool
    {
        return $this->isOwnerOrManager($user) && $this->sameStore($user, $customer);
    }
}
