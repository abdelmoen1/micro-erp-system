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
        return [
            'id' => $this->id,
            'invoice_id' => $this->invoice?->id,
            'source' => $this->invoice?->source?->value,
            'amount' => Money::of($this->amount),
            'total_payments' => Money::sum($this->payments->where('is_reversed', false)->pluck('amount')),
            'remaining_amount' => Money::of($this->remaining_amount),
            'status' => $this->status,
        ];
    }
}
