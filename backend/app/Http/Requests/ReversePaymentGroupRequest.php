<?php

namespace App\Http\Requests;

use App\Models\Payment;
use Illuminate\Foundation\Http\FormRequest;

class ReversePaymentGroupRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('reverse', Payment::class);
    }

    public function rules(): array
    {
        return [
            'reason' => ['required', 'string', 'max:500'],
        ];
    }

    public function messages(): array
    {
        return [
            'reason.required' => 'يرجى إدخال سبب إلغاء عملية السداد.',
            'reason.string' => 'سبب الإلغاء يجب أن يكون نصًا.',
            'reason.max' => 'سبب الإلغاء طويل جدًا.',
        ];
    }
}
