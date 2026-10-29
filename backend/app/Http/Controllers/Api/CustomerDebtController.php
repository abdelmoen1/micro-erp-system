<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\PayAllDebtsRequest;
use App\Http\Resources\DebtResource;
use App\Models\Customer;
use App\Models\Debt;
use App\Models\Payment;
use App\Services\PaymentService;
use App\Support\Money;
use Illuminate\Http\Request;

class CustomerDebtController extends Controller
{
    public function __construct(private readonly PaymentService $payments) {}

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

        // D-12: a real repayment of what is owed, recorded as payments. Without an amount the
        // whole balance is settled; with one it goes to the oldest due debts first (US-0705).
        $result = $this->payments->payCustomer(
            $request->user(),
            $customer,
            isset($validated['amount']) ? Money::of($validated['amount']) : null,
            $validated['method'],
            $validated['paid_at'] ?? null,
            $validated['notes'] ?? null,
        );

        return self::paidResponse($result, isset($validated['amount']));
    }

    /** The 201 body of a customer payment; the offline sync (US-1101) answers with the same one. */
    public static function paidResponse(array $result, bool $withAmount)
    {
        return response()->json([
            'message' => $withAmount
                ? 'تم تسجيل الدفعة بنجاح.'
                : 'تم تسديد جميع ديون العميل بنجاح.',
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
