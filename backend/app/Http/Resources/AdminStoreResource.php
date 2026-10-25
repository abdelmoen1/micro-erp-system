<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A store as the platform admin sees it. `status` (account access) and `subscription` are separate
 * objects because they are separate states. Counts appear when the query loaded them.
 */
class AdminStoreResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $owner = $this->whenLoaded('owner');

        return [
            'id' => $this->id,
            'name' => $this->name,
            'phone' => $this->phone,
            'address' => $this->address,
            'area' => $this->area,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'timezone' => $this->businessTimezone(),
            'created_at' => $this->created_at,
            'days_since_registration' => (int) floor($this->created_at->diffInDays(now(), true)),
            'owner' => $this->when($this->relationLoaded('owner'), fn() => $owner ? [
                'id' => $owner->id,
                'name' => $owner->name,
                'email' => $owner->email,
                'phone' => $owner->phone,
                'status' => $owner->status ?? 'active',
            ] : null),
            'status' => $this->status,
            'suspension_reason' => $this->suspension_reason,
            'status_changed_at' => $this->status_changed_at,
            'status_changed_by' => $this->whenLoaded('statusChangedBy', fn($user) => $user?->only(['id', 'name'])),
            'subscription' => [
                'status' => $this->subscription_status,
                'state' => $this->subscriptionState(),
                'has_access' => $this->hasAccess(),
                'trial_ends_at' => $this->trial_ends_at,
                'started_at' => $this->subscription_started_at,
                'expires_at' => $this->subscription_expires_at,
                'changed_at' => $this->subscription_changed_at,
                'changed_by' => $this->whenLoaded('subscriptionChangedBy', fn($user) => $user?->only(['id', 'name'])),
            ],
            'users_count' => $this->whenCounted('users'),
            'products_count' => $this->whenCounted('products'),
        ];
    }
}
