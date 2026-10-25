<?php

namespace App\Http\Resources;

use App\Support\Money;
use Illuminate\Http\Request;

/**
 * A shared catalog item in the platform admin's list: the identity plus how many stores carry it
 * and the range of their selling prices (active rows only). Admin-only: the store-facing
 * CatalogProductResource never carries prices.
 */
class AdminCatalogProductResource extends CatalogProductResource
{
    public function toArray(Request $request): array
    {
        return parent::toArray($request) + [
            'stores_count' => (int) $this->stores_count,
            'active_stores_count' => (int) $this->active_stores_count,
            'price_min' => $this->price_min === null ? null : Money::of($this->price_min),
            'price_max' => $this->price_max === null ? null : Money::of($this->price_max),
            'created_at' => $this->created_at,
        ];
    }
}
