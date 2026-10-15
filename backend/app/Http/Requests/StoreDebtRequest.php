<?php

namespace App\Http\Requests;

use App\Models\Debt;
use App\Support\Money;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreDebtRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Debt::class);
    }

    public function rules(): array
    {
        return [
            'customer_id' => [
                'required',
                Rule::exists('customers', 'id')
                    ->where(fn($query) => $query->where('store_id', $this->user()->store_id)->whereNull('deleted_at')),
            ],
            'amount' => ['required', ...Money::inputRules()],
        ];
    }

    public function messages(): array
    {
        return [
            'customer_id.required' => 'يجب اختيار العميل.',
            'customer_id.exists' => 'العميل غير موجود في متجرك.',
            'amount.required' => 'يجب إدخال قيمة الدين.',
            'amount.numeric' => 'قيمة الدين يجب أن تكون رقمية.',
            'amount.decimal' => 'قيمة الدين يجب ألا تتجاوز منزلتين عشريتين.',
            'amount.gt' => 'قيمة الدين يجب أن تكون أكبر من صفر.',
            'amount.max' => 'قيمة الدين أكبر من الحد المسموح.',
        ];
    }
}
