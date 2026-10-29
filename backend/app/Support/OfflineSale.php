<?php

namespace App\Support;

use Carbon\CarbonImmutable;

/**
 * How a sale that happened offline differs from a counter sale (doc 16 §4, D-03): it is recorded
 * at the time it happened, with the prices the cashier charged, and a mismatch with the server's
 * current data becomes a review flag instead of a refusal, because the goods already left the shop.
 */
final class OfflineSale
{
    /** @var array<string, string> charged unit price by "product_id|sale_unit" */
    private array $charged = [];

    /**
     * @param  list<array{product_id: int|string, sale_unit?: ?string, unit_price: string}>  $charged
     */
    public function __construct(
        public readonly CarbonImmutable $occurredAt,
        public readonly string $deviceId,
        array $charged = [],
    ) {
        foreach ($charged as $line) {
            $this->charged[self::key($line['product_id'], $line['sale_unit'] ?? null)] = Money::of($line['unit_price']);
        }
    }

    /** The unit price the cashier charged for this line, or null when the device did not say. */
    public function chargedPrice(int|string $productId, ?string $saleUnit): ?string
    {
        return $this->charged[self::key($productId, $saleUnit)] ?? null;
    }

    private static function key(int|string $productId, ?string $saleUnit): string
    {
        return (int) $productId . '|' . ($saleUnit ?? '');
    }
}
