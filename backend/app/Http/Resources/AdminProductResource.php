<?php

namespace App\Http\Resources;

use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * One store's product row for the platform admin: that store's own name, price, cost and stock,
 * with the store it belongs to. Rows are never summed or merged across stores; the shared catalog
 * identity is only a link.
 */
class AdminProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'barcode' => $this->barcode,
            'unit' => $this->unit,
            'selling_price' => Money::of($this->selling_price),
            'cost_price' => $this->cost_price === null ? null : Money::of($this->cost_price),
            'pack_size' => $this->pack_size,
            'pack_price' => $this->pack_price === null ? null : Money::of($this->pack_price),
            'current_stock' => Quantity::format($this->current_stock, $this->unit),
            'minimum_stock' => Quantity::format($this->minimum_stock, $this->unit),
            'is_low_stock' => Quantity::compare($this->current_stock, $this->minimum_stock) <= 0,
            'status' => $this->status,
            'updated_at' => $this->updated_at,
            'catalog_product' => $this->whenLoaded('catalogProduct', fn($catalog) => $catalog ? new CatalogProductResource($catalog) : null),
            'store' => $this->whenLoaded('store', fn($store) => [
                'id' => $store->id,
                'name' => $store->name,
                'address' => $store->address,
                'area' => $store->area,
                'phone' => $store->phone,
                'status' => $store->status,
            ]),
        ];
    }
}
