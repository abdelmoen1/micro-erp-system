<?php

namespace App\Policies;

use App\Models\Product;
use App\Models\User;
use App\Policies\Concerns\ChecksRoles;

/** US-0401 AC5: reading is open to every role; writing is Owner / Manager only (05 §API). */
class ProductPolicy
{
    use ChecksRoles;

    public function create(User $user): bool
    {
        return $this->isOwnerOrManager($user);
    }

    public function update(User $user, Product $product): bool
    {
        return $this->isOwnerOrManager($user) && $this->sameStore($user, $product);
    }
}
