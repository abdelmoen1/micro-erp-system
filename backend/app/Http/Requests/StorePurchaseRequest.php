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
 * Goods from a supplier. A line is an existing product (`product_id`, or a barcode the store knows)
 * or a new one (`name`, `unit`, `selling_price`). By the carton: `cartons` and `pack_size`, with
 * `buy_price` for a carton. By weight: `quantity` in kg, with `buy_price` for a kilo.
 */
class StorePurchaseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('adjustStock', Product::class);
    }

    protected function prepareForValidation(): void
    {
        $lines = $this->input('lines');
        if (!is_array($lines)) {
            return;
        }

        $this->merge(['lines' => array_map(
            fn($line) => is_array($line) && isset($line['barcode']) ? ['barcode' => Barcode::normalize($line['barcode'])] + $line : $line,
            $lines,
        )]);
    }

    public function rules(): array
    {
        $storeId = $this->user()->store_id;

        return [
            'supplier_id' => ['nullable', 'integer', Rule::exists('suppliers', 'id')->where('store_id', $storeId)],
            'supplier_name' => ['required_without:supplier_id', 'nullable', 'string', 'max:150'],
            'paid_amount' => ['nullable', 'numeric', 'decimal:0,2', 'min:0', 'max:' . Money::MAX],
            'method' => ['nullable', 'string', Rule::in(PaymentMethods::ALL)],
            'lines' => ['required', 'array', 'min:1', 'max:200'],
            'lines.*.product_id' => ['nullable', 'integer', Rule::exists('products', 'id')->where('store_id', $storeId)],
            'lines.*.name' => ['nullable', 'string', 'max:255'],
            'lines.*.barcode' => ['nullable', 'string', 'max:64'],
            'lines.*.unit' => ['nullable', Rule::in([Quantity::UNIT_PIECE, Quantity::UNIT_KG])],
            'lines.*.cartons' => ['nullable', 'integer', 'min:1', 'max:1000000'],
            'lines.*.pack_size' => ['nullable', 'integer', 'min:1', 'max:' . Pack::MAX_SIZE],
            'lines.*.quantity' => ['nullable', 'numeric', 'decimal:0,3', 'gt:0', 'max:999999'],
            'lines.*.buy_price' => ['required', ...Money::inputRules()],
            'lines.*.selling_price' => ['nullable', ...Money::inputRules()],
            'lines.*.carton_price' => ['nullable', ...Money::inputRules()],
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator) {
                if ($validator->errors()->isNotEmpty()) {
                    return;
                }
                foreach ($this->input('lines') as $index => $line) {
                    $this->checkLine($validator, $index, $line);
                }
            },
        ];
    }

    private function checkLine(Validator $validator, int $index, array $line): void
    {
        $product = $this->productOf($line);
        $unit = $product?->unit ?? $line['unit'] ?? Quantity::UNIT_PIECE;

        if (!$product) {
            if (blank($line['name'] ?? null)) {
                $validator->errors()->add("lines.$index.name", 'اكتب اسم الصنف.');
            }
            if (blank($line['selling_price'] ?? null)) {
                $validator->errors()->add("lines.$index.selling_price", 'اكتب سعر البيع.');
            }
            // A carton is always found by its barcode; a weighed item never has one.
            if ($unit === Quantity::UNIT_PIECE && blank($line['barcode'] ?? null)) {
                $validator->errors()->add("lines.$index.barcode", 'اكتب رقم الباركود.');
            }
            if ($unit === Quantity::UNIT_KG && !blank($line['barcode'] ?? null)) {
                $validator->errors()->add("lines.$index.barcode", 'الصنف بالوزن ليس له باركود.');
            }
        }
        if ($unit === Quantity::UNIT_KG) {
            if (blank($line['quantity'] ?? null)) {
                $validator->errors()->add("lines.$index.quantity", 'اكتب الكمية بالكيلو.');
            }
            return;
        }
        if (blank($line['cartons'] ?? null)) {
            $validator->errors()->add("lines.$index.cartons", 'اكتب عدد الكراتين.');
        }
        if (blank($line['pack_size'] ?? null) && blank($product?->pack_size)) {
            $validator->errors()->add("lines.$index.pack_size", 'اكتب عدد القطع بالكرتونة.');
        }
        $selling = $line['selling_price'] ?? $product?->selling_price;
        if (!blank($line['carton_price'] ?? null) && Money::compare($line['carton_price'], $selling) <= 0) {
            $validator->errors()->add("lines.$index.carton_price", 'سعر الكرتونة لازم يكون أعلى من سعر القطعة.');
        }
    }

    private function productOf(array $line): ?Product
    {
        $query = Product::query()->forStore($this->user()->store_id);
        $barcode = $line['barcode'] ?? null;

        return match (true) {
            !empty($line['product_id']) => $query->find($line['product_id']),
            !blank($barcode) => $query->where('barcode', $barcode)->first(),
            default => null,
        };
    }

    public function messages(): array
    {
        return [
            'supplier_name.required_without' => 'اكتب اسم المورد.',
            'supplier_name.max' => 'اسم المورد طويل.',
            'lines.required' => 'أضف صنفاً واحداً على الأقل.',
            'lines.min' => 'أضف صنفاً واحداً على الأقل.',
            'lines.*.buy_price.required' => 'اكتب سعر الشراء.',
            'lines.*.buy_price.gt' => 'اكتب سعر الشراء.',
            'paid_amount.min' => 'المدفوع لا يكون بالسالب.',
            'method.in' => 'طريقة الدفع غير صحيحة.',
        ];
    }
}
