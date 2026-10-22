<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ReversePaymentGroupRequest;
use App\Http\Requests\ReversePaymentRequest;
use App\Http\Requests\StorePaymentRequest;
use App\Http\Resources\PaymentOperationResource;
use App\Http\Resources\PaymentResource;
use App\Models\Payment;
use App\Services\PaymentService;
use App\Support\BusinessClock;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PaymentController extends Controller
{
    public function __construct(private readonly PaymentService $payments) {}

    /**
     * W-14 payment history as operations: a pay-all group is one row, a single payment another.
     * US-0703 AC4: `customer_id` and `invoice_id` narrow the history to that context; `from` and
     * `to` are local dates in the store timezone.
     */
    public function index(Request $request)
    {
        $filters = $request->validate([
            'customer_id' => ['nullable', 'integer'],
            'invoice_id' => ['nullable', 'integer'],
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to' => ['nullable', 'date_format:Y-m-d'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $user = $request->user();
        $timezone = BusinessClock::forStore($user->store)->timezone();

        $scoped = function () use ($user, $filters, $timezone): Builder {
            return Payment::query()
                ->where('payments.store_id', $user->store_id)
                ->when($filters['customer_id'] ?? null, fn($q, $id) => $q->where('customer_id', $id))
                ->when($filters['invoice_id'] ?? null, fn($q, $id) => $q->whereHas('debt', fn($d) => $d->where('invoice_id', $id)))
                ->when($filters['from'] ?? null, fn($q, $day) => $q->where('paid_at', '>=', CarbonImmutable::parse($day, $timezone)->startOfDay()->utc()))
                ->when($filters['to'] ?? null, fn($q, $day) => $q->where('paid_at', '<=', CarbonImmutable::parse($day, $timezone)->endOfDay()->utc()));
        };

        $singleKey = DB::connection()->getDriverName() === 'sqlite' ? "'single_' || id" : "CONCAT('single_', id)";
        $operationKey = "COALESCE(payment_group_id, {$singleKey})";

        $page = $scoped()
            ->selectRaw("{$operationKey} AS operation_key, MAX(paid_at) AS operation_paid_at")
            ->groupByRaw($operationKey)
            ->orderByDesc('operation_paid_at')
            ->paginate($filters['per_page'] ?? 15);

        $keys = collect($page->items())->pluck('operation_key')->values();

        if ($keys->isEmpty()) {
            $page->setCollection(collect());

            return PaymentOperationResource::collection($page);
        }

        $groupIds = $keys->reject(fn($key) => str_starts_with($key, 'single_'))->values();
        $singleIds = $keys->filter(fn($key) => str_starts_with($key, 'single_'))
            ->map(fn($key) => (int) substr($key, 7))
            ->values();

        $payments = $scoped()
            ->with(['debt.invoice', 'customer', 'creator', 'reverser'])
            ->where(function ($query) use ($groupIds, $singleIds) {
                if ($groupIds->isNotEmpty()) {
                    $query->whereIn('payment_group_id', $groupIds);
                }
                if ($singleIds->isNotEmpty()) {
                    $query->orWhereIn('id', $singleIds);
                }
            })
            ->orderBy('id')
            ->get();

        $byKey = $payments
            ->groupBy(fn(Payment $payment) => $payment->payment_group_id ?? 'single_' . $payment->id)
            ->map(function ($group) {
                $first = $group->first();
                $reversed = $group->every(fn(Payment $payment) => $payment->is_reversed);

                return (object) [
                    'type' => $first->payment_group_id !== null ? 'pay_all' : 'single',
                    'id' => $first->id,
                    'payment_group_id' => $first->payment_group_id,
                    'customer' => $first->customer,
                    'total_amount' => Money::sum($group->pluck('amount')),
                    'method' => $first->method,
                    'paid_at' => $first->paid_at,
                    'created_by' => $first->creator?->name,
                    'is_reversed' => $reversed,
                    'reversed_at' => $reversed ? $group->max('reversed_at') : null,
                    'reversed_by' => $reversed ? $first->reverser?->name : null,
                    'reversal_reason' => $reversed ? $first->reversal_reason : null,
                    'payments' => $group->values(),
                ];
            });

        $page->setCollection($keys->map(fn($key) => $byKey->get($key))->filter()->values());

        return PaymentOperationResource::collection($page);
    }

    /** Record a real payment against one debt. Any role (D-12). */
    public function store(StorePaymentRequest $request)
    {
        $validated = $request->validated();

        $payment = $this->payments->payDebt(
            $request->user(),
            (int) $validated['debt_id'],
            Money::of($validated['amount']),
            $validated['method'],
            $validated['paid_at'] ?? null,
            $validated['notes'] ?? null,
        );

        return new PaymentResource($payment->load('debt'));
    }

    /** Reverse one payment (owner/manager). A payment of a group needs the group reversal. */
    public function is_reverse(ReversePaymentRequest $request, Payment $payment)
    {
        abort_unless((int) $payment->store_id === (int) $request->user()->store_id, 404);

        $this->payments->reverse($request->user(), $payment, $request->validated('reason'));

        return response()->json([
            'message' => 'تم إلغاء الدفعة وإعادة المبلغ إلى الدين بنجاح.',
        ]);
    }

    /** Reverse every payment of a pay-all operation (owner/manager). */
    public function reverseGroup(ReversePaymentGroupRequest $request, string $paymentGroupId)
    {
        $result = $this->payments->reverseGroup($request->user(), $paymentGroupId, $request->validated('reason'));

        return response()->json([
            'message' => 'تم إلغاء عملية السداد بالكامل بنجاح.',
            'data' => $result,
        ]);
    }
}
