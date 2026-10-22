<?php

namespace App\Http\Resources;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DebtResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        // US-0701 AC3: original, paid, returned, remaining, customer, invoice, created_at, due_date, status.
        return [
            'id' => $this->id,
            'invoice_id' => $this->invoice?->id,
            'source' => $this->invoice?->source?->value,
            'customer_id' => $this->customer_id,
            'customer' => new CustomerResource($this->whenLoaded('customer')),
            'amount' => Money::of($this->amount),
            'total_payments' => Money::sum($this->payments->where('is_reversed', false)->pluck('amount')),
            'return_credit' => Money::of($this->return_credit),
            'remaining_amount' => Money::of($this->remaining_amount),
            'due_date' => $this->due_date?->toDateString(),
            'status' => $this->status,
            'created_at' => $this->created_at,
        ];
    }
}
