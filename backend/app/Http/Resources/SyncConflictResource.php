<?php

namespace App\Http\Resources;

use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** A review item of the offline sync (SCR-W-18): what arrived, why it is listed, how it ended. */
class SyncConflictResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $payload = $this->payload['payload'] ?? [];

        return [
            'id' => $this->id,
            'client_transaction_id' => $this->client_transaction_id,
            'type' => $this->type,
            'kind' => $this->kind,
            'reason' => $this->reason,
            'message' => $this->message,
            'flags' => $this->flags ?? [],
            'amount' => $this->amount === null ? null : Money::of($this->amount),
            'payment_method' => $payload['payment_method'] ?? $payload['method'] ?? null,
            'items_count' => is_array($payload['items'] ?? null) ? count($payload['items']) : null,
            'device_id' => $this->device_id,
            'occurred_at' => $this->occurred_at,
            'created_at' => $this->created_at,
            'invoice_id' => $this->invoice_id,
            'status' => $this->status,
            'resolution' => $this->resolution,
            'resolution_note' => $this->resolution_note,
            'resolved_at' => $this->resolved_at,
            'user' => $this->whenLoaded('user', fn() => $this->user ? ['id' => $this->user->id, 'name' => $this->user->name] : null),
            'customer' => $this->whenLoaded('customer', fn() => $this->customer ? ['id' => $this->customer->id, 'name' => $this->customer->name, 'phone' => $this->customer->phone] : null),
            'resolver' => $this->whenLoaded('resolver', fn() => $this->resolver ? ['id' => $this->resolver->id, 'name' => $this->resolver->name] : null),
        ];
    }
}
