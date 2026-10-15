<?php

namespace App\Http\Requests;

use App\Support\Money;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreInvoiceRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'customer_id' => [
                'required',
                Rule::exists('customers', 'id')->where(function ($query) {
                    $query->where('store_id', $this->user()->store_id)->whereNull('deleted_at');
                }),
            ],

            'has_debt' => [
                'required',
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
                'required',
                'array',
                'min:1',
            ],

            'items.*.item_name' => [
                'required',
                'string',
                'max:255',
            ],

            'items.*.quantity' => [
                'required',
                'integer',
                'min:1',
            ],

            'items.*.unit_price' => ['required', ...Money::inputRules()],
        ];
    }

    public function messages(): array
    {
        return [
            'customer_id.required' => 'يرجى اختيار العميل أولاً.',
            'customer_id.exists'   => 'العميل المحدد غير مسجل في النظام.',
            'has_debt.required'    => 'يرجى تحديد ما إذا كانت الفاتورة بالدين أم لا.',

            'items.required'       => 'قائمة الفاتورة فارغة، يرجى إضافة منتج واحد على الأقل.',
            'items.min'            => 'يرجى إضافة منتج واحد على الأقل لإتمام الفاتورة.',

            'items.*.item_name.required'  => 'يرجى إدخال اسم المنتج.',
            'items.*.item_name.max'       => 'اسم المنتج طويل جداً، يرجى اختصاره.',

            'items.*.quantity.required'   => 'يرجى تحديد الكمية المطلوبة.',
            'items.*.quantity.integer'    => 'الكمية يجب أن تكون عدداً صحيحاً.',
            'items.*.quantity.min'        => 'أقل كمية يمكن طلبها هي قطعة واحدة.',

            'items.*.unit_price.required' => 'يرجى تحديد سعر المنتج.',
            'items.*.unit_price.numeric'  => 'السعر يجب أن يكون قيمة مالية صحيحة.',
            'items.*.unit_price.gt'       => 'سعر المنتج لا يمكن أن يكون مجانياً أو بالسالب.',
            'items.*.unit_price.decimal'  => 'السعر يجب ألا يتجاوز منزلتين عشريتين.',
        ];
    }
}
