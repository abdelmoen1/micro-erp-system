<?php

namespace App\Http\Resources;

use App\Models\PurchaseItem;
use App\Models\PurchaseReturnItem;
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
        $remainingAmount = '0.00';
        $items = $this->whenLoaded('items', function () use (&$remainingAmount) {
            return $this->items->map(function (PurchaseItem $item) use (&$remainingAmount) {
            $returnedValue = Money::sum(
                PurchaseReturnItem::query()
                    ->where('purchase_item_id', $item->id)
                    ->pluck('total'),
            );
            $remainingValue = Money::sub($item->line_total, $returnedValue);
            $remainingQuantity = Quantity::sub($item->quantity, $item->returned_quantity);
            $remainingAmount = Money::add($remainingAmount, $remainingValue);
            $remainingCartons = null;
            $remainingLoosePieces = 0;
            if ($item->cartons !== null && (int) $item->pack_size > 0 && Quantity::isWhole($remainingQuantity)) {
                $remainingPieces = (int) substr(Quantity::of($remainingQuantity), 0, -4);
                $remainingCartons = intdiv($remainingPieces, (int) $item->pack_size);
                $remainingLoosePieces = $remainingPieces % (int) $item->pack_size;
            }

            return [
                'id' => $item->id,
                'product_id' => $item->product_id,
                'item_name' => $item->product?->name,
                'unit' => $item->product?->unit ?? Quantity::UNIT_PIECE,
                'quantity' => Quantity::format($item->quantity, $item->product?->unit),
                'returned_quantity' => Quantity::format($item->returned_quantity, $item->product?->unit),
                'remaining_quantity' => Quantity::format($remainingQuantity, $item->product?->unit),
                'returned_value' => Money::of($returnedValue),
                'remaining_line_value' => Money::of($remainingValue),
                'cartons' => $item->cartons,
                'remaining_cartons' => $remainingCartons,
                'pack_size' => $item->pack_size,
                'loose_pieces' => (int) $item->loose_pieces,
                'remaining_loose_pieces' => $remainingLoosePieces,
                'buy_price' => Money::of($item->buy_price),
                'line_total' => Money::of($item->line_total),
            ];
            })->values();
        });

        return [
            'id' => $this->id,
            'supplier' => ['id' => $this->supplier->id, 'name' => $this->supplier->name],
            'total' => Money::of($this->total),
            'returned_amount' => Money::of($this->returned_amount ?? $this->returns()->sum('total_amount')),
            'lines_count' => $this->items_count ?? $this->items()->count(),
            'by' => $this->creator?->name,
            'at' => $this->created_at,
            'remaining_amount' => $this->relationLoaded('items') ? Money::of($remainingAmount) : null,
            'items' => $items,
            'returns' => PurchaseReturnResource::collection($this->whenLoaded('returns')),
        ];
    }
}
