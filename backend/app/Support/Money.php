<?php

namespace App\Support;

use InvalidArgumentException;

/**
 * Exact money arithmetic in agorot precision (2 decimals, ILS), using bcmath.
 * Every value leaves this class as a normalized string such as "12.50" (D-09).
 */
final class Money
{
    public const SCALE = 2;

    public const CURRENCY = 'ILS';

    public const MAX = '99999999.99';

    /** Validation rules for a positive money input with at most 2 decimals. */
    public static function inputRules(): array
    {
        return ['numeric', 'decimal:0,2', 'gt:0', 'max:' . self::MAX];
    }

    public static function of(int|float|string|null $value): string
    {
        if ($value === null || $value === '') {
            return '0.00';
        }

        if (is_int($value)) {
            return bcadd((string) $value, '0', self::SCALE);
        }

        if (is_float($value)) {
            // Only database reads arrive as floats (sqlite REAL); they are already 2-decimal values.
            $value = number_format($value, self::SCALE, '.', '');
        }

        $value = trim($value);

        if (!preg_match('/^-?\d+(\.\d+)?$/', $value)) {
            throw new InvalidArgumentException("Invalid money value [{$value}].");
        }

        return self::roundHalfUp($value);
    }

    public static function add(int|float|string|null $a, int|float|string|null $b): string
    {
        return bcadd(self::of($a), self::of($b), self::SCALE);
    }

    public static function sub(int|float|string|null $a, int|float|string|null $b): string
    {
        return bcsub(self::of($a), self::of($b), self::SCALE);
    }

    /**
     * Line total: unit price × quantity, rounded half-up to 2 decimals (doc 15 §4).
     * The quantity may be whole (pieces) or have up to 3 decimals (kg).
     */
    public static function times(int|float|string|null $unitPrice, int|float|string $quantity): string
    {
        $exact = bcmul(self::of($unitPrice), Quantity::of($quantity), self::SCALE + Quantity::SCALE);

        return self::of($exact);
    }

    public static function sum(iterable $values): string
    {
        $total = '0.00';

        foreach ($values as $value) {
            $total = self::add($total, $value);
        }

        return $total;
    }

    public static function compare(int|float|string|null $a, int|float|string|null $b): int
    {
        return bccomp(self::of($a), self::of($b), self::SCALE);
    }

    public static function isZero(int|float|string|null $value): bool
    {
        return self::compare($value, '0') === 0;
    }

    public static function isPositive(int|float|string|null $value): bool
    {
        return self::compare($value, '0') > 0;
    }

    public static function maxZero(int|float|string|null $value): string
    {
        return self::isPositive($value) ? self::of($value) : '0.00';
    }

    private static function roundHalfUp(string $value): string
    {
        $negative = str_starts_with($value, '-');
        $offset = '0.' . str_repeat('0', self::SCALE) . '5';

        $rounded = $negative
            ? bcsub($value, $offset, self::SCALE)
            : bcadd($value, $offset, self::SCALE);

        return $rounded === '-0.00' ? '0.00' : $rounded;
    }
}
