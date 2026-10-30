<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\PaymentMethods;
use App\Http\Requests\StorePurchaseRequest;
use App\Models\Product;
use App\Models\PurchaseInvoice;
use App\Models\Supplier;
use App\Models\SupplierPayment;
use App\Services\PurchaseService;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

/** Goods from suppliers, Owner / Manager only: costs and what the store owes stay off staff phones. */
class SupplierController extends Controller
{
    public function __construct(private readonly PurchaseService $purchases) {}

    /** The picker in the goods flow and the suppliers list: name search, with what the store owes. */
    public function index(Request $request)
    {
        Gate::authorize('adjustStock', Product::class);
        $filters = $request->validate(['search' => ['nullable', 'string', 'max:150']]);

        $suppliers = Supplier::query()
            ->forStore($request->user()->store_id)
            ->withBalance()
            ->when($filters['search'] ?? null, fn($q, string $search) => $q->where('name', 'like', '%' . $search . '%'))
            ->orderBy('name')
            ->limit(100)
            ->get();

        return response()->json(['data' => $suppliers->map(fn(Supplier $s) => $this->row($s))]);
    }

    /** The account: balance, then invoices and payments together, newest first. */
    public function show(Request $request, Supplier $supplier)
    {
        Gate::authorize('adjustStock', Product::class);
        $supplier->loadSum('invoices as purchased', 'total')->loadSum('payments as paid', 'amount');

        $invoices = $supplier->invoices()->withCount('items')->latest('id')->limit(100)->get()
            ->map(fn(PurchaseInvoice $i) => [
                'type' => 'invoice',
                'id' => $i->id,
                'amount' => Money::of($i->total),
                'items' => $i->items_count,
                'at' => $i->created_at,
            ]);
        $payments = $supplier->payments()->latest('id')->limit(100)->get()
            ->map(fn(SupplierPayment $p) => [
                'type' => 'payment',
                'id' => $p->id,
                'amount' => Money::of($p->amount),
                'method' => $p->method,
                'at' => $p->created_at,
            ]);

        // On the same second the invoice comes first in the sort, so it reads before its payment.
        $entries = $invoices->concat($payments)
            ->sortBy([['at', 'desc'], ['type', 'desc'], ['id', 'desc']])
            ->values();

        return response()->json(['data' => $this->row($supplier) + ['entries' => $entries]]);
    }

    public function pay(Request $request, Supplier $supplier)
    {
        Gate::authorize('adjustStock', Product::class);
        $data = $request->validate([
            'amount' => ['required', ...Money::inputRules()],
            'method' => ['required', 'string', Rule::in(PaymentMethods::ALL)],
        ], [
            'amount.required' => 'اكتب المبلغ.',
            'amount.gt' => 'اكتب المبلغ.',
            'method.required' => 'اختر طريقة الدفع.',
        ]);

        $this->purchases->pay($request->user(), $supplier, (string) $data['amount'], $data['method']);

        return response()->json(['data' => ['balance' => $supplier->balance()]], 201);
    }

    /** POST /purchases: the three steps of «تسجيل بضاعة» in one transaction. */
    public function purchase(StorePurchaseRequest $request)
    {
        $invoice = $this->purchases->record($request->user(), $request->validated());
        $paid = Money::sum($invoice->payments->pluck('amount'));

        return response()->json(['data' => [
            'id' => $invoice->id,
            'supplier' => ['id' => $invoice->supplier->id, 'name' => $invoice->supplier->name],
            'total' => Money::of($invoice->total),
            'paid' => $paid,
            'remaining' => Money::sub($invoice->total, $paid),
            'lines' => $invoice->items->count(),
        ]], 201);
    }

    private function row(Supplier $supplier): array
    {
        return [
            'id' => $supplier->id,
            'name' => $supplier->name,
            'phone' => $supplier->phone,
            'balance' => Money::sub($supplier->purchased, $supplier->paid),
        ];
    }
}
