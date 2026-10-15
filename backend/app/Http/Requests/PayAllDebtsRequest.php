<?php

namespace App\Http\Requests;

use App\Models\Payment;
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
            'method' => ['required', 'string', Rule::in(PaymentMethods::ALL)],
            'paid_at' => ['nullable', 'date'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function messages(): array
    {
        return [
            'method.required' => 'يرجى تحديد طريقة الدفع.',
            'method.in' => 'طريقة الدفع المحددة غير صحيحة.',
            'paid_at.date' => 'تاريخ الدفع غير صحيح.',
            'notes.string' => 'الملاحظات يجب أن تكون نصًا.',
        ];
    }
}
