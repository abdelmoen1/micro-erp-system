<?php

namespace App\Http\Resources;

use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** One return to a supplier, with how its value was split between the balance and a refund. */
class PurchaseReturnResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'purchase_invoice_id' => $this->purchase_invoice_id,
            'supplier' => $this->whenLoaded('supplier', fn() => ['id' => $this->supplier->id, 'name' => $this->supplier->name]),
            'total_amount' => Money::of($this->total_amount),
            'balance_reduction' => Money::of($this->balance_reduction),
            'refund_amount' => Money::of($this->refund_amount),
            'reason' => $this->reason,
            'created_by' => $this->whenLoaded('creator', fn() => $this->creator?->name),
            'created_at' => $this->created_at,
            'items' => $this->whenLoaded('items', fn() => $this->items->map(fn($item) => [
                'purchase_item_id' => $item->purchase_item_id,
                'product_id' => $item->product_id,
                'item_name' => $item->purchaseItem?->product?->name,
                'unit' => $item->purchaseItem?->product?->unit ?? Quantity::UNIT_PIECE,
                'quantity' => Quantity::format($item->quantity, $item->purchaseItem?->product?->unit),
                'total' => Money::of($item->total),
                'from_stock' => (bool) $item->from_stock,
            ])->values()),
        ];
    }
}
