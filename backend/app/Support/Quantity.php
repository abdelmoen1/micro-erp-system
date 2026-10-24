<?php

namespace App\Support;

use InvalidArgumentException;

/**
 * Exact stock quantities for pieces and weighed goods (CR-13 modified, doc 15 §4), using bcmath.
 * Stored as DECIMAL(12,3); a `piece` quantity is whole, a `kg` quantity has up to 3 decimals (1 g).
 * The API carries quantities as strings: "3" for pieces, "0.750" for kg.
 */
final class Quantity
{
    public const SCALE = 3;

    public const UNIT_PIECE = 'piece';

    public const UNIT_KG = 'kg';

    public const UNITS = [self::UNIT_PIECE, self::UNIT_KG];

    public const MAX = '1000000';

    public static function of(int|float|string|null $value): string
    {
        if ($value === null || $value === '') {
            return '0.000';
        }

        if (is_int($value)) {
            return bcadd((string) $value, '0', self::SCALE);
        }

        if (is_float($value)) {
            // Only database reads arrive as floats (sqlite REAL); they are already 3-decimal values.
            $value = number_format($value, self::SCALE, '.', '');
        }

        $value = trim($value);

        if (!preg_match('/^-?\d+(\.\d+)?$/', $value)) {
            throw new InvalidArgumentException("Invalid quantity [{$value}].");
        }

        $rounded = bcadd($value, '0', self::SCALE);

        return $rounded === '-0.000' ? '0.000' : $rounded;
    }

    public static function add(int|float|string|null $a, int|float|string|null $b): string
    {
        return bcadd(self::of($a), self::of($b), self::SCALE);
    }

    public static function sub(int|float|string|null $a, int|float|string|null $b): string
    {
        return bcsub(self::of($a), self::of($b), self::SCALE);
    }

    public static function negate(int|float|string|null $value): string
    {
        return self::sub('0', $value);
    }

    public static function compare(int|float|string|null $a, int|float|string|null $b): int
    {
        return bccomp(self::of($a), self::of($b), self::SCALE);
    }

    public static function isNegative(int|float|string|null $value): bool
    {
        return self::compare($value, '0') < 0;
    }

    public static function isZero(int|float|string|null $value): bool
    {
        return self::compare($value, '0') === 0;
    }

    public static function isWhole(int|float|string|null $value): bool
    {
        return str_ends_with(self::of($value), '.000');
    }

    /** True when the value is valid for the unit: pieces are whole, kg has at most 3 decimals. */
    public static function fitsUnit(int|float|string|null $value, ?string $unit): bool
    {
        return $unit === self::UNIT_KG || self::isWhole($value);
    }

    /** API form: "3" for pieces, "0.750" for kg. */
    public static function format(int|float|string|null $value, ?string $unit): string
    {
        $quantity = self::of($value);

        return $unit === self::UNIT_KG ? $quantity : substr($quantity, 0, -4);
    }

    /** Validation rules for a quantity input in a given unit (null = unit unknown yet: up to 3 decimals). */
    public static function inputRules(?string $unit, bool $signed = false): array
    {
        return [
            'numeric',
            $unit === self::UNIT_PIECE ? 'integer' : 'decimal:0,3',
            $signed ? 'min:-' . self::MAX : 'gt:0',
            'max:' . self::MAX,
        ];
    }
}
