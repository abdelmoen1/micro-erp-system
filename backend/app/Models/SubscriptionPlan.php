<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** A plan the platform admin manages (price, duration, features, limits). Not tenant-scoped. */
class SubscriptionPlan extends Model
{
    protected $fillable = ['name', 'description', 'duration_months', 'price', 'currency', 'features', 'limits', 'is_active', 'sort_order'];

    protected function casts(): array
    {
        return [
            'features' => 'array',
            'limits' => 'array',
            'is_active' => 'boolean',
            'price' => 'decimal:2',
            'duration_months' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    /** Active and priced: the only plans a store can order. */
    public function isOrderable(): bool
    {
        return $this->is_active && $this->price !== null && (float) $this->price > 0 && $this->currency !== null;
    }

    /** Feature codes this plan grants (NULL features = every feature). */
    public function featureCodes(): array
    {
        $all = array_keys(config('hisbah.features', []));

        return $this->features === null ? $all : array_values(array_intersect($all, $this->features));
    }

    public function snapshot(): array
    {
        return [
            'id' => $this->id,
            'code' => $this->code,
            'name' => $this->name,
            'duration_months' => $this->duration_months,
            'price' => $this->price,
            'currency' => $this->currency,
            'features' => $this->featureCodes(),
            'limits' => $this->limits ?? [],
        ];
    }

    public function scopeOrdered($query)
    {
        return $query->orderBy('sort_order')->orderBy('id');
    }
}
