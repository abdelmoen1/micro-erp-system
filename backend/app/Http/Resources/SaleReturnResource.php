<?php

namespace App\Http\Resources;

use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** US-0601: one return, with how its value was split between the debt and a cash refund. */
class SaleReturnResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'invoice_id' => $this->invoice_id,
            'total_amount' => Money::of($this->total_amount),
            'debt_reduction' => Money::of($this->debt_reduction),
            'refund_amount' => Money::of($this->refund_amount),
            'reason' => $this->reason,
            'created_by' => $this->whenLoaded('creator', fn() => $this->creator?->name),
            'created_at' => $this->created_at,
            'items' => $this->whenLoaded('items', fn() => $this->items->map(fn($item) => [
                'invoice_item_id' => $item->invoice_item_id,
                'product_id' => $item->product_id,
                'item_name' => $item->invoiceItem?->item_name,
                'unit' => $item->invoiceItem?->unit ?? Quantity::UNIT_PIECE,
                'quantity' => Quantity::format($item->quantity, $item->invoiceItem?->unit),
                'unit_price' => Money::of($item->unit_price),
                'total' => Money::of($item->total),
            ])->values()),
        ];
    }
}
