<?php

namespace App\Http\Requests;

use App\Support\Money;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateInvoiceRequest extends FormRequest
{
    public function authorize(): bool
    {
        // DEF-05 containment: employees can no longer rewrite sales (US-0105).
        return $this->user()->can('update', $this->route('invoice'));
    }

    public function rules(): array
    {
        return [
            'customer_id' => [
                'sometimes',
                'integer',
                Rule::exists('customers', 'id')->where(
                    fn($query) =>
                    $query->where('store_id', $this->user()->store_id)
                ),
            ],

            'has_debt' => [
                'sometimes',
                'boolean',
            ],

            'payment_method' => [
                'nullable',
                'string',
                Rule::in(PaymentMethods::ALL),
                'required_if:has_debt,false',
                'prohibited_if:has_debt,true',
            ],

            'items' => [
                'sometimes',
                'array',
                'min:1',
            ],

            'items.*.item_name' => [
                'required_with:items',
                'string',
                'max:255',
            ],

            'items.*.quantity' => [
                'required_with:items',
                'integer',
                'min:1',
            ],

            'items.*.unit_price' => ['required_with:items', ...Money::inputRules()],
        ];
    }
}
