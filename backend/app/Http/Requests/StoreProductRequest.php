<?php

namespace App\Http\Requests;

use App\Models\Product;
use App\Support\Money;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** US-0401 AC1–AC2. */
class StoreProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Product::class);
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
            'name' => ['required', 'string', 'max:255'],
            'barcode' => [
                'nullable',
                'string',
                'max:64',
                Rule::unique('products', 'barcode')->where(fn($query) => $query->where('store_id', $this->user()->store_id)),
            ],
            'selling_price' => ['required', ...Money::inputRules()],
            'cost_price' => ['nullable', 'numeric', 'decimal:0,2', 'min:0', 'max:' . Money::MAX],
            // CR-13: integer quantities only.
            'current_stock' => ['required', 'integer', 'min:0', 'max:1000000'],
            'minimum_stock' => ['sometimes', 'integer', 'min:0', 'max:1000000'],
        ];
    }

    public function messages(): array
    {
        return ProductMessages::all();
    }
}
