<?php

namespace App\Http\Requests;

use App\Models\Product;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** US-0402 AC1, AC4: a signed, non-zero integer change (CR-13) with a required reason. */
class StoreStockAdjustmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('adjustStock', Product::class);
    }

    public function rules(): array
    {
        return [
            'product_id' => [
                'required',
                'integer',
                Rule::exists('products', 'id')->where(fn($query) => $query->where('store_id', $this->user()->store_id)),
            ],
            'quantity' => ['required', 'integer', 'not_in:0', 'min:-1000000', 'max:1000000'],
            'reason' => ['required', 'string', 'max:500'],
        ];
    }

    public function messages(): array
    {
        return [
            'product_id.required' => 'يرجى تحديد المنتج.',
            'product_id.exists' => 'المنتج المحدد غير موجود.',
            'quantity.required' => 'يرجى إدخال كمية التعديل.',
            'quantity.integer' => 'الكمية يجب أن تكون عددًا صحيحًا',
            'quantity.not_in' => 'كمية التعديل لا يمكن أن تكون صفرًا.',
            'quantity.min' => 'كمية التعديل خارج الحد المسموح.',
            'quantity.max' => 'كمية التعديل خارج الحد المسموح.',
            'reason.required' => 'يجب كتابة سبب تعديل المخزون.',
            'reason.max' => 'السبب طويل جدًا',
        ];
    }
}
