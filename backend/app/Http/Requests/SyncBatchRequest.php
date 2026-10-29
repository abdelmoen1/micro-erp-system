<?php

namespace App\Http\Requests;

use App\Services\SyncService;
use App\Support\Money;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * POST /sync/batch (US-1101, 05 §4.2). Only the envelope is checked here; each item's payload is
 * checked by its own online request (StoreSaleRequest / PayAllDebtsRequest) so a bad item is held
 * for review instead of blocking the whole queue.
 */
class SyncBatchRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'device_id' => ['required', 'string', 'max:64'],
            'items' => ['required', 'array', 'min:1', 'max:' . SyncService::MAX_BATCH],
            'items.*.client_transaction_id' => ['required', 'uuid', 'distinct:ignore_case'],
            'items.*.seq' => ['required', 'integer', 'min:1'],
            'items.*.type' => ['required', Rule::in(['sale', 'payment'])],
            'items.*.occurred_at' => ['required', 'date'],
            'items.*.payload' => ['required', 'array'],
            'items.*.charged' => ['nullable', 'array', 'max:200'],
            'items.*.charged.*.product_id' => ['required', 'integer'],
            'items.*.charged.*.sale_unit' => ['nullable', 'string'],
            'items.*.charged.*.unit_price' => ['required', 'numeric', 'decimal:0,2', 'min:0', 'max:' . Money::MAX],
        ];
    }

    public function messages(): array
    {
        return [
            'items.max' => 'الدفعة تقبل ' . SyncService::MAX_BATCH . ' عملية كحد أقصى.',
            'items.*.client_transaction_id.uuid' => 'معرّف العملية يجب أن يكون بصيغة UUID.',
            'items.*.client_transaction_id.distinct' => 'العملية مكررة في الدفعة.',
            'items.*.type.in' => 'نوع العملية غير مدعوم دون اتصال.',
        ];
    }

    /** @return list<array<string, mixed>> items in the device's FIFO order */
    public function orderedItems(): array
    {
        return collect($this->validated('items'))->sortBy('seq')->values()->all();
    }
}
