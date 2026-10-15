<?php

namespace App\Http\Resources;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InvoiceResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'source' => $this->source,
            'has_debt' => (bool) $this->has_debt,
            'payment_method' => $this->payment_method,
            'total_amount' => Money::of($this->total_amount),
            'items' => InvoiceItemResource::collection($this->whenLoaded('items')),
            'customer' => new CustomerResource($this->whenLoaded('customer')),
            'debt' => new DebtResource($this->whenLoaded('debt')),
        ];
    }
}
