<?php

namespace App\Http\Controllers\Api;

use App\Models\Invoice;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreSaleRequest;
use App\Http\Requests\UpdateInvoiceRequest;
use App\Http\Requests\VoidSaleRequest;
use App\Http\Resources\InvoiceResource;
use App\Services\SaleService;

/**
 * Sales (US-0501 – US-0503). Served at /sales; /invoices stays as an alias of the same handlers.
 * An invoice is final at creation (D-06): there is no delete and no financial edit, only `notes`
 * and a void. Other stores' invoices resolve to 404 through BelongsToStore route binding.
 */
class InvoiceController extends Controller
{
    public function __construct(private readonly SaleService $sales) {}

    /**
     * Display a listing of the resource.
     */
    public function index(Request $request)
    {
        $invoices = Invoice::with([
            'customer',
            'items',
            'debt.payments',
        ])
            ->where('store_id', $request->user()->store_id)
            ->latest()
            ->paginate(10);

        return InvoiceResource::collection($invoices);
    }

    /**
     * POST /sales: cash, credit or partial sale in one transaction. A stock shortfall is not an
     * error (D-27): the sale is saved and the response carries `flags` and `warnings`.
     */
    public function store(StoreSaleRequest $request)
    {
        ['invoice' => $invoice, 'warnings' => $warnings] = $this->sales->create(
            $request->user(),
            $request->validated(),
        );

        return response()->json([
            'message' => 'تم حفظ عملية البيع'
                . ($invoice->has_debt ? ' وتسجيل الدين' : '')
                . ' بنجاح.',
            'data' => new InvoiceResource($invoice),
            'flags' => array_values(array_unique(array_column($warnings, 'code'))),
            'warnings' => $warnings,
        ], 201);
    }

    /**
     * Display the specified resource.
     */
    public function show(Invoice $invoice)
    {
        $invoice->load([
            'customer',
            'items',
            'debt.payments',
        ]);

        return new InvoiceResource($invoice);
    }

    /** PATCH /sales/{id}: notes only (US-0503 AC1). */
    public function update(UpdateInvoiceRequest $request, Invoice $invoice)
    {
        $invoice->update(['notes' => $request->validated('notes')]);

        return response()->json([
            'message' => 'تم تحديث ملاحظات الفاتورة.',
            'data' => new InvoiceResource($invoice->load(['customer', 'items', 'debt.payments'])),
        ]);
    }

    /** POST /sales/{id}/void (US-0503 AC2–AC4). */
    public function void(VoidSaleRequest $request, Invoice $invoice)
    {
        $voided = $this->sales->void($request->user(), $invoice, $request->validated('reason'));

        return response()->json([
            'message' => 'تم إلغاء الفاتورة وإرجاع المخزون.',
            'data' => new InvoiceResource($voided),
        ]);
    }
}
