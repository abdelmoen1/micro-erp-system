<?php

namespace App\Services\Payments;

use Illuminate\Contracts\Container\Container;

/**
 * The providers that may be offered: `enabled` in config/payments.php AND a `driver` class that
 * implements PaymentProvider. Today none qualifies, so online payment is reported unavailable.
 */
class PaymentProviderRegistry
{
    public function __construct(private readonly Container $container) {}

    /** @return array<string, string> key => label */
    public function available(): array
    {
        $out = [];
        foreach (config('payments.providers', []) as $key => $settings) {
            if ($this->resolvable($settings)) {
                $out[$key] = $settings['label'] ?? $key;
            }
        }

        return $out;
    }

    public function get(string $key): ?PaymentProvider
    {
        $settings = config("payments.providers.{$key}");
        if (!is_array($settings) || !$this->resolvable($settings)) {
            return null;
        }
        $provider = $this->container->make($settings['driver']);

        return $provider instanceof PaymentProvider ? $provider : null;
    }

    private function resolvable(array $settings): bool
    {
        $driver = $settings['driver'] ?? null;

        return ($settings['enabled'] ?? false) === true
            && is_string($driver) && class_exists($driver)
            && is_subclass_of($driver, PaymentProvider::class);
    }
}
