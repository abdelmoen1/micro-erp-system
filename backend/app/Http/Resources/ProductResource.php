<?php

namespace App\Http\Resources;

use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Quantities are strings in the product's unit: "12" pieces, "2.500" kg (doc 15 §4). */
class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'barcode' => $this->barcode,
            'unit' => $this->unit,
            'selling_price' => Money::of($this->selling_price),
            'cost_price' => $this->cost_price === null ? null : Money::of($this->cost_price),
            'current_stock' => Quantity::format($this->current_stock, $this->unit),
            'minimum_stock' => Quantity::format($this->minimum_stock, $this->unit),
            'is_low_stock' => Quantity::compare($this->current_stock, $this->minimum_stock) <= 0,
            'status' => $this->status,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
