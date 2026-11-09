<?php

namespace App\Services\Payments;

use RuntimeException;

/** A webhook that failed signature/authenticity checks or could not be parsed. */
class InvalidPaymentNotification extends RuntimeException {}
