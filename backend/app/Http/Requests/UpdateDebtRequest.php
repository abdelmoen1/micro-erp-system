<?php

namespace App\Http\Requests;

use App\Support\Money;
use Illuminate\Foundation\Http\FormRequest;

class UpdateDebtRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('update', $this->route('debt'));
    }

    public function rules(): array
    {
        return [
            'amount' => ['sometimes', ...Money::inputRules()],
        ];
    }

    public function messages(): array
    {
        return [
            'amount.decimal' => 'قيمة الدين يجب ألا تتجاوز منزلتين عشريتين.',
            'amount.gt' => 'قيمة الدين يجب أن تكون أكبر من صفر.',
        ];
    }
}
