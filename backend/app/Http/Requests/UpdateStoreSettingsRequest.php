<?php

namespace App\Http\Requests;

use App\Enums\UserRole;
use Illuminate\Foundation\Http\FormRequest;

class UpdateStoreSettingsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->hasRole(UserRole::OWNER);
    }

    public function rules(): array
    {
        return [
            // Each field is optional; the ones sent are validated and saved.
            'timezone' => ['sometimes', 'required', 'timezone:all'],
            // The name and phone printed on every receipt.
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'phone' => ['sometimes', 'nullable', 'string', 'regex:/^0\d{8,9}$/'],
            'address' => ['sometimes', 'nullable', 'string', 'max:255'],
            ...StoreLocation::rules(),
        ];
    }

    public function messages(): array
    {
        return [
            'timezone.required' => 'يرجى تحديد المنطقة الزمنية.',
            'timezone.timezone' => 'المنطقة الزمنية غير صحيحة.',
            'name.required' => 'اكتب اسم المتجر.',
            'name.max' => 'اسم المتجر طويل جداً.',
            'phone.regex' => 'رقم الهاتف 9 أو 10 أرقام ويبدأ بـ 0، مثل 0599123456.',
            ...StoreLocation::messages(),
        ];
    }
}
