<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\Customer;
use App\Models\InventoryReservation;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\ReceivingAccount;
use App\Models\SuspendedInvoice;
use App\Models\SuspendedInvoiceEvent;
use App\Models\User;
use App\Support\Money;
use App\Support\Pack;
use App\Support\Quantity;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SuspendedSaleService
{
    public function __construct(private readonly SaleService $sales) {}

    public function suspend(User $actor, array $data): SuspendedInvoice
    {
        return DB::transaction(function () use ($actor, $data) {
            $account = ReceivingAccount::query()
                ->forStore($actor->store_id)
                ->whereKey((int) $data['receiving_account_id'])
                ->where('provider', $data['payment_method'])
                ->where('active', true)
                ->whereNull('deleted_at')
                ->lockForUpdate()
                ->first();

            if (!$account) {
                throw ValidationException::withMessages([
                    'receiving_account_id' => ['حساب الاستقبال غير صالح أو غير نشط لهذا المزود.'],
                ]);
            }

            $customer = null;
            if (!empty($data['customer_id'])) {
                $customer = Customer::query()->forStore($actor->store_id)
                    ->whereKey((int) $data['customer_id'])->where('status', 'active')
                    ->lockForUpdate()->first();
                if (!$customer) {
                    throw ValidationException::withMessages(['customer_id' => ['العميل غير موجود أو موقوف.']]);
                }
            }

            $ids = collect($data['items'])->pluck('product_id')->map(fn($id) => (int) $id)->unique()->sort()->values();
            $products = Product::query()->forStore($actor->store_id)->whereIn('id', $ids)
                ->orderBy('id')->lockForUpdate()->get()->keyBy('id');

            $subtotal = '0.00';
            $lines = [];
            $errors = [];

            foreach ($data['items'] as $index => $item) {
                $product = $products->get((int) $item['product_id']);
                if (!$product || !$product->isActive()) {
                    $errors["items.{$index}.product_id"] = ['المنتج غير موجود أو موقوف.'];
                    continue;
                }

                $byPack = ($item['sale_unit'] ?? null) === Pack::SALE_UNIT;
                if ($byPack && !$product->hasPack()) {
                    $errors["items.{$index}.sale_unit"] = ['هذا المنتج لا يُباع بالكرتونة.'];
                    continue;
                }

                $quantity = Quantity::of((string) $item['quantity']);
                if (!Quantity::fitsUnit($quantity, $byPack ? Quantity::UNIT_PIECE : $product->unit)) {
                    $errors["items.{$index}.quantity"] = ['الكمية غير صالحة لوحدة هذا المنتج.'];
                    continue;
                }

                $packSize = $byPack ? (int) $product->pack_size : null;
                $baseQuantity = Pack::baseQuantity($quantity, $packSize);
                $serverUnitPrice = Money::of($byPack ? $product->pack_price : $product->selling_price);
                $charged = isset($item['unit_price']) ? Money::of((string) $item['unit_price']) : $serverUnitPrice;
                $lineTotal = Money::times($charged, $quantity);
                $subtotal = Money::sum([$subtotal, $lineTotal]);

                $lines[] = [
                    'product' => $product,
                    'quantity' => $quantity,
                    'base_quantity' => $baseQuantity,
                    'sale_unit' => $byPack ? Pack::SALE_UNIT : null,
                    'pack_size' => $packSize,
                    'unit_price' => $charged,
                    'total' => $lineTotal,
                ];
            }

            if ($errors !== []) {
                throw ValidationException::withMessages($errors);
            }

            $discount = Money::of($data['discount_amount'] ?? '0');
            if (Money::compare($discount, $subtotal) >= 0 && Money::isPositive($discount)) {
                throw ValidationException::withMessages(['discount_amount' => ['الخصم يجب أن يكون أقل من مجموع الفاتورة.']]);
            }
            $total = Money::sub($subtotal, $discount);

            foreach ($lines as $line) {
                $reserved = InventoryReservation::query()
                    ->where('store_id', $actor->store_id)
                    ->where('product_id', $line['product']->id)
                    ->where('status', InventoryReservation::STATUS_ACTIVE)
                    ->lockForUpdate()
                    ->sum('quantity');
                $available = Money::sub((string) $line['product']->current_stock, (string) $reserved);
                if (Quantity::compare($available, $line['base_quantity']) < 0) {
                    throw ValidationException::withMessages([
                        "items" => ["المخزون المتاح غير كافٍ للمنتج {$line['product']->name} بعد الحجوزات الحالية."],
                    ]);
                }
            }

            $invoice = SuspendedInvoice::create([
                'store_id' => $actor->store_id,
                'reference' => 'H-' . now()->format('Ymd-His') . '-' . str_pad((string) random_int(0, 9999), 4, '0', STR_PAD_LEFT),
                'customer_id' => $customer?->id,
                'cashier_id' => $actor->id,
                'status' => SuspendedInvoice::STATUS_PENDING_TRANSFER,
                'subtotal' => $subtotal,
                'discount_amount' => $discount,
                'total_amount' => $total,
                'payment_method' => $data['payment_method'],
                'receiving_account_id' => $account->id,
                'account_snapshot_name' => $account->account_name,
                'account_snapshot_provider' => $account->provider,
                'account_snapshot_identifier' => $account->account_identifier,
                'idempotency_key' => $data['idempotency_key'] ?? null,
                'notes' => $data['notes'] ?? null,
            ]);

            foreach ($lines as $line) {
                $product = $line['product'];
                $invoice->items()->create([
                    'product_id' => $product->id,
                    'item_name' => $product->name,
                    'unit' => $product->unit,
                    'quantity' => $line['quantity'],
                    'sale_unit' => $line['sale_unit'],
                    'pack_size' => $line['pack_size'],
                    'unit_price' => $line['unit_price'],
                    'total' => $line['total'],
                ]);
                InventoryReservation::create([
                    'store_id' => $actor->store_id,
                    'product_id' => $product->id,
                    'suspended_invoice_id' => $invoice->id,
                    'quantity' => $line['base_quantity'],
                    'status' => InventoryReservation::STATUS_ACTIVE,
                ]);
            }

            $this->event($invoice, $actor, null, SuspendedInvoice::STATUS_PENDING_TRANSFER, 'suspended', [
                'account_id' => $account->id,
                'account_snapshot' => [
                    'name' => $account->account_name,
                    'provider' => $account->provider,
                    'identifier' => $account->account_identifier,
                ],
            ]);

            return $invoice->load(['customer', 'cashier', 'items', 'reservations', 'events']);
        });
    }

    public function confirm(User $actor, SuspendedInvoice $invoice): array
    {
        return DB::transaction(function () use ($actor, $invoice) {
            $locked = SuspendedInvoice::query()->forStore($actor->store_id)
                ->whereKey($invoice->id)->lockForUpdate()->firstOrFail();

            if ($locked->status === SuspendedInvoice::STATUS_COMPLETED) {
                $final = Invoice::query()->forStore($actor->store_id)
                    ->whereKey($locked->final_invoice_id)->firstOrFail();
                return ['invoice' => $final, 'suspended' => $locked, 'already_completed' => true];
            }
            if ($locked->status !== SuspendedInvoice::STATUS_PENDING_TRANSFER) {
                throw ApiException::conflict('SUSPENDED_INVOICE_NOT_PENDING', 'لا يمكن تأكيد فاتورة ليست قيد انتظار التحويل.');
            }

            $locked->load('items');
            $saleItems = [];
            $ids = $locked->items->pluck('product_id')->sort()->values();
            $products = Product::query()->forStore($actor->store_id)->whereIn('id', $ids)
                ->orderBy('id')->lockForUpdate()->get()->keyBy('id');

            foreach ($locked->items as $item) {
                $reservation = InventoryReservation::query()->where('suspended_invoice_id', $locked->id)
                    ->where('product_id', $item->product_id)->where('status', InventoryReservation::STATUS_ACTIVE)
                    ->lockForUpdate()->first();
                if (!$reservation) {
                    throw ApiException::conflict('RESERVATION_MISSING', 'حجز المخزون غير متاح ولا يمكن إكمال الفاتورة.');
                }
                $product = $products->get($item->product_id);
                if (!$product) {
                    throw ApiException::conflict('RESERVATION_PRODUCT_MISSING', 'أحد منتجات الفاتورة لم يعد متاحًا.');
                }
                $saleItems[] = [
                    'product_id' => $product->id,
                    'quantity' => (string) $item->quantity,
                    'sale_unit' => $item->sale_unit,
                    'unit_price' => (string) $item->unit_price,
                ];
            }

            $result = $this->sales->create($actor, [
                'customer_id' => $locked->customer_id,
                'items' => $saleItems,
                'discount_amount' => (string) $locked->discount_amount,
                'paid_amount' => (string) $locked->total_amount,
                'payment_method' => $locked->payment_method,
                'notes' => $locked->notes,
            ]);
            $final = $result['invoice'];

            foreach ($locked->reservations()->lockForUpdate()->get() as $reservation) {
                $reservation->update([
                    'status' => InventoryReservation::STATUS_DEDUCTED,
                    'deducted_at' => now(),
                ]);
            }
            $locked->update([
                'status' => SuspendedInvoice::STATUS_COMPLETED,
                'final_invoice_id' => $final->id,
                'closed_by' => $actor->id,
                'closed_at' => now(),
            ]);
            $this->event($locked, $actor, SuspendedInvoice::STATUS_PENDING_TRANSFER, SuspendedInvoice::STATUS_COMPLETED, 'confirmed', [
                'final_invoice_id' => $final->id,
                'payment_method' => $locked->payment_method,
                'receiving_account_id' => $locked->receiving_account_id,
            ]);

            return ['invoice' => $final, 'suspended' => $locked->fresh(), 'already_completed' => false];
        });
    }

    public function close(User $actor, SuspendedInvoice $invoice, string $status, ?string $reason = null): SuspendedInvoice
    {
        if (!in_array($status, [SuspendedInvoice::STATUS_REJECTED, SuspendedInvoice::STATUS_CANCELLED], true)) {
            throw ValidationException::withMessages(['status' => ['حالة الإغلاق غير صالحة.']]);
        }
        return DB::transaction(function () use ($actor, $invoice, $status, $reason) {
            $locked = SuspendedInvoice::query()->forStore($actor->store_id)
                ->whereKey($invoice->id)->lockForUpdate()->firstOrFail();
            if (!in_array($locked->status, [SuspendedInvoice::STATUS_DRAFT, SuspendedInvoice::STATUS_PENDING_TRANSFER], true)) {
                throw ApiException::conflict('SUSPENDED_INVOICE_NOT_OPEN', 'هذه الفاتورة ليست معلقة ويمكن إغلاقها مسبقًا.');
            }
            foreach ($locked->reservations()->lockForUpdate()->get() as $reservation) {
                if ($reservation->status === InventoryReservation::STATUS_ACTIVE) {
                    $reservation->update(['status' => InventoryReservation::STATUS_RELEASED, 'released_at' => now()]);
                }
            }
            $oldStatus = $locked->status;
            $locked->update([
                'status' => $status,
                'cancellation_reason' => $reason,
                'closed_by' => $actor->id,
                'closed_at' => now(),
            ]);
            $this->event($locked, $actor, $oldStatus, $status, $status === SuspendedInvoice::STATUS_REJECTED ? 'rejected' : 'cancelled', [
                'reason' => $reason,
            ]);
            return $locked->load(['customer', 'cashier', 'items', 'reservations', 'events']);
        });
    }

    private function event(
        SuspendedInvoice $invoice,
        User $actor,
        ?string $from,
        string $to,
        string $event,
        array $metadata,
    ): void {
        SuspendedInvoiceEvent::create([
            'store_id' => $actor->store_id,
            'suspended_invoice_id' => $invoice->id,
            'user_id' => $actor->id,
            'from_status' => $from,
            'to_status' => $to,
            'event' => $event,
            'metadata' => $metadata,
        ]);
    }
}
