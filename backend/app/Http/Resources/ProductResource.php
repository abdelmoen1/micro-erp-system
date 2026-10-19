<?php

namespace App\Http\Resources;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'barcode' => $this->barcode,
            'selling_price' => Money::of($this->selling_price),
            'cost_price' => $this->cost_price === null ? null : Money::of($this->cost_price),
            'current_stock' => $this->current_stock,
            'minimum_stock' => $this->minimum_stock,
            'is_low_stock' => $this->current_stock <= $this->minimum_stock,
            'status' => $this->status,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
