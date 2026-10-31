<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\PaymentMethods;
use App\Http\Requests\StorePurchaseRequest;
use App\Models\Product;
use App\Models\PurchaseItem;
use App\Models\Supplier;
use App\Models\SupplierPayment;
use App\Services\PurchaseService;
use App\Support\Money;
use App\Support\Quantity;
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

    /** The supplier: what is owed in all, the products bought from them, and the payments made. */
    public function show(Request $request, Supplier $supplier)
    {
        Gate::authorize('adjustStock', Product::class);
        $supplier->loadSum('invoices as purchased', 'total')->loadSum('payments as paid', 'amount');

        $products = PurchaseItem::query()
            ->whereIn('purchase_invoice_id', $supplier->invoices()->select('id'))
            ->with('product')
            ->get()
            ->groupBy('product_id')
            ->map(fn($rows, $productId) => [
                'id' => (int) $productId,
                'name' => $rows->first()->product->name,
                'unit' => $rows->first()->product->unit,
                'total' => Money::sum($rows->pluck('line_total')),
            ])
            ->sortBy('name')
            ->values();

        $payments = $supplier->payments()->with('creator')->latest('id')->limit(200)->get()
            ->map(fn(SupplierPayment $payment) => [
                'id' => $payment->id,
                'at' => $payment->created_at,
                'by' => $payment->creator?->name,
                'amount' => Money::of($payment->amount),
                'method' => $payment->method,
            ]);

        return response()->json(['data' => $this->row($supplier) + ['products' => $products, 'payments' => $payments]]);
    }

    /** One product at this supplier: its invoices. */
    public function product(Request $request, Supplier $supplier, Product $product)
    {
        Gate::authorize('adjustStock', Product::class);

        $invoices = $supplier->productLines($product->id)->with('invoice.creator')->latest('id')->limit(200)->get()
            ->map(fn(PurchaseItem $item) => [
                'id' => $item->id,
                'invoice_id' => $item->purchase_invoice_id,
                'at' => $item->created_at,
                'by' => $item->invoice->creator?->name,
                'quantity' => Quantity::format($item->quantity, $product->unit),
                'cartons' => $item->cartons,
                'pack_size' => $item->pack_size,
                'buy_price' => Money::of($item->buy_price),
                'total' => Money::of($item->line_total),
            ]);

        return response()->json(['data' => [
            'supplier' => ['id' => $supplier->id, 'name' => $supplier->name],
            'product' => ['id' => $product->id, 'name' => $product->name, 'unit' => $product->unit],
            'invoices' => $invoices,
        ]]);
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

    /** POST /purchases: «تسجيل بضاعة» in one transaction. */
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
            'at' => $invoice->created_at,
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
