<?php

namespace App\Http\Resources;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DebtDetailsResource extends JsonResource
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

            'total_payments' => Money::sum($this->payments->where('is_reversed', false)->pluck('amount')),

            'remaining_amount' => Money::of($this->remaining_amount),

            'payments' => PaymentResource::collection(
                $this->whenLoaded('payments')
            ),

            'invoice' => [
                'id' => $this->invoice->id,

                'customer' => new CustomerResource(
                    $this->invoice->customer
                ),

                'total_amount' => Money::of($this->invoice->total_amount),

                'items' => InvoiceItemResource::collection(
                    $this->invoice->items
                ),
            ],
        ];
    }
}
