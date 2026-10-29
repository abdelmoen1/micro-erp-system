<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** A complaint; the admin list also carries the store and the sender. */
class SupportTicketResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            'subject' => $this->subject,
            'details' => $this->details,
            'status' => $this->status,
            'reply' => $this->reply,
            'replied_at' => $this->replied_at,
            'created_at' => $this->created_at,
            'user' => $this->whenLoaded('user', fn() => $this->user ? ['id' => $this->user->id, 'name' => $this->user->name, 'phone' => $this->user->phone] : null),
            'store' => $this->whenLoaded('store', fn() => ['id' => $this->store->id, 'name' => $this->store->name, 'phone' => $this->store->phone]),
        ];
    }
}
