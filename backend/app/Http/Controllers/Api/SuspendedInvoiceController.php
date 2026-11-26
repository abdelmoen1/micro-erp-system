<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\PaymentMethods;
use App\Models\SuspendedInvoice;
use App\Services\SuspendedSaleService;
use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class SuspendedInvoiceController extends Controller
{
    public function __construct(private readonly SuspendedSaleService $service) {}

    public function index(Request $request)
    {
        $status = $request->validate([
            'status' => ['nullable', Rule::in([
                SuspendedInvoice::STATUS_PENDING_TRANSFER,
                SuspendedInvoice::STATUS_COMPLETED,
                SuspendedInvoice::STATUS_REJECTED,
                SuspendedInvoice::STATUS_CANCELLED,
                'all',
            ])],
        ])['status'] ?? 'pending_transfer';

        $query = SuspendedInvoice::query()->forStore($request->user()->store_id)
            ->with(['customer', 'cashier', 'items.product', 'reservations', 'events']);
        if ($status !== 'all') {
            $query->where('status', $status);
        }
        return response()->json(['data' => $query->latest()->get()]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'store_id' => ['prohibited'],
            'customer_id' => [
                'nullable',
                'integer',
                Rule::exists('customers', 'id')
                    ->where(fn($query) => $query->where('store_id', $request->user()->store_id)->whereNull('deleted_at')),
            ],
            'items' => ['required', 'array', 'min:1', 'max:200'],
            'items.*.product_id' => ['required', 'integer'],
            'items.*.quantity' => ['required', ...Quantity::inputRules(null)],
            'items.*.sale_unit' => ['nullable', 'in:pack'],
            'items.*.unit_price' => ['nullable', 'numeric', 'decimal:0,2', 'gt:0', 'max:' . Money::MAX],
            'discount_amount' => ['nullable', 'numeric', 'decimal:0,2', 'min:0', 'max:' . Money::MAX],
            'payment_method' => ['required', Rule::in(PaymentMethods::TRANSFER_PROVIDERS)],
            'receiving_account_id' => ['required', 'integer'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);
        $validator->after(function ($validator) use ($request): void {
            $seen = [];
            foreach ((array) $request->input('items', []) as $index => $item) {
                if (!is_array($item) || !isset($item['product_id'])) {
                    continue;
                }
                $lineIdentity = $item['product_id'] . '|' . ($item['sale_unit'] ?? '');
                if (isset($seen[$lineIdentity])) {
                    $validator->errors()->add("items.{$index}.product_id", 'كرر المنتج في نفس وحدة البيع؛ عدّل الكمية بدل التكرار.');
                }
                $seen[$lineIdentity] = true;
            }
        });
        $data = $validator->validate();
        $data['idempotency_key'] = $request->header('Idempotency-Key');
        $invoice = $this->service->suspend($request->user(), $data);
        return response()->json(['message' => 'تم تعليق الفاتورة وجميع الكميات محجوزة.', 'data' => $invoice], 201);
    }

    public function show(Request $request, SuspendedInvoice $invoice)
    {
        if ($invoice->store_id !== $request->user()->store_id) {
            abort(404);
        }
        $invoice->load(['customer', 'cashier', 'items.product', 'reservations', 'events', 'finalInvoice']);
        return response()->json(['data' => $invoice]);
    }

    public function confirm(Request $request, SuspendedInvoice $invoice)
    {
        $result = $this->service->confirm($request->user(), $invoice);
        return response()->json([
            'message' => $result['already_completed'] ? 'تم إكمال الفاتورة مسبقًا.' : 'تم تأكيد التحويل وإكمال الفاتورة.',
            'data' => $result['suspended'],
            'final_invoice' => $result['invoice'],
            'already_completed' => $result['already_completed'],
        ]);
    }

    /** DELETE /suspended-invoices/{id}/items/{item}: a line removed before the invoice is confirmed. */
    public function removeItem(Request $request, SuspendedInvoice $invoice, int $item)
    {
        $updated = $this->service->removeItem($request->user(), $invoice, $item);

        return response()->json(['message' => 'تم حذف البند وإعادة حساب الإجمالي.', 'data' => $updated]);
    }

    public function close(Request $request, SuspendedInvoice $invoice)
    {
        $data = $request->validate([
            'status' => ['required', Rule::in([SuspendedInvoice::STATUS_REJECTED, SuspendedInvoice::STATUS_CANCELLED])],
            'reason' => ['required_if:status,cancelled', 'nullable', 'string', 'max:1000'],
        ]);
        $closed = $this->service->close($request->user(), $invoice, $data['status'], $data['reason'] ?? null);
        return response()->json(['message' => 'تم إغلاق الفاتورة وإطلاق الحجوزات.', 'data' => $closed]);
    }
}
