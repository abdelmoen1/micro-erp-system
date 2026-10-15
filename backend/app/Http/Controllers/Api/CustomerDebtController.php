<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\PayAllDebtsRequest;
use App\Http\Resources\DebtResource;
use App\Models\Customer;
use App\Models\Debt;
use App\Models\Payment;
use App\Services\DebtLedger;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CustomerDebtController extends Controller
{
    public function __construct(private readonly DebtLedger $ledger) {}

    /**
     * Display a listing of the resource.
     */
    public function index(Request $request, Customer $customer)
    {
        $this->ensureBelongsToStore($request, $customer);

        $query = Debt::forStore($request->user()->store_id)
            ->whereHas('invoice', function ($query) use ($customer) {
                $query->where('customer_id', $customer->id);
            });

        $summary = [
            'debts_count' => (clone $query)->count(),
            'total_debt' => Money::sum((clone $query)->pluck('amount')),
            'total_payments' => Money::sum(Payment::query()
                ->where('is_reversed', false)
                ->whereHas('debt', function ($debtQuery) use ($request, $customer) {
                    $debtQuery
                        ->where('store_id', $request->user()->store_id)
                        ->whereHas('invoice', fn($invoiceQuery) => $invoiceQuery
                            ->where('customer_id', $customer->id));
                })
                ->pluck('amount')),
            'total_remaining' => Money::sum((clone $query)->pluck('remaining_amount')),
        ];

        $debts = (clone $query)
            ->with('invoice')
            ->latest()
            ->paginate(10);

        return response()->json([
            'data' => DebtResource::collection($debts),
            'summary' => $summary,
        ]);
    }

    public function payAll(PayAllDebtsRequest $request, Customer $customer)
    {
        $this->ensureBelongsToStore($request, $customer);

        $validated = $request->validated();
        $storeId = $request->user()->store_id;

        $result = DB::transaction(function () use ($validated, $customer, $request, $storeId) {

            $debts = $customer->debts()
                ->forStore($storeId)
                ->where('remaining_amount', '>', 0)
                ->lockForUpdate()
                ->get();

            if ($debts->isEmpty()) {
                throw ApiException::businessRule('NOTHING_TO_PAY', 'لا يوجد على هذا العميل أي مبلغ متبقي.', [
                    'customer' => ['لا يوجد على هذا العميل أي مبلغ متبقي.'],
                ]);
            }

            $paymentGroupId = (string) Str::uuid();

            $totalPaid = '0.00';

            // D-12: a real repayment of what is owed, recorded as payments.
            // Write-offs are a different operation and never go through here.
            foreach ($debts as $debt) {
                $amount = Money::of($debt->remaining_amount);

                $debt->payments()->create([
                    'amount' => $amount,
                    'method' => $validated['method'],
                    'paid_at' => $validated['paid_at'] ?? now(),
                    'notes' => $validated['notes'] ?? null,
                    'created_by' => $request->user()->id,
                    'payment_group_id' => $paymentGroupId,
                ]);

                $this->ledger->recalculate($debt);

                $totalPaid = Money::add($totalPaid, $amount);
            }

            return [
                'payment_group_id' => $paymentGroupId,
                'debts_count' => $debts->count(),
                'total_paid' => $totalPaid,
            ];
        });

        return response()->json([
            'message' => 'تم تسديد جميع ديون العميل بنجاح.',
            'data' => $result,
        ], 201);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        //
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        //
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        //
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        //
    }
}
