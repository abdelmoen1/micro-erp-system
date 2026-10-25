<?php

namespace App\Http\Requests;

use App\Models\CatalogProduct;
use App\Models\Product;
use App\Support\Barcode;
use App\Support\Money;
use App\Support\Pack;
use App\Support\Quantity;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/** US-0401 AC1–AC2; CR-13: sold by the piece (whole quantities) or by the kg (up to 3 decimals). */
class StoreProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Product::class);
    }

    protected function prepareForValidation(): void
    {
        if (is_string($this->barcode)) {
            $barcode = Barcode::normalize($this->barcode);
            $this->merge(['barcode' => $barcode]);

            // Shared catalog: a known barcode brings its name and unit unless the store sent its own.
            $catalog = $barcode === null ? null : CatalogProduct::query()->where('barcode', $barcode)->first();
            if ($catalog) {
                $this->merge(array_filter([
                    'name' => blank($this->name) ? $catalog->name : null,
                    'unit' => blank($this->unit) ? $catalog->unit : null,
                ]));
            }
        }
    }

    public function rules(): array
    {
        $unit = in_array($this->input('unit'), Quantity::UNITS, true) ? $this->input('unit') : Quantity::UNIT_PIECE;

        return [
            'name' => ['required', 'string', 'max:255'],
            'barcode' => [
                'nullable',
                'string',
                'max:64',
                Rule::unique('products', 'barcode')->where(fn($query) => $query->where('store_id', $this->user()->store_id)),
            ],
            'unit' => ['sometimes', Rule::in(Quantity::UNITS)],
            'selling_price' => ['required', ...Money::inputRules()],
            'cost_price' => ['nullable', 'numeric', 'decimal:0,2', 'min:0', 'max:' . Money::MAX],
            'current_stock' => ['required', ...ProductMessages::stockRules($unit)],
            'minimum_stock' => ['sometimes', ...ProductMessages::stockRules($unit)],
            ...Pack::rules(),
        ];
    }

    /** The carton must be complete and unambiguous (App\Support\Pack). */
    public function after(): array
    {
        return [
            function (Validator $validator) {
                $problems = Pack::problems(
                    $this->input('unit', Quantity::UNIT_PIECE),
                    $this->input('pack_size'),
                    $this->input('pack_price'),
                    $this->input('selling_price'),
                );
                foreach ($problems as $field => $message) {
                    if (!$validator->errors()->has($field)) {
                        $validator->errors()->add($field, $message);
                    }
                }
            },
        ];
    }

    public function messages(): array
    {
        return ProductMessages::all() + Pack::messages();
    }
}
