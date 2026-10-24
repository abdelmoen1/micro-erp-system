<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Customer;
use App\Http\Requests\StoreCustomerRequest;
use App\Http\Requests\UpdateCustomerRequest;
use App\Http\Resources\CustomerResource;
use App\Services\AuditService;
use App\Services\StatementService;
use App\Support\BusinessClock;
use Illuminate\Validation\Rule;

class CustomerController extends Controller
{
    public function __construct(
        private readonly StatementService $statements,
        private readonly AuditService $audit,
    ) {}

    /**
     * W-06 / M-07 list and the M-05 picker: search by name or phone; each row carries its open
     * balance and overdue amount. `status` defaults to active, so the POS picker never offers an
     * inactive customer (US-0301 AC4); the back office asks for `all`.
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'status' => ['nullable', Rule::in([Customer::STATUS_ACTIVE, Customer::STATUS_INACTIVE, 'all'])],
            'filter' => ['nullable', Rule::in(['with_balance', 'overdue'])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);
        $status = $filters['status'] ?? Customer::STATUS_ACTIVE;
        $today = BusinessClock::forStore($user->store)->now()->toDateString();
        $overdue = fn($q) => $q->where('status', '<>', 'cancelled')->where('remaining_amount', '>', 0)->whereDate('due_date', '<', $today);

        $customers = Customer::query()
            ->where('store_id', $user->store_id)
            ->when($status !== 'all', fn($q) => $q->where('status', $status))
            ->withCount('debts')
            ->withSum('ledgerDebts as balance', 'remaining_amount')
            ->withSum(['ledgerDebts as overdue' => $overdue], 'remaining_amount')
            ->when($filters['search'] ?? null, function ($query, string $search) {
                $query->where(fn($q) => $q->where('name', 'like', '%' . $search . '%')
                    ->orWhere('phone', 'like', '%' . preg_replace('/\s+/', '', $search) . '%'));
            })
            ->when(($filters['filter'] ?? null) === 'with_balance', fn($q) => $q->whereHas('ledgerDebts', fn($d) => $d->where('remaining_amount', '>', 0)))
            ->when(($filters['filter'] ?? null) === 'overdue', fn($q) => $q->whereHas('ledgerDebts', $overdue))
            ->latest()
            ->orderByDesc('id')
            ->paginate($filters['per_page'] ?? 10);

        return CustomerResource::collection($customers);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(StoreCustomerRequest $request)
    {
        $customer = Customer::create([
            ...$request->validated(),
            'store_id' => $request->user()->store_id,
        ]);

        return response()->json([
            'message' => 'تم انشاء العميل بنجاح',
            'customer' => new CustomerResource($customer),
        ], 201);
    }

    /**
     * Display the specified resource.
     */
    public function show(Request $request, Customer $customer)
    {
        abort_unless(
            $customer->store_id === $request->user()->store_id,
            404
        );

        return new CustomerResource($customer);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(
        UpdateCustomerRequest $request,
        Customer $customer
    ) {
        abort_unless(
            $customer->store_id === $request->user()->store_id,
            404
        );

        $customer->update($request->validated());

        return new CustomerResource($customer);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(Request $request, Customer $customer)
    {
        // Employees cannot delete customers; store isolation is enforced by route binding.
        $this->authorize('delete', $customer);

        // Customer with any financial history cannot be deleted
        if ($customer->invoices()->exists()) {
            return response()->json([
                'message' => 'لا يمكن حذف العميل لأنه يمتلك سجلًا ماليًا.',
            ], 422);
        }

        $customer->delete();

        return response()->json([
            'message' => 'تم حذف العميل بنجاح.',
        ]);
    }

    /** GET /customers/{id}/summary (US-0302 AC2): totals that equal the statement. */
    public function summary(Customer $customer)
    {
        return response()->json(['data' => $this->statements->summary($customer)]);
    }

    /** GET /customers/{id}/statement?from&to (US-0302 AC1): every event with a running balance. */
    public function statement(Request $request, Customer $customer)
    {
        $filters = $request->validate([
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:from'],
        ]);

        return response()->json(['data' => $this->statements->statement($customer, $filters['from'] ?? null, $filters['to'] ?? null)]);
    }

    /** POST /customers/{id}/deactivate (US-0301 AC4): Owner / Manager, audited. */
    public function deactivate(Request $request, Customer $customer)
    {
        return $this->setStatus($request, $customer, Customer::STATUS_INACTIVE, 'customer.deactivated', 'تم إيقاف العميل. يبقى سجله ودينه كما هو.');
    }

    /** POST /customers/{id}/reactivate (US-0301 AC4): Owner / Manager, audited. */
    public function reactivate(Request $request, Customer $customer)
    {
        return $this->setStatus($request, $customer, Customer::STATUS_ACTIVE, 'customer.reactivated', 'تمت إعادة تفعيل العميل.');
    }

    private function setStatus(Request $request, Customer $customer, string $status, string $action, string $message)
    {
        $this->authorize('changeStatus', $customer);

        if (($customer->status ?? Customer::STATUS_ACTIVE) !== $status) {
            $customer->forceFill(['status' => $status])->save();
            $this->audit->record($action, $customer, ['status' => $status], $request->user());
        }

        return response()->json([
            'message' => $message,
            'data' => new CustomerResource($customer->fresh()),
        ]);
    }
}
