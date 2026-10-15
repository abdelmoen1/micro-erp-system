<?php

namespace App\Http\Controllers\Api;

use App\Models\Invoice;
use App\Models\Debt;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreInvoiceRequest;
use App\Http\Requests\UpdateInvoiceRequest;
use App\Http\Resources\InvoiceResource;
use App\Enums\InvoiceSource;
use App\Support\Money;

class InvoiceController extends Controller
{
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
     * Store a newly created resource in storage.
     */
    public function store(StoreInvoiceRequest $request)
    {
        $validated = $request->validated();

        $storeId = $request->user()->store_id;

        $totalAmount = self::itemsTotal($validated['items']);

        $invoice = DB::transaction(function () use ($validated, $totalAmount, $storeId) {
            $invoice = Invoice::create([
                'store_id' => $storeId,
                'customer_id' => $validated['customer_id'],
                'has_debt' => $validated['has_debt'],
                'payment_method' => $validated['has_debt']
                    ? null
                    : $validated['payment_method'],
                'total_amount' => $totalAmount,
                'source' => InvoiceSource::SALE,
            ]);

            self::createItems($invoice, $validated['items']);

            if ($validated['has_debt'] === true) {
                Debt::create([
                    'invoice_id' => $invoice->id,
                    'store_id' => $storeId,
                    'amount' => $totalAmount,
                    'remaining_amount' => $totalAmount,
                    'status' => 'unpaid',
                ]);
            }

            return $invoice;
        });

        return response()->json([
            'message' => 'تم حفظ الفاتورة'
                . ($validated['has_debt'] ? ' وتسجيل الدين' : '')
                . ' بنجاح.',
            'data' => new InvoiceResource(
                $invoice->load(['customer', 'items', 'debt.payments'])
            ),
        ], 201);
    }

    /**
     * Display the specified resource.
     */
    public function show(Request $request, Invoice $invoice)
    {
        abort_unless(
            $invoice->store_id === $request->user()->store_id,
            404
        );

        $invoice->load([
            'customer',
            'items',
            'debt.payments',
        ]);

        return new InvoiceResource($invoice);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(
        UpdateInvoiceRequest $request,
        Invoice $invoice
    ) {
        abort_unless(
            $invoice->store_id === $request->user()->store_id,
            404
        );

        $validated = $request->validated();

        $updatedInvoice = DB::transaction(function () use (
            $validated,
            $invoice
        ) {
            $invoice = Invoice::query()
                ->whereKey($invoice->id)
                ->where('store_id', $invoice->store_id)
                ->lockForUpdate()
                ->with('debt')
                ->firstOrFail();

            /*
         * ------------------------------------------------------
         * 1. Invoice Debt -> Cash Invoice
         * ------------------------------------------------------
         */
            if (
                array_key_exists('has_debt', $validated)
                && $invoice->has_debt
                && $validated['has_debt'] === false
            ) {
                $debt = $invoice->debt;

                if ($debt) {
                    if ($debt->payments()->exists()) {
                        abort(
                            422,
                            'لا يمكن تحويل الفاتورة إلى نقدية لأن الدين عليه دفعات مسجلة.'
                        );
                    }

                    $debt->delete();
                }

                $invoice->has_debt = false;
                $invoice->payment_method = $validated['payment_method'];
            }

            /*
         * ------------------------------------------------------
         * 2. Cash Invoice -> Debt Invoice
         * ------------------------------------------------------
         *
         * لا نسمح بتحويل فاتورة نقدية إلى دين من خلال Update.
         * إذا أراد المستخدم ذلك، ينشئ فاتورة دين جديدة.
         */
            if (
                array_key_exists('has_debt', $validated)
                && !$invoice->has_debt
                && $validated['has_debt'] === true
            ) {
                abort(
                    422,
                    'لا يمكن تحويل الفاتورة النقدية إلى فاتورة دين. أنشئ فاتورة دين جديدة.'
                );
            }

            /*
         * ------------------------------------------------------
         * 3. Customer
         * ------------------------------------------------------
         */
            if (array_key_exists('customer_id', $validated)) {
                $invoice->customer_id = $validated['customer_id'];
            }

            /*
         * ------------------------------------------------------
         * 4. Invoice Items
         * ------------------------------------------------------
         */
            if (array_key_exists('items', $validated)) {

                if (
                    $invoice->has_debt
                    && $invoice->debt
                    && $invoice->debt->payments()->exists()
                ) {
                    abort(
                        422,
                        'لا يمكن تعديل عناصر الفاتورة لأن عليها دفعات مسجلة.'
                    );
                }

                $totalAmount = self::itemsTotal($validated['items']);

                $invoice->items()->delete();

                self::createItems($invoice, $validated['items']);

                $invoice->total_amount = $totalAmount;

                /*
             * If this invoice still has an unpaid debt,
             * keep the debt amount synchronized.
             */
                if (
                    $invoice->has_debt
                    && $invoice->debt
                    && !$invoice->debt->payments()->exists()
                ) {
                    $invoice->debt->amount = $totalAmount;
                    $invoice->debt->remaining_amount = $totalAmount;
                    $invoice->debt->status = 'unpaid';
                    $invoice->debt->save();
                }
            }

            $invoice->save();

            return $invoice->fresh()->load([
                'customer',
                'items',
                'debt.payments',
            ]);
        });

        return response()->json([
            'message' => 'تم تحديث الفاتورة بنجاح.',
            'data' => new InvoiceResource($updatedInvoice),
        ]);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(
        Request $request,
        Invoice $invoice
    ) {
        $this->authorize('delete', $invoice);

        DB::transaction(function () use ($invoice) {
            $lockedInvoice = Invoice::query()
                ->whereKey($invoice->id)
                ->where('store_id', $invoice->store_id)
                ->with('debt')
                ->lockForUpdate()
                ->firstOrFail();

            if ($lockedInvoice->debt?->payments()->exists()) {
                abort(
                    422,
                    'لا يمكن حذف الفاتورة لأنها تحتوي على دفعات مسجلة.'
                );
            }

            if ($lockedInvoice->debt) {
                $lockedInvoice->debt->forceDelete();
            }

            $lockedInvoice->delete();
        });

        return response()->json([
            'message' => 'تم حذف الفاتورة بنجاح.',
        ]);
    }

    /**
     * Exact invoice total: Σ unit_price × quantity (US-0102).
     */
    private static function itemsTotal(array $items): string
    {
        return Money::sum(array_map(
            fn(array $item) => Money::times($item['unit_price'], (int) $item['quantity']),
            $items,
        ));
    }

    private static function createItems(Invoice $invoice, array $items): void
    {
        foreach ($items as $item) {
            $invoice->items()->create([
                'item_name' => $item['item_name'],
                'quantity' => $item['quantity'],
                'unit_price' => Money::of($item['unit_price']),
                'total' => Money::times($item['unit_price'], (int) $item['quantity']),
            ]);
        }
    }
}
