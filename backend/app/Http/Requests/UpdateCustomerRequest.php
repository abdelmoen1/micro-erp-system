<?php

namespace App\Http\Requests;

use App\Models\Customer;
use App\Support\Money;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        // US-0305 AC1: every role edits customers; only Owner / Manager change the credit limit.
        return !$this->has('credit_limit') || $this->user()->can('setCreditLimit', Customer::class);
    }

    public function rules(): array
    {
        return [
            'name' => 'sometimes|string|max:255',
            'phone' => [
                'sometimes',
                'string',
                'max:10',
                Rule::unique('customers', 'phone')
                    ->where(fn($query) => $query->where('store_id', $this->user()->store_id))
                    ->ignore($this->route('customer')),
            ],
            'address' => 'sometimes|nullable|string|max:500',
            'notes' => 'sometimes|nullable|string',
            // null removes the limit (AC2).
            'credit_limit' => ['sometimes', 'nullable', 'numeric', 'decimal:0,2', 'min:0', 'max:' . Money::MAX],
        ];
    }

    public function messages(): array
    {
        return [
            'name.max' => 'اسم العميل يجب ألا يزيد عن 255 حرف',
            'phone.string' => 'رقم الهاتف يجب أن يكون نصًا',
            'phone.max' => 'رقم الهاتف طويل جدًا',
            'phone.unique' => 'رقم الهاتف مستخدم مسبقًا لعميل آخر',
            'address.string' => 'العنوان يجب أن يكون نصًا',
            ...CustomerCreditLimitMessages::all(),
        ];
    }
}
