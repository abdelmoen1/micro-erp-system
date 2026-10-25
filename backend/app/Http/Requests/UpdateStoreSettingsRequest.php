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
            'address' => ['sometimes', 'nullable', 'string', 'max:255'],
            ...StoreLocation::rules(),
        ];
    }

    public function messages(): array
    {
        return [
            'timezone.required' => 'يرجى تحديد المنطقة الزمنية.',
            'timezone.timezone' => 'المنطقة الزمنية غير صحيحة.',
            ...StoreLocation::messages(),
        ];
    }
}
