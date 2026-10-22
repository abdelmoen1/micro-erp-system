<?php

namespace App\Http\Requests;

use App\Models\Payment;
use App\Support\Money;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PayAllDebtsRequest extends FormRequest
{
    /** D-12: any role may record a customer's full repayment. */
    public function authorize(): bool
    {
        return $this->user()->can('payAll', Payment::class);
    }

    public function rules(): array
    {
        return [
            // US-0705 AC2: optional custom amount; without it the whole balance is paid.
            'amount' => ['nullable', ...Money::inputRules()],
            'method' => ['required', 'string', Rule::in(PaymentMethods::ALL)],
            'paid_at' => ['nullable', 'date'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function messages(): array
    {
        return [
            'amount.numeric' => 'المبلغ يجب أن يكون رقمًا.',
            'amount.decimal' => 'المبلغ يقبل خانتين عشريتين على الأكثر.',
            'amount.gt' => 'المبلغ يجب أن يكون أكبر من صفر.',
            'amount.max' => 'المبلغ أكبر من المسموح.',
            'method.required' => 'يرجى تحديد طريقة الدفع.',
            'method.in' => 'طريقة الدفع المحددة غير صحيحة.',
            'paid_at.date' => 'تاريخ الدفع غير صحيح.',
            'notes.string' => 'الملاحظات يجب أن تكون نصًا.',
        ];
    }
}
