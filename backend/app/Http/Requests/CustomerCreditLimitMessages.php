<?php

namespace App\Http\Requests;

/** Arabic validation messages for the customer credit limit (US-0305). */
final class CustomerCreditLimitMessages
{
    public static function all(): array
    {
        return [
            'credit_limit.numeric' => 'سقف الدين يجب أن يكون رقمًا',
            'credit_limit.decimal' => 'سقف الدين يقبل خانتين عشريتين كحد أقصى',
            'credit_limit.min' => 'سقف الدين لا يمكن أن يكون سالبًا',
            'credit_limit.max' => 'سقف الدين أكبر من الحد المسموح',
        ];
    }
}
