<?php

namespace App\Http\Requests;

use App\Models\Invoice;
use App\Support\Money;
use App\Support\Pack;
use App\Support\Quantity;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/**
 * POST /sales (US-0501, US-0502; 05 §3.1). The client sends products and quantities, never prices:
 * any price field is ignored. Rules that need the products or the total (unit, walk-in, due date,
 * credit limit) are checked by SaleService under the row locks.
 */
class StoreSaleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Invoice::class);
    }

    public function rules(): array
    {
        return [
            'store_id' => ['prohibited'],
            'customer_id' => [
                'nullable',
                'integer',
                Rule::exists('customers', 'id')
                    ->where(fn($query) => $query->where('store_id', $this->user()->store_id)->whereNull('deleted_at')),
            ],
            'items' => ['required', 'array', 'min:1', 'max:200'],
            'items.*.product_id' => ['required', 'integer'],
            'items.*.quantity' => ['required', ...Quantity::inputRules(null)],
            // Absent: the product's own unit (piece / kg). `pack`: whole cartons at the carton price.
            'items.*.sale_unit' => ['nullable', Rule::in([Pack::SALE_UNIT])],
            'paid_amount' => ['required', 'numeric', 'decimal:0,2', 'min:0', 'max:' . Money::MAX],
            'payment_method' => ['nullable', 'string', Rule::in(PaymentMethods::ALL)],
            'due_date' => ['nullable', 'date_format:Y-m-d'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'confirm_over_limit' => ['sometimes', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'store_id.prohibited' => 'لا يُرسل المتجر في الطلب.',
            'customer_id.exists' => 'العميل غير موجود في متجرك.',
            'items.required' => 'يجب إضافة منتج واحد على الأقل.',
            'items.min' => 'يجب إضافة منتج واحد على الأقل.',
            'items.max' => 'عدد المنتجات في الفاتورة كبير جدًا.',
            'items.*.product_id.required' => 'يجب تحديد المنتج.',
            'items.*.product_id.distinct' => 'المنتج مكرر في الفاتورة؛ عدّل الكمية بدل التكرار.',
            'items.*.quantity.required' => 'يجب إدخال الكمية.',
            'items.*.quantity.numeric' => 'الكمية يجب أن تكون رقمًا.',
            'items.*.quantity.decimal' => 'الوزن يقبل ثلاث خانات عشرية كحد أقصى.',
            'items.*.quantity.gt' => 'الكمية يجب أن تكون أكبر من صفر.',
            'items.*.quantity.max' => 'الكمية أكبر من الحد المسموح.',
            'paid_amount.required' => 'يجب إدخال المبلغ المدفوع (0 للبيع بالدين).',
            'paid_amount.decimal' => 'المبلغ يقبل خانتين عشريتين كحد أقصى.',
            'paid_amount.min' => 'المبلغ المدفوع لا يمكن أن يكون سالبًا.',
            'payment_method.in' => 'طريقة الدفع غير صالحة.',
            'due_date.date_format' => 'صيغة تاريخ الاستحقاق يجب أن تكون YYYY-MM-DD.',
            'items.*.sale_unit.in' => 'وحدة البيع غير صالحة.',
        ];
    }

    /** One line per product and unit: pieces and cartons of one product are two lines, never two of the same. */
    public function after(): array
    {
        return [
            function (Validator $validator) {
                $seen = [];
                foreach ((array) $this->input('items', []) as $index => $item) {
                    if (!is_array($item) || !isset($item['product_id'])) {
                        continue;
                    }
                    $key = $item['product_id'] . '|' . ($item['sale_unit'] ?? '');
                    if (isset($seen[$key])) {
                        $validator->errors()->add("items.{$index}.product_id", 'المنتج مكرر في الفاتورة؛ عدّل الكمية بدل التكرار.');
                    }
                    $seen[$key] = true;
                }
            },
        ];
    }
}
