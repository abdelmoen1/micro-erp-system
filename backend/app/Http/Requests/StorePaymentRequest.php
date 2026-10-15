<?php

namespace App\Http\Requests;

use App\Models\Payment;
use App\Support\Money;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePaymentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Payment::class);
    }

    public function rules(): array
    {
        return [
            'debt_id' => [
                'required',
                Rule::exists('debts', 'id')->where(function ($query) {
                    $query->where('store_id', $this->user()->store_id)->whereNull('deleted_at');
                }),
            ],
            'amount' => ['required', ...Money::inputRules()],
            'method' => ['required', 'string', Rule::in(PaymentMethods::ALL)],
            'paid_at' => ['nullable', 'date'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function messages(): array
    {
        return [
            'debt_id.required' => 'يرجى تحديد الدين أولاً.',
            'debt_id.exists' => 'الدين المحدد غير موجود.',
            'amount.required' => 'يرجى إدخال مبلغ الدفعة.',
            'amount.numeric' => 'مبلغ الدفعة يجب أن يكون رقمًا.',
            'amount.decimal' => 'مبلغ الدفعة يجب ألا يتجاوز منزلتين عشريتين.',
            'amount.gt' => 'مبلغ الدفعة يجب أن يكون أكبر من صفر.',
            'amount.max' => 'مبلغ الدفعة أكبر من الحد المسموح.',
            'method.required' => 'يرجى تحديد طريقة الدفع.',
            'method.in' => 'طريقة الدفع المحددة غير صحيحة.',
            'paid_at.date' => 'تاريخ الدفع غير صحيح.',
            'notes.string' => 'الملاحظات يجب أن تكون نصًا.',
        ];
    }
}
