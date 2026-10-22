<?php

namespace App\Http\Resources;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CustomerResource extends JsonResource
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
            'name' => $this->name,
            'phone' => $this->phone,
            'address' => $this->address,
            'notes' => $this->notes,
            // US-0305: money string, or null = no limit.
            'credit_limit' => $this->credit_limit === null ? null : Money::of($this->credit_limit),
            'status' => $this->status ?? 'active',
            'debts_count' => $this->debts_count,
            // Open balance (Σ remaining of the customer's debts), when the query summed it.
            'balance' => $this->when(
                array_key_exists('balance', $this->resource->getAttributes()),
                fn() => Money::of($this->balance),
            ),
            // Σ remaining past its due date (store timezone), when the query summed it.
            'overdue' => $this->when(
                array_key_exists('overdue', $this->resource->getAttributes()),
                fn() => Money::of($this->overdue),
            ),
        ];
    }
}
