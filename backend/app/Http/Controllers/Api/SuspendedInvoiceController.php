<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\PaymentMethods;
use App\Models\SuspendedInvoice;
use App\Services\SuspendedSaleService;
use Illuminate\Http\Request;
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
        $data = $request->validate([
            'customer_id' => ['nullable', 'integer'],
            'items' => ['required', 'array', 'min:1', 'max:200'],
            'items.*.product_id' => ['required', 'integer'],
            'items.*.quantity' => ['required', 'numeric', 'gt:0'],
            'items.*.sale_unit' => ['nullable', 'in:pack'],
            'items.*.unit_price' => ['nullable', 'numeric', 'gt:0'],
            'discount_amount' => ['nullable', 'numeric', 'min:0'],
            'payment_method' => ['required', Rule::in(PaymentMethods::ALL)],
            'receiving_account_id' => ['required', 'integer'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);
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

    public function close(Request $request, SuspendedInvoice $invoice)
    {
        $data = $request->validate([
            'status' => ['required', Rule::in([SuspendedInvoice::STATUS_REJECTED, SuspendedInvoice::STATUS_CANCELLED])],
            'reason' => ['nullable', 'string', 'max:1000'],
        ]);
        $closed = $this->service->close($request->user(), $invoice, $data['status'], $data['reason'] ?? null);
        return response()->json(['message' => 'تم إغلاق الفاتورة وإطلاق الحجوزات.', 'data' => $closed]);
    }
}
