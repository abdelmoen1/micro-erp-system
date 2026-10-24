<?php

namespace App\Http\Resources;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** W-14 row: one pay-all group or one single payment, with what it paid (debt → sale or opening). */
class PaymentOperationResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'type' => $this->type,
            'id' => $this->id,
            'payment_group_id' => $this->payment_group_id,
            'total_amount' => Money::of($this->total_amount),
            'method' => $this->method,
            'paid_at' => $this->paid_at,
            'created_by' => $this->created_by,
            'is_reversed' => $this->is_reversed,
            'reversed_at' => $this->reversed_at,
            'reversed_by' => $this->reversed_by,
            'reversal_reason' => $this->reversal_reason,
            'payments' => PaymentResource::collection($this->payments),
            'applied_to' => $this->payments->map(fn($payment) => [
                'debt_id' => $payment->debt_id,
                'invoice_id' => $payment->debt?->invoice_id,
                'source' => $payment->debt?->invoice?->source?->value,
                'amount' => Money::of($payment->amount),
            ])->values(),
            'customer' => $this->customer ? [
                'id' => $this->customer->id,
                'name' => $this->customer->name,
                'phone' => $this->customer->phone,
            ] : null,
        ];
    }
}
