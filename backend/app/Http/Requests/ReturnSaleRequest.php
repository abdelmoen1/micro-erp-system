<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/** POST /sales/{id}/returns (US-0601): Owner / Manager, at least one line, reason required. */
class ReturnSaleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('return', $this->route('invoice'));
    }

    public function rules(): array
    {
        return [
            'items' => ['required', 'array', 'min:1', 'max:200'],
            'items.*.invoice_item_id' => ['required', 'integer'],
            'items.*.quantity' => ['required', 'numeric', 'decimal:0,3'],
            'reason' => ['required', 'string', 'max:500'],
        ];
    }

    public function messages(): array
    {
        return [
            'items.required' => 'اختر صنفًا واحدًا على الأقل للإرجاع.',
            'items.min' => 'اختر صنفًا واحدًا على الأقل للإرجاع.',
            'items.*.invoice_item_id.required' => 'الصنف مطلوب.',
            'items.*.quantity.required' => 'الكمية المرتجعة مطلوبة.',
            'items.*.quantity.numeric' => 'الكمية المرتجعة يجب أن تكون رقمًا.',
            'items.*.quantity.decimal' => 'الكمية تقبل 3 خانات عشرية على الأكثر.',
            'reason.required' => 'يجب كتابة سبب الإرجاع.',
            'reason.max' => 'السبب طويل جدًا.',
        ];
    }
}
