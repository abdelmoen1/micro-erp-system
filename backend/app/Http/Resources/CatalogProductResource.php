<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** The shared identity only: no prices, stock or creating store leave a store through it. */
class CatalogProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'barcode' => $this->barcode,
            'name' => $this->name,
            'unit' => $this->unit,
        ];
    }
}
