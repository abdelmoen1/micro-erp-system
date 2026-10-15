<?php

namespace App\Support;

use App\Models\Store;
use Carbon\CarbonImmutable;
use DateTimeInterface;

/**
 * Business dates in the store's own timezone (US-0107, D-23 / CR-14).
 * Database timestamps are UTC; bounds are converted before querying.
 */
final class BusinessClock
{
    public function __construct(private readonly string $timezone) {}

    public static function forStore(Store $store): self
    {
        return new self($store->businessTimezone());
    }

    public function timezone(): string
    {
        return $this->timezone;
    }

    public function now(): CarbonImmutable
    {
        return CarbonImmutable::now($this->timezone);
    }

    /**
     * @return array{0: CarbonImmutable, 1: CarbonImmutable} local start and end of the period
     */
    public function periodBounds(string $period): array
    {
        $now = $this->now();

        return match ($period) {
            'today' => [$now->startOfDay(), $now->endOfDay()],
            'this_week' => [$now->startOfWeek(), $now->endOfWeek()],
            'this_year' => [$now->startOfYear(), $now->endOfYear()],
            default => [$now->startOfMonth(), $now->endOfMonth()],
        };
    }

    /**
     * Local bounds as UTC values for comparison with stored timestamps.
     *
     * @return array{0: CarbonImmutable, 1: CarbonImmutable}
     */
    public static function toUtc(CarbonImmutable $from, CarbonImmutable $to): array
    {
        return [$from->utc(), $to->utc()];
    }

    /** The local calendar date (Y-m-d) of a stored UTC timestamp. */
    public function localDate(DateTimeInterface|string $utcTimestamp): string
    {
        $moment = $utcTimestamp instanceof DateTimeInterface
            ? CarbonImmutable::instance($utcTimestamp)
            : CarbonImmutable::parse($utcTimestamp, 'UTC');

        return $moment->setTimezone($this->timezone)->format('Y-m-d');
    }
}
