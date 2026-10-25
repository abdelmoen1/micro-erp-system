<?php

namespace App\Http\Requests;

use App\Models\Product;
use App\Support\Pack;
use App\Support\Quantity;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/**
 * US-0402 AC1, AC4: a signed, non-zero change with a required reason. CR-13: whole for piece
 * products, up to 3 decimals for kg products.
 */
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
            'quantity' => [
                'required',
                ...Quantity::inputRules($this->productUnit(), signed: true),
                function (string $attribute, mixed $value, \Closure $fail) {
                    if (is_numeric($value) && Quantity::isZero((string) $value)) {
                        $fail('كمية التعديل لا يمكن أن تكون صفرًا.');
                    }
                },
            ],
            'reason' => ['required', 'string', 'max:500'],
            // `pack`: the quantity is in whole cartons of the product (received by the carton).
            'unit' => ['nullable', Rule::in([Pack::SALE_UNIT])],
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator) {
                if ($this->input('unit') !== Pack::SALE_UNIT || $validator->errors()->has('product_id')) {
                    return;
                }
                $product = Product::query()->forStore($this->user()->store_id)->find((int) $this->input('product_id'));
                if ($product && !$product->hasPack()) {
                    $validator->errors()->add('unit', 'هذا المنتج لا يُستلم بالكرتونة؛ أدخل الكمية بالقطعة.');
                }
            },
        ];
    }

    public function messages(): array
    {
        return [
            'unit.in' => 'وحدة الكمية غير صالحة.',
            'product_id.required' => 'يرجى تحديد المنتج.',
            'product_id.exists' => 'المنتج المحدد غير موجود.',
            'quantity.required' => 'يرجى إدخال كمية التعديل.',
            'quantity.numeric' => 'الكمية يجب أن تكون رقمًا',
            'quantity.integer' => 'الكمية يجب أن تكون عددًا صحيحًا',
            'quantity.decimal' => 'الوزن يقبل ثلاث خانات عشرية كحد أقصى',
            'quantity.min' => 'كمية التعديل خارج الحد المسموح.',
            'quantity.max' => 'كمية التعديل خارج الحد المسموح.',
            'reason.required' => 'يجب كتابة سبب تعديل المخزون.',
            'reason.max' => 'السبب طويل جدًا',
        ];
    }

    /** The unit of the product being adjusted; unknown products fail `exists` and default to pieces. */
    private function productUnit(): string
    {
        $productId = $this->input('product_id');

        $unit = is_numeric($productId)
            ? Product::query()->forStore($this->user()->store_id)->whereKey((int) $productId)->value('unit')
            : null;

        return $unit ?? Quantity::UNIT_PIECE;
    }
}
