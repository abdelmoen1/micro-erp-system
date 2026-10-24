<?php

namespace App\Http\Resources;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** A sale (05 §3.1). `debt_amount` is what the sale left on credit: total − paid. */
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
            'status' => $this->status,
            'has_debt' => (bool) $this->has_debt,
            'payment_method' => $this->payment_method,
            'total_amount' => Money::of($this->total_amount),
            'paid_amount' => Money::of($this->paid_amount),
            'debt_amount' => Money::maxZero(Money::sub($this->total_amount, $this->paid_amount)),
            'notes' => $this->notes,
            'items' => InvoiceItemResource::collection($this->whenLoaded('items')),
            'customer' => new CustomerResource($this->whenLoaded('customer')),
            'debt' => new DebtResource($this->whenLoaded('debt')),
            'created_by' => $this->created_by,
            'seller' => $this->whenLoaded('creator', fn() => $this->creator ? ['id' => $this->creator->id, 'name' => $this->creator->name] : null),
            'voided_by_name' => $this->whenLoaded('voider', fn() => $this->voider?->name),
            'created_at' => $this->created_at,
            'voided_at' => $this->voided_at,
            'voided_by' => $this->voided_by,
            'void_reason' => $this->void_reason,
            // US-0602: returns against the sale and their total value.
            'returns' => SaleReturnResource::collection($this->whenLoaded('returns')),
            'returned_amount' => $this->whenLoaded('returns', fn() => Money::sum($this->returns->pluck('total_amount'))),
        ];
    }
}
