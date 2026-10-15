<?php

namespace App\Http\Resources;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PaymentResource extends JsonResource
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
            'amount' => Money::of($this->amount),
            'method' => $this->method,
            'paid_at' => $this->paid_at,
            'notes' => $this->notes,
            'is_reversed' => (bool) $this->is_reversed,
            'reversed_at' => $this->reversed_at,
            'reversal_reason' => $this->reversal_reason,
        ];
    }
}
