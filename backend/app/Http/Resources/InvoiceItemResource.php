<?php

namespace App\Http\Resources;

use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A sale line with its snapshots: `quantity` is a string in the line's unit ("3", "0.750"),
 * `line_total` = quantity × unit_price rounded half-up (doc 15 §4). `total` is kept for older clients.
 */
class InvoiceItemResource extends JsonResource
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
            'product_id' => $this->product_id,
            'item_name' => $this->item_name,
            'unit' => $this->unit,
            'quantity' => Quantity::format($this->quantity, $this->unit),
            'returned_quantity' => Quantity::format($this->returned_quantity, $this->unit),
            'unit_price' => Money::of($this->unit_price),
            'line_total' => Money::of($this->total),
            'total' => Money::of($this->total),
        ];
    }
}
