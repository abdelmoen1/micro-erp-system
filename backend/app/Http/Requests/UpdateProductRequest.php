<?php

namespace App\Http\Requests;

use App\Models\Product;
use App\Support\Money;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * US-0401: product details. Stock is not editable here: it changes only through stock movements
 * (adjustments are US-0402), so `current_stock` is not accepted.
 */
class UpdateProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('update', $this->route('product'));
    }

    protected function prepareForValidation(): void
    {
        if (is_string($this->barcode)) {
            $barcode = trim($this->barcode);
            $this->merge(['barcode' => $barcode === '' ? null : $barcode]);
        }
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'barcode' => [
                'sometimes',
                'nullable',
                'string',
                'max:64',
                Rule::unique('products', 'barcode')
                    ->where(fn($query) => $query->where('store_id', $this->user()->store_id))
                    ->ignore($this->route('product')->id),
            ],
            'selling_price' => ['sometimes', 'required', ...Money::inputRules()],
            'cost_price' => ['sometimes', 'nullable', 'numeric', 'decimal:0,2', 'min:0', 'max:' . Money::MAX],
            'minimum_stock' => ['sometimes', 'integer', 'min:0', 'max:1000000'],
            // FR-16 activate / deactivate.
            'status' => ['sometimes', Rule::in([Product::STATUS_ACTIVE, Product::STATUS_INACTIVE])],
            'current_stock' => ['prohibited'],
        ];
    }

    public function messages(): array
    {
        return ProductMessages::all();
    }
}
