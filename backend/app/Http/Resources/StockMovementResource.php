<?php

namespace App\Http\Resources;

use App\Support\Quantity;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Quantities are strings in the product's unit (doc 15 §4); load `product` so kg keeps 3 decimals. */
class StockMovementResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $unit = $this->relationLoaded('product') ? $this->product?->unit : null;

        return [
            'id' => $this->id,
            'product_id' => $this->product_id,
            'type' => $this->type,
            'quantity' => Quantity::format($this->quantity, $unit),
            'balance_after' => Quantity::format($this->balance_after, $unit),
            'reason' => $this->reason,
            'reference_type' => $this->reference_type,
            'reference_id' => $this->reference_id,
            'created_by' => $this->created_by,
            'created_at' => $this->created_at,
        ];
    }
}
