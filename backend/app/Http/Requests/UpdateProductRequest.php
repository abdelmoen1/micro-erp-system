<?php

namespace App\Http\Requests;

use App\Models\Product;
use App\Support\Barcode;
use App\Support\Money;
use App\Support\Pack;
use App\Support\Quantity;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

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
            $this->merge(['barcode' => Barcode::normalize($this->barcode)]);
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
            'unit' => ['sometimes', Rule::in(Quantity::UNITS)],
            'selling_price' => ['sometimes', 'required', ...Money::inputRules()],
            'cost_price' => ['sometimes', 'nullable', 'numeric', 'decimal:0,2', 'min:0', 'max:' . Money::MAX],
            'minimum_stock' => ['sometimes', ...ProductMessages::stockRules($this->targetUnit())],
            // FR-16 activate / deactivate.
            'status' => ['sometimes', Rule::in([Product::STATUS_ACTIVE, Product::STATUS_INACTIVE])],
            'current_stock' => ['prohibited'],
            'pack_size' => ['sometimes', ...Pack::rules()['pack_size']],
            'pack_price' => ['sometimes', ...Pack::rules()['pack_price']],
        ];
    }

    /**
     * CR-13: a weighed product whose stock has a fraction cannot become a piece product. The carton
     * is checked as it would be saved: what was sent, merged onto the stored product (so changing
     * the unit or the piece price alone cannot leave an ambiguous carton behind).
     */
    public function after(): array
    {
        return [
            function (Validator $validator) {
                $product = $this->route('product');

                if ($this->input('unit') === Quantity::UNIT_PIECE && !Quantity::isWhole($product->current_stock)) {
                    $validator->errors()->add('unit', 'لا يمكن تحويل المنتج إلى قطع لأن مخزونه الحالي يحتوي على كسور.');
                }

                $value = fn(string $field) => $this->exists($field) ? $this->input($field) : $product->{$field};
                $problems = Pack::problems($this->targetUnit(), $value('pack_size'), $value('pack_price'), $value('selling_price'));
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

    private function targetUnit(): string
    {
        $unit = $this->input('unit');

        return in_array($unit, Quantity::UNITS, true) ? $unit : $this->route('product')->unit;
    }
}
