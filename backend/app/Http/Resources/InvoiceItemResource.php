<?php

namespace App\Http\Resources;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InvoiceItemResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'item_name' => $this->item_name,
            'quantity' => (int) $this->quantity,
            'unit_price' => Money::of($this->unit_price),
            'total' => Money::of($this->total),
        ];
    }
}
