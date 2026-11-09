<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\SubscriptionController;
use App\Models\SubscriptionOrder;
use App\Services\SubscriptionService;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Platform admin: subscription requests. Moving a request along never activates anything; only
 * confirm-payment does, after the admin verified the money arrived, with the exact amount/currency.
 */
class SubscriptionOrderController extends Controller
{
    public function index(Request $request)
    {
        $filters = $request->validate([
            'status' => ['nullable', 'string', 'max:30'],
            'channel' => ['nullable', 'string', 'max:20'],
            'search' => ['nullable', 'string', 'max:100'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);
        $orders = SubscriptionOrder::query()
            ->when($filters['status'] ?? null, fn($q, $s) => $s === 'open' ? $q->whereIn('status', SubscriptionOrder::OPEN) : $q->where('status', $s))
            ->when($filters['channel'] ?? null, fn($q, $c) => $q->where('channel', $c))
            ->when($filters['search'] ?? null, fn($q, $s) => $q->where(fn($q) => $q->where('reference', 'like', "%{$s}%")->orWhere('store_name', 'like', "%{$s}%")))
            ->latest('id')
            ->paginate($filters['per_page'] ?? 20);

        return response()->json([
            'data' => collect($orders->items())->map(fn($o) => SubscriptionController::order($o) + ['store' => ['id' => $o->store_id, 'name' => $o->store_name]])->values(),
            'meta' => ['current_page' => $orders->currentPage(), 'last_page' => $orders->lastPage(), 'total' => $orders->total()],
        ]);
    }

    public function show(SubscriptionOrder $order)
    {
        return response()->json(['data' => $this->detail($order)]);
    }

    public function transition(Request $request, SubscriptionOrder $order, SubscriptionService $subscriptions)
    {
        $data = $request->validate([
            'status' => ['required', Rule::in([SubscriptionOrder::PENDING_CONTACT, SubscriptionOrder::AWAITING_PAYMENT, SubscriptionOrder::PAYMENT_VERIFICATION, SubscriptionOrder::REJECTED, SubscriptionOrder::CANCELLED])],
            'note' => ['nullable', 'string', 'max:2000'],
        ]);
        $subscriptions->transition($order, $data['status'], $request->user(), $data['note'] ?? null);

        return response()->json(['data' => $this->detail($order->fresh())]);
    }

    public function note(Request $request, SubscriptionOrder $order, SubscriptionService $subscriptions)
    {
        $data = $request->validate(['note' => ['required', 'string', 'max:2000']]);
        $subscriptions->addNote($order, $request->user(), $data['note']);

        return response()->json(['data' => $this->detail($order->fresh())], 201);
    }

    public function confirmPayment(Request $request, SubscriptionOrder $order, SubscriptionService $subscriptions)
    {
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'decimal:0,2', 'min:0.01'],
            'currency' => ['required', 'string', 'size:3'],
            'payment_method' => ['required', 'string', 'max:40'],
            'transaction_reference' => ['required', 'string', 'max:120'],
            'paid_at' => ['nullable', 'date', 'before_or_equal:now'],
            'note' => ['nullable', 'string', 'max:2000'],
            // The admin states they checked the money arrived; the request alone proves nothing.
            'payment_verified' => ['required', 'accepted'],
        ]);
        $data['currency'] = strtoupper($data['currency']);
        $subscriptions->confirmManualPayment($order, $request->user(), $data);

        return response()->json(['data' => $this->detail($order->fresh())]);
    }

    private function detail(SubscriptionOrder $order): array
    {
        $order->load(['payments.recorder:id,name', 'events.actor:id,name', 'reviewer:id,name', 'requester:id,name', 'store:id,name,phone,subscription_expires_at']);

        return SubscriptionController::order($order) + [
            'store' => ['id' => $order->store_id, 'name' => $order->store_name, 'phone' => $order->store?->phone, 'deleted' => $order->store === null],
            'requested_by' => $order->requester?->only(['id', 'name']),
            'reviewed_by' => $order->reviewer?->only(['id', 'name']),
            'reviewed_at' => $order->reviewed_at?->toIso8601String(),
            'provider' => $order->provider,
            'allowed_transitions' => SubscriptionOrder::MANUAL_TRANSITIONS[$order->status] ?? [],
            'can_confirm_payment' => $order->isOpen() && $order->channel === SubscriptionOrder::CHANNEL_MANUAL,
            'whatsapp_url' => $order->store && $order->isOpen() ? SubscriptionController::whatsappUrl($order, $order->store) : null,
            'payments' => $order->payments->map(fn($p) => [
                'kind' => $p->kind, 'source' => $p->source, 'amount' => Money::of($p->amount), 'currency' => $p->currency,
                'method' => $p->method, 'transaction_reference' => $p->transaction_reference,
                'paid_at' => $p->paid_at?->toIso8601String(), 'recorded_by' => $p->recorder?->only(['id', 'name']),
                'created_at' => $p->created_at?->toIso8601String(),
            ])->values(),
            'events' => $order->events->map(fn($e) => [
                'type' => $e->type, 'from' => $e->from_status, 'to' => $e->to_status, 'note' => $e->note, 'data' => $e->data,
                'actor' => $e->actor?->only(['id', 'name']), 'created_at' => $e->created_at?->toIso8601String(),
            ])->values(),
        ];
    }
}
