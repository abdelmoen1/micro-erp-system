<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\ReversePaymentGroupRequest;
use App\Http\Requests\ReversePaymentRequest;
use App\Http\Requests\StorePaymentRequest;
use App\Http\Resources\PaymentOperationResource;
use App\Http\Resources\PaymentResource;
use App\Models\Debt;
use App\Models\Payment;
use App\Services\AuditService;
use App\Services\DebtLedger;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PaymentController extends Controller
{
    public function __construct(
        private readonly DebtLedger $ledger,
        private readonly AuditService $audit,
    ) {}

    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        $storeId = $request->user()->store_id;

        $perPage = min(
            max((int) $request->input('per_page', 15), 1),
            50
        );

        /*
     * An operation is:
     *
     * 1. payment_group_id when the payments belong to pay_all
     * 2. single_{id} when it is a single payment
     *
     * We paginate operations first, then load all payments
     * belonging to those operations.
     */
        $singlePaymentKeyExpression = DB::connection()->getDriverName() === 'sqlite'
            ? "'single_' || id"
            : "CONCAT('single_', id)";

        $operationKeyExpression = "
        COALESCE(
            payment_group_id,
            {$singlePaymentKeyExpression}
        )
    ";

        $operationPaginator = Payment::forStore($storeId)
            ->selectRaw("
            {$operationKeyExpression} AS operation_key,
            MAX(paid_at) AS operation_paid_at
        ")
            ->groupByRaw($operationKeyExpression)
            ->orderByDesc('operation_paid_at')
            ->paginate($perPage);

        $operationKeys = collect($operationPaginator->items())
            ->pluck('operation_key')
            ->values();

        if ($operationKeys->isEmpty()) {
            $operationPaginator->setCollection(collect());

            return PaymentOperationResource::collection(
                $operationPaginator
            );
        }

        /*
     * Separate grouped payments from single payments.
     */
        $groupIds = $operationKeys
            ->filter(fn($key) => !str_starts_with($key, 'single_'))
            ->values();

        $singlePaymentIds = $operationKeys
            ->filter(fn($key) => str_starts_with($key, 'single_'))
            ->map(fn($key) => (int) str_replace('single_', '', $key))
            ->values();

        /*
     * Load only payments belonging to the current page's operations.
     */
        $payments = Payment::forStore($storeId)
            ->with([
                'debt.invoice.customer',
            ])
            ->where(function ($query) use (
                $groupIds,
                $singlePaymentIds
            ) {
                if ($groupIds->isNotEmpty()) {
                    $query->whereIn('payment_group_id', $groupIds);
                }

                if ($singlePaymentIds->isNotEmpty()) {
                    $method = $groupIds->isNotEmpty()
                        ? 'orWhereIn'
                        : 'whereIn';

                    $query->{$method}('id', $singlePaymentIds);
                }
            })
            ->latest('paid_at')
            ->get();

        /*
     * Build operations exactly as before.
     */
        $operationsByKey = $payments
            ->groupBy(function ($payment) {
                return $payment->payment_group_id
                    ?? 'single_' . $payment->id;
            })
            ->map(function ($group) {

                $firstPayment = $group->first();

                $isPayAll = $firstPayment->payment_group_id !== null;

                $operation = new \stdClass();

                $operation->type = $isPayAll
                    ? 'pay_all'
                    : 'single';

                $operation->payment_group_id =
                    $firstPayment->payment_group_id;

                $operation->customer =
                    $firstPayment->debt?->invoice?->customer;

                $operation->total_amount =
                    Money::sum($group->pluck('amount'));

                $operation->method =
                    $firstPayment->method;

                $operation->paid_at =
                    $firstPayment->paid_at;

                $operation->is_reversed =
                    $group->every(
                        fn($payment) => $payment->is_reversed
                    );

                $operation->reversed_at =
                    $operation->is_reversed
                    ? $group->max('reversed_at')
                    : null;

                $operation->reversal_reason =
                    $operation->is_reversed
                    ? $group->first()->reversal_reason
                    : null;

                $operation->payments =
                    $group->values();

                return $operation;
            });

        /*
     * Preserve the exact order of the paginated operations.
     */
        $operations = $operationKeys
            ->map(fn($key) => $operationsByKey->get($key))
            ->filter()
            ->values();

        $operationPaginator->setCollection($operations);

        return PaymentOperationResource::collection(
            $operationPaginator
        );
    }

    /**
     * Record a real payment against one debt. Any role (D-12).
     */
    public function store(StorePaymentRequest $request)
    {
        $validated = $request->validated();
        $storeId = $request->user()->store_id;
        $amount = Money::of($validated['amount']);

        $payment = DB::transaction(function () use ($validated, $request, $storeId, $amount) {
            $debt = Debt::query()
                ->whereKey($validated['debt_id'])
                ->where('store_id', $storeId)
                ->lockForUpdate()
                ->firstOrFail();

            if (Money::isZero($debt->remaining_amount)) {
                throw ApiException::businessRule('DEBT_ALREADY_PAID', 'هذا الدين مسدد بالكامل.', [
                    'debt_id' => ['هذا الدين مسدد بالكامل.'],
                ]);
            }

            if (Money::compare($amount, $debt->remaining_amount) > 0) {
                $message = 'مبلغ الدفعة أكبر من المبلغ المتبقي: ' . Money::of($debt->remaining_amount);

                throw ApiException::businessRule('PAYMENT_EXCEEDS_REMAINING', $message, [
                    'amount' => [$message],
                ]);
            }

            $payment = $debt->payments()->create([
                'amount' => $amount,
                'method' => $validated['method'],
                'paid_at' => $validated['paid_at'] ?? now(),
                'notes' => $validated['notes'] ?? null,
                'created_by' => $request->user()->id,
            ]);

            $this->ledger->recalculate($debt);

            return $payment;
        });

        return new PaymentResource($payment->load('debt'));
    }

    /**
     * Reverse one payment (owner/manager). The debt balance is re-derived
     * from the remaining non-reversed payments.
     */
    public function is_reverse(ReversePaymentRequest $request, Payment $payment)
    {
        $this->ensurePaymentBelongsToStore($request, $payment);

        DB::transaction(function () use ($request, $payment) {
            $lockedPayment = Payment::query()
                ->whereKey($payment->id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($lockedPayment->is_reversed) {
                throw ApiException::businessRule('PAYMENT_ALREADY_REVERSED', 'هذه الدفعة ملغاة بالفعل.', [
                    'payment' => ['هذه الدفعة ملغاة بالفعل.'],
                ]);
            }

            $debt = Debt::query()
                ->whereKey($lockedPayment->debt_id)
                ->lockForUpdate()
                ->firstOrFail();

            $lockedPayment->update([
                'is_reversed' => true,
                'reversed_at' => now(),
                'reversal_reason' => $request->validated('reason'),
            ]);

            $this->ledger->recalculate($debt);

            $this->audit->record('payment.reversed', $lockedPayment, [
                'amount' => Money::of($lockedPayment->amount),
                'debt_id' => $debt->id,
                'reason' => $request->validated('reason'),
            ]);
        });

        return response()->json([
            'message' => 'تم إلغاء الدفعة وإعادة المبلغ إلى الدين بنجاح.',
        ]);
    }

    /**
     * Reverse every payment of a pay-all operation (owner/manager).
     */
    public function reverseGroup(ReversePaymentGroupRequest $request, string $paymentGroupId)
    {
        $storeId = $request->user()->store_id;

        $result = DB::transaction(function () use ($request, $paymentGroupId, $storeId) {
            $groupPayments = Payment::where('payment_group_id', $paymentGroupId)
                ->forStore($storeId)
                ->lockForUpdate()
                ->get();

            // Unknown or another store's group: never reveal existence.
            abort_if($groupPayments->isEmpty(), 404);

            $payments = $groupPayments->where('is_reversed', false);

            if ($payments->isEmpty()) {
                throw ApiException::businessRule('PAYMENT_ALREADY_REVERSED', 'تم إلغاء عملية السداد هذه بالفعل.', [
                    'payment_group_id' => ['تم إلغاء عملية السداد هذه بالفعل.'],
                ]);
            }

            $debts = Debt::query()
                ->whereIn('id', $payments->pluck('debt_id'))
                ->where('store_id', $storeId)
                ->lockForUpdate()
                ->get()
                ->keyBy('id');

            foreach ($payments as $payment) {
                $payment->update([
                    'is_reversed' => true,
                    'reversed_at' => now(),
                    'reversal_reason' => $request->validated('reason'),
                ]);
            }

            foreach ($debts as $debt) {
                $this->ledger->recalculate($debt);
            }

            $total = Money::sum($payments->pluck('amount'));

            $this->audit->record('payment_group.reversed', 'PaymentGroup', [
                'entity_id' => $paymentGroupId,
                'payments_count' => $payments->count(),
                'total_reversed' => $total,
                'reason' => $request->validated('reason'),
            ]);

            return [
                'payment_group_id' => $paymentGroupId,
                'debts_count' => $debts->count(),
                'total_reversed' => $total,
            ];
        });

        return response()->json([
            'message' => 'تم إلغاء عملية السداد بالكامل بنجاح.',
            'data' => $result,
        ]);
    }

    private function ensurePaymentBelongsToStore(Request $request, Payment $payment): void
    {
        $payment->loadMissing('debt');

        abort_unless(
            $payment->debt?->store_id === $request->user()->store_id,
            404
        );
    }
}
