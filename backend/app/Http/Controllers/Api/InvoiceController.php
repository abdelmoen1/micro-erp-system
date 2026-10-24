<?php

namespace App\Http\Controllers\Api;

use App\Models\Invoice;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use App\Http\Requests\ReturnSaleRequest;
use App\Http\Requests\StoreSaleRequest;
use App\Http\Requests\UpdateInvoiceRequest;
use App\Http\Requests\VoidSaleRequest;
use App\Http\Resources\InvoiceResource;
use App\Http\Resources\SaleReturnResource;
use App\Services\ReturnService;
use App\Services\SaleService;
use App\Support\BusinessClock;
use Carbon\CarbonImmutable;
use Illuminate\Validation\Rule;

/**
 * Sales (US-0501 – US-0503). Served at /sales; /invoices stays as an alias of the same handlers.
 * An invoice is final at creation (D-06): there is no delete and no financial edit, only `notes`
 * and a void. Other stores' invoices resolve to 404 through BelongsToStore route binding.
 */
class InvoiceController extends Controller
{
    public function __construct(
        private readonly SaleService $sales,
        private readonly ReturnService $returns,
    ) {}

    /**
     * W-10 sales list (US-0504 AC1): local-date range in the store timezone, type (cash = nothing
     * owed at the sale, credit = nothing paid, partial = both), status and customer. `source`
     * keeps opening debts out of the sales list when set to `sale`.
     */
    public function index(Request $request)
    {
        $filters = $request->validate([
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to' => ['nullable', 'date_format:Y-m-d'],
            'type' => ['nullable', Rule::in(['cash', 'credit', 'partial'])],
            'status' => ['nullable', Rule::in([Invoice::STATUS_ACTIVE, Invoice::STATUS_VOIDED, 'all'])],
            'source' => ['nullable', Rule::in(['sale', 'opening_debt', 'all'])],
            'customer_id' => ['nullable', 'integer'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $user = $request->user();
        $timezone = BusinessClock::forStore($user->store)->timezone();

        $invoices = Invoice::with(['customer', 'items', 'debt.payments', 'creator'])
            ->where('store_id', $user->store_id)
            ->when(($filters['source'] ?? 'all') !== 'all', fn($q) => $q->where('source', $filters['source']))
            ->when(($filters['status'] ?? 'all') !== 'all', fn($q) => $q->where('status', $filters['status']))
            ->when($filters['customer_id'] ?? null, fn($q, $id) => $q->where('customer_id', $id))
            ->when($filters['from'] ?? null, fn($q, $day) => $q->where('created_at', '>=', CarbonImmutable::parse($day, $timezone)->startOfDay()->utc()))
            ->when($filters['to'] ?? null, fn($q, $day) => $q->where('created_at', '<=', CarbonImmutable::parse($day, $timezone)->endOfDay()->utc()))
            ->when($filters['type'] ?? null, fn($q, $type) => match ($type) {
                'cash' => $q->where('has_debt', false),
                'credit' => $q->where('has_debt', true)->where('paid_amount', 0),
                'partial' => $q->where('has_debt', true)->where('paid_amount', '>', 0),
            })
            ->latest()
            ->orderByDesc('id')
            ->paginate($filters['per_page'] ?? 10);

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
            'creator',
            'voider',
            'returns.items.invoiceItem',
            'returns.creator',
        ]);

        return new InvoiceResource($invoice);
    }

    /** PATCH /sales/{id}: notes only (US-0503 AC1). */
    public function update(UpdateInvoiceRequest $request, Invoice $invoice)
    {
        $invoice->update(['notes' => $request->validated('notes')]);

        return response()->json([
            'message' => 'تم تحديث ملاحظات الفاتورة.',
            'data' => new InvoiceResource($invoice->load(['customer', 'items', 'debt.payments', 'creator', 'voider'])),
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

    /** POST /sales/{id}/returns (US-0601): the server computes the split; the client only previews. */
    public function storeReturn(ReturnSaleRequest $request, Invoice $invoice)
    {
        $validated = $request->validated();
        $return = $this->returns->create($request->user(), $invoice, $validated['items'], $validated['reason']);
        $return->load('items.invoiceItem');

        return response()->json([
            'message' => 'تم تسجيل المرتجع وإعادة الكميات إلى المخزون.',
            'data' => new SaleReturnResource($return),
            'invoice' => new InvoiceResource($invoice->fresh()->load([
                'customer', 'items', 'debt.payments', 'creator', 'voider', 'returns.items.invoiceItem', 'returns.creator',
            ])),
        ], 201);
    }
}
