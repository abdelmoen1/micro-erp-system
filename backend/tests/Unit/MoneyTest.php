<?php

namespace Tests\Unit;

use App\Support\Money;
use InvalidArgumentException;
use PHPUnit\Framework\TestCase;

/**
 * T-0102-1: exact money helper.
 */
class MoneyTest extends TestCase
{
    public function test_normalizes_to_two_decimals(): void
    {
        $this->assertSame('12.50', Money::of('12.5'));
        $this->assertSame('7.00', Money::of(7));
        $this->assertSame('0.10', Money::of(0.1));
        $this->assertSame('0.00', Money::of(null));
        $this->assertSame('0.00', Money::of('-0.001'));
    }

    public function test_rounds_half_up(): void
    {
        $this->assertSame('1.01', Money::of('1.005'));
        $this->assertSame('1.00', Money::of('1.004'));
        $this->assertSame('-1.01', Money::of('-1.005'));
    }

    public function test_arithmetic_is_exact(): void
    {
        $this->assertSame('0.30', Money::add('0.10', '0.20'));
        $this->assertSame('0.00', Money::sub('0.30', Money::add('0.10', '0.20')));
        $this->assertSame('0.30', Money::sum(['0.10', 0.1, '0.10']));
        $this->assertSame('10.50', Money::times('3.50', 3));
        $this->assertTrue(Money::isZero(Money::sub('0.3', '0.30')));
        $this->assertSame(1, Money::compare('100.01', '100'));
        $this->assertSame('0.00', Money::maxZero('-5'));
    }

    public function test_rejects_non_numeric_values(): void
    {
        $this->expectException(InvalidArgumentException::class);
        Money::of('1e3');
    }
}
