<?php

namespace App\Http\Requests;

use App\Models\Customer;
use App\Support\Money;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreCustomerRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        // US-0305 AC1: every role creates customers; only Owner / Manager set a credit limit.
        return !$this->has('credit_limit') || $this->user()->can('setCreditLimit', Customer::class);
    }

    /**
     * Get the validation rules that apply to the request.
     */
    public function rules(): array
    {
        return [
            'name' => 'required|string|max:255',
            'phone' => [
                'required',
                'string',
                'max:10',
                'min:10',
                Rule::unique('customers', 'phone')->where(
                    fn($query) => $query->where('store_id', $this->user()->store_id)
                ),
            ],
            'address' => 'nullable|string|max:500',
            'notes' => 'nullable|string',
            'credit_limit' => ['nullable', 'numeric', 'decimal:0,2', 'min:0', 'max:' . Money::MAX],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => 'اسم العميل مطلوب',
            'name.max' => 'اسم العميل يجب ألا يزيد عن 255 حرف',
            'phone.required' => 'رقم الهاتف مطلوب',
            'phone.unique' => 'رقم الهاتف مستخدم مسبقًا لعميل آخر',
            'address.string' => 'العنوان يجب أن يكون نصًا',
            ...CustomerCreditLimitMessages::all(),
        ];
    }
}
