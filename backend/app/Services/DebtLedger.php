<?php

namespace App\Services;

use App\Models\Debt;
use App\Support\Money;

/**
 * Derives a debt's remaining amount and status from its non-reversed payments
 * (integrity rules 5 and 6 in the data-model contract).
 */
class DebtLedger
{
    public function recalculate(Debt $debt): Debt
    {
        $paid = Money::sum(
            $debt->payments()->where('is_reversed', false)->pluck('amount')
        );

        $debt->remaining_amount = Money::maxZero(Money::sub($debt->amount, $paid));
        $debt->status = self::status($debt->amount, $debt->remaining_amount);
        $debt->save();

        return $debt;
    }

    public static function status(string $amount, string $remaining): string
    {
        if (Money::isZero($remaining)) {
            return 'paid';
        }

        return Money::compare($remaining, $amount) < 0 ? 'partially_paid' : 'unpaid';
    }
}
