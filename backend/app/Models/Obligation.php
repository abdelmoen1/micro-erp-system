<?php

namespace App\Models;

use App\Support\Money;
use App\Traits\BelongsToStore;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * A running cost of the store (rent, electricity, salaries…): an amount per day, week, month or
 * year. Home takes each day's share of the active ones off the day's profit.
 */
class Obligation extends Model
{
    use BelongsToStore, SoftDeletes;

    public const FREQUENCIES = ['daily', 'weekly', 'monthly', 'yearly'];

    protected $fillable = ['store_id', 'name', 'amount', 'frequency', 'active', 'created_by', 'updated_by'];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'active' => 'boolean',
            'deleted_at' => 'datetime',
        ];
    }

    /**
     * This obligation's cost for one local day (a month's rent spread over that month's days), to
     * 6 decimals: callers add the days up and round once, so a whole month sums to the rent.
     */
    public function shareOn(CarbonImmutable $day): string
    {
        $days = match ($this->frequency) {
            'daily' => 1,
            'weekly' => 7,
            'yearly' => $day->isLeapYear() ? 366 : 365,
            default => $day->daysInMonth,
        };

        return bcdiv(Money::of($this->amount), (string) $days, 6);
    }
}
