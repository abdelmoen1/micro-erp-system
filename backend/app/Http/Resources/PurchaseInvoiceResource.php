<?php

namespace App\Http\Resources;

use App\Models\PurchaseItem;
use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** A purchase invoice. The lines and returns come only with GET /purchases/{id}. */
class PurchaseInvoiceResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'supplier' => ['id' => $this->supplier->id, 'name' => $this->supplier->name],
            'total' => Money::of($this->total),
            'returned_amount' => Money::of($this->returned_amount ?? $this->returns()->sum('total_amount')),
            'lines_count' => $this->items_count ?? $this->items()->count(),
            'by' => $this->creator?->name,
            'at' => $this->created_at,
            'items' => $this->whenLoaded('items', fn() => $this->items->map(fn(PurchaseItem $item) => [
                'id' => $item->id,
                'product_id' => $item->product_id,
                'item_name' => $item->product?->name,
                'unit' => $item->product?->unit ?? Quantity::UNIT_PIECE,
                'quantity' => Quantity::format($item->quantity, $item->product?->unit),
                'returned_quantity' => Quantity::format($item->returned_quantity, $item->product?->unit),
                'cartons' => $item->cartons,
                'pack_size' => $item->pack_size,
                'buy_price' => Money::of($item->buy_price),
                'line_total' => Money::of($item->line_total),
            ])->values()),
            'returns' => PurchaseReturnResource::collection($this->whenLoaded('returns')),
        ];
    }
}
