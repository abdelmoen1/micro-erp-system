<?php

namespace App\Http\Requests;

use App\Models\Product;
use Illuminate\Foundation\Http\FormRequest;

/**
 * The reason every cancel, void or reversal of a posted record carries (kept on the row and in the
 * audit log). Owner / Manager only, checked before validation so staff get 403, not 422. The
 * record itself was already resolved inside the caller's store (BelongsToStore route binding).
 */
class VoidReasonRequest extends FormRequest
{
    public function authorize(): bool
    {
        // A sale return follows the sale's own rule (US-0601 AC6); supplier and stock records
        // follow the suppliers and stock rule (05 §6).
        if ($saleReturn = $this->route('saleReturn')) {
            return $this->user()->can('return', $saleReturn->invoice);
        }

        return $this->user()->can('adjustStock', Product::class);
    }

    protected function prepareForValidation(): void
    {
        if (is_string($this->reason)) {
            $this->merge(['reason' => trim($this->reason)]);
        }
    }

    public function rules(): array
    {
        return [
            'reason' => ['required', 'string', 'max:500'],
        ];
    }

    public function messages(): array
    {
        return [
            'reason.required' => 'يجب كتابة سبب الإلغاء.',
            'reason.max' => 'السبب طويل جدًا.',
        ];
    }
}
