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
            'due_date' => ['nullable', 'date_format:Y-m-d'],
            // A legacy debt: the day it started, never in the future, and a short note on where it came from.
            'originated_on' => ['nullable', 'date_format:Y-m-d', 'before_or_equal:today'],
            'note' => ['nullable', 'string', 'max:255'],
        ];
    }

    public function messages(): array
    {
        return [
            'customer_id.required' => 'اختر الزبون.',
            'customer_id.exists' => 'الزبون غير موجود في محلك.',
            'amount.required' => 'يجب إدخال قيمة الدين.',
            'amount.numeric' => 'قيمة الدين يجب أن تكون رقمية.',
            'amount.decimal' => 'قيمة الدين يجب ألا تتجاوز منزلتين عشريتين.',
            'amount.gt' => 'قيمة الدين يجب أن تكون أكبر من صفر.',
            'due_date.date_format' => 'صيغة تاريخ الاستحقاق يجب أن تكون YYYY-MM-DD.',
            'amount.max' => 'قيمة الدين أكبر من الحد المسموح.',
            'originated_on.date_format' => 'صيغة تاريخ الدين يجب أن تكون YYYY-MM-DD.',
            'originated_on.before_or_equal' => 'تاريخ الدين لا يكون بعد اليوم.',
            'note.max' => 'الملاحظة طويلة، 255 حرفاً كحد أقصى.',
        ];
    }
}
