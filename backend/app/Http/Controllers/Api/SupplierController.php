<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\PaymentMethods;
use App\Http\Requests\StorePurchaseRequest;
use App\Http\Requests\VoidReasonRequest;
use App\Services\AuditService;
use Illuminate\Support\Facades\DB;
use App\Http\Resources\PurchaseReturnResource;
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
    public function __construct(
        private readonly PurchaseService $purchases,
        private readonly AuditService $audit,
    ) {}

    /** The picker in the goods flow and the suppliers list: name search, with what the store owes. */
    public function index(Request $request)
    {
        Gate::authorize('adjustStock', Product::class);
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:150'],
            // Archived suppliers leave the picker; the suppliers screen can still list them.
            'status' => ['nullable', Rule::in([Supplier::STATUS_ACTIVE, Supplier::STATUS_ARCHIVED, 'all'])],
        ]);
        $status = $filters['status'] ?? Supplier::STATUS_ACTIVE;

        $suppliers = Supplier::query()
            ->forStore($request->user()->store_id)
            ->withBalance()
            ->when($status !== 'all', fn($q) => $q->where('status', $status))
            ->when($filters['search'] ?? null, fn($q, string $search) => $q->where('name', 'like', '%' . $search . '%'))
            ->orderBy('name')
            ->limit(100)
            ->get();

        return response()->json(['data' => $suppliers->map(fn(Supplier $s) => $this->row($s))]);
    }

    /** The supplier: what is owed in all, the products bought, the payments made, the goods sent back. */
    public function show(Request $request, Supplier $supplier)
    {
        Gate::authorize('adjustStock', Product::class);
        $supplier->loadSum(['invoices as purchased' => fn($q) => $q->notVoided()], 'total')
            ->loadSum(['payments as paid' => fn($q) => $q->notVoided()], 'amount')
            ->loadSum(['returns as returned' => fn($q) => $q->notVoided()], 'balance_reduction');

        // A line sent back in full leaves the supplier's invoice; the rest count only what is left.
        $lines = PurchaseItem::query()
            ->whereIn('purchase_invoice_id', $supplier->invoices()->notVoided()->select('id'))
            ->with('product')
            ->get()
            ->reject(fn(PurchaseItem $item) => $item->isFullyReturned());
        $returnedValues = PurchaseItem::returnedValues($lines->pluck('id'));

        $products = $lines
            ->groupBy('product_id')
            ->map(fn($rows, $productId) => [
                'id' => (int) $productId,
                'name' => $rows->first()->product->name,
                'unit' => $rows->first()->product->unit,
                'total' => Money::sum($rows->map(fn(PurchaseItem $item) => Money::sub($item->line_total, $returnedValues[$item->id] ?? '0'))),
            ])
            ->sortBy('name')
            ->values();

        $payments = $supplier->payments()->with(['creator', 'voider'])->latest('id')->limit(200)->get()
            ->map(fn(SupplierPayment $payment) => [
                'id' => $payment->id,
                'at' => $payment->created_at,
                'by' => $payment->creator?->name,
                'amount' => Money::of($payment->amount),
                'method' => $payment->method,
                'purchase_invoice_id' => $payment->purchase_invoice_id,
                'status' => $payment->isVoided() ? 'voided' : 'active',
                'voided_at' => $payment->voided_at,
                'voided_by_name' => $payment->voider?->name,
                'void_reason' => $payment->void_reason,
            ]);

        $returns = $supplier->returns()->with(['creator', 'voider', 'items.purchaseItem.product'])->latest('id')->limit(200)->get();

        return response()->json(['data' => $this->row($supplier) + [
            'products' => $products,
            'payments' => $payments,
            'returns' => PurchaseReturnResource::collection($returns),
        ]]);
    }

    /**
     * One product at this supplier: its invoices, each with what is still on it. An invoice whose
     * whole quantity of the product went back to the supplier no longer lists it.
     */
    public function product(Request $request, Supplier $supplier, Product $product)
    {
        Gate::authorize('adjustStock', Product::class);

        $lines = $supplier->productLines($product->id)->with('invoice.creator')->latest('id')->limit(200)->get()
            ->reject(fn(PurchaseItem $item) => $item->isFullyReturned())
            ->values();
        $returnedValues = PurchaseItem::returnedValues($lines->pluck('id'));

        $invoices = $lines->map(function (PurchaseItem $item) use ($product, $returnedValues) {
            [$cartons, $loosePieces] = $item->remainingCartons();

            return [
                'id' => $item->id,
                'invoice_id' => $item->purchase_invoice_id,
                'at' => $item->created_at,
                'by' => $item->invoice->creator?->name,
                'quantity' => Quantity::format($item->remainingQuantity(), $product->unit),
                'bought_quantity' => Quantity::format($item->quantity, $product->unit),
                'returned_quantity' => Quantity::format($item->returned_quantity, $product->unit),
                'cartons' => $cartons,
                'pack_size' => $item->pack_size,
                'loose_pieces' => $loosePieces,
                'buy_price' => Money::of($item->buy_price),
                'total' => Money::sub($item->line_total, $returnedValues[$item->id] ?? '0'),
                'voided' => $item->invoice->isVoided(),
            ];
        });

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

    /** POST /suppliers/{id}/payments/{payment}/void: a payment recorded by mistake. */
    public function voidPayment(VoidReasonRequest $request, Supplier $supplier, SupplierPayment $payment)
    {
        abort_unless((int) $payment->supplier_id === (int) $supplier->id, 404);
        $this->purchases->voidPayment($request->user(), $payment, $request->validated('reason'));

        return response()->json([
            'message' => 'تم إلغاء الدفعة وأُعيد مبلغها إلى رصيد المورد.',
            'data' => ['balance' => $supplier->balance()],
        ]);
    }

    /** POST /suppliers/{id}/archive: hidden from the picker; its documents and balance stay. */
    public function archive(Request $request, Supplier $supplier)
    {
        return $this->setStatus($request, $supplier, Supplier::STATUS_ARCHIVED, 'supplier.archived', 'تمت أرشفة المورد. تبقى فواتيره ودفعاته كما هي.');
    }

    /** POST /suppliers/{id}/restore */
    public function restore(Request $request, Supplier $supplier)
    {
        return $this->setStatus($request, $supplier, Supplier::STATUS_ACTIVE, 'supplier.restored', 'تمت إعادة المورد إلى القائمة.');
    }

    /** DELETE /suppliers/{id}: only a supplier with no document at all; otherwise archive. */
    public function destroy(Request $request, Supplier $supplier)
    {
        Gate::authorize('adjustStock', Product::class);

        DB::transaction(function () use ($request, $supplier) {
            $locked = Supplier::query()->forStore($request->user()->store_id)->whereKey($supplier->id)->lockForUpdate()->firstOrFail();

            if ($locked->hasHistory()) {
                throw ApiException::conflict('SUPPLIER_IN_USE', 'لا يمكن حذف المورد لأن له فواتير أو دفعات أو مرتجعات. يمكنك أرشفته بدلًا من ذلك.');
            }

            $this->audit->record('supplier.deleted', $locked, ['name' => $locked->name, 'phone' => $locked->phone], $request->user());
            $locked->delete();
        });

        return response()->json(['message' => 'تم حذف المورد.']);
    }

    private function setStatus(Request $request, Supplier $supplier, string $status, string $action, string $message)
    {
        Gate::authorize('adjustStock', Product::class);

        if ($supplier->status !== $status) {
            DB::transaction(function () use ($request, $supplier, $status, $action) {
                $supplier->forceFill(['status' => $status])->save();
                $this->audit->record($action, $supplier, ['status' => $status], $request->user());
            });
        }

        $fresh = Supplier::query()->whereKey($supplier->id)->withBalance()->firstOrFail();

        return response()->json(['message' => $message, 'data' => $this->row($fresh)]);
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
            'status' => $supplier->status ?? Supplier::STATUS_ACTIVE,
            'balance' => Money::sub(Money::sub($supplier->purchased, $supplier->paid), $supplier->returned),
        ];
    }
}
