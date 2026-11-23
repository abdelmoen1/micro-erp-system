<?php

namespace App\Http\Requests;

final class PaymentMethods
{
    public const ALL = ['cash', 'jawwal_pay', 'palpay', 'bank_of_palestine'];

    public const TRANSFER_PROVIDERS = ['jawwal_pay', 'palpay', 'bank_of_palestine'];
}
