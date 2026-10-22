<?php

namespace App\Policies;

use App\Models\Invoice;
use App\Models\User;
use App\Policies\Concerns\ChecksRoles;

/**
 * Authorization matrix (05 §6, D-12). Employees may create sales but not
 * change or remove them: DEF-05 containment until void/notes-only (US-0503).
 */
class InvoicePolicy
{
    use ChecksRoles;

    public function create(User $user): bool
    {
        return true;
    }

    public function update(User $user, Invoice $invoice): bool
    {
        return $this->isOwnerOrManager($user) && $this->sameStore($user, $invoice);
    }

    /** US-0503 (D-06): the only correction of a sale. There is no delete. */
    public function void(User $user, Invoice $invoice): bool
    {
        return $this->isOwnerOrManager($user) && $this->sameStore($user, $invoice);
    }

    /** US-0601 AC6: returns are Owner / Manager only. */
    public function return(User $user, Invoice $invoice): bool
    {
        return $this->isOwnerOrManager($user) && $this->sameStore($user, $invoice);
    }
}
