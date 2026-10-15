<?php

namespace App\Http\Resources;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PaymentOperationResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'type' => $this->type,
            'payment_group_id' => $this->payment_group_id,


            'total_amount' => Money::of($this->total_amount),

            'method' => $this->method,

            'paid_at' => $this->paid_at,

            'is_reversed' => $this->is_reversed,

            'reversed_at' => $this->reversed_at,

            'reversal_reason' => $this->reversal_reason,

            'payments' => PaymentResource::collection(
                $this->payments
            ),
            'customer' => $this->customer
                ? new CustomerResource($this->customer)
                : null,
        ];
    }
}
