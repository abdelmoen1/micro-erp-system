<?php

namespace App\Services;

use App\Models\Debt;
use App\Support\Money;

/**
 * Derives a debt's remaining amount and status from its return credit and non-reversed payments
 * (integrity rules 5 and 6 in the data-model contract).
 */
class DebtLedger
{
    public function recalculate(Debt $debt): Debt
    {
        // A voided sale's debt stays cancelled with nothing remaining (US-0503).
        if ($debt->status === Debt::STATUS_CANCELLED) {
            return $debt;
        }

        $paid = Money::sum(
            $debt->payments()->where('is_reversed', false)->pluck('amount')
        );

        $owed = Money::sub($debt->amount, $debt->return_credit);
        $debt->remaining_amount = Money::maxZero(Money::sub($owed, $paid));
        $debt->status = self::status($owed, $debt->remaining_amount);
        $debt->save();

        return $debt;
    }

    /** @param string $amount what is owed after return credit (amount − return_credit) */
    public static function status(string $amount, string $remaining): string
    {
        if (Money::isZero($remaining)) {
            return 'paid';
        }

        return Money::compare($remaining, $amount) < 0 ? 'partially_paid' : 'unpaid';
    }
}
