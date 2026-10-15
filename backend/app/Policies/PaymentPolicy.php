<?php

namespace App\Policies;

use App\Models\User;
use App\Policies\Concerns\ChecksRoles;

/**
 * D-12 (approved): every role may record real payments, including full
 * repayment of a customer's debts (pay-all). Reversals stay with owners and
 * managers. Debt write-offs are not payments and need their own authorization
 * when introduced; they must never be recorded through these abilities.
 */
class PaymentPolicy
{
    use ChecksRoles;

    public function create(User $user): bool
    {
        return true;
    }

    public function payAll(User $user): bool
    {
        return true;
    }

    public function reverse(User $user): bool
    {
        return $this->isOwnerOrManager($user);
    }
}
