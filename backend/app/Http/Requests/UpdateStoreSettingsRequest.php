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
            'timezone' => ['required', 'timezone:all'],
        ];
    }

    public function messages(): array
    {
        return [
            'timezone.required' => 'يرجى تحديد المنطقة الزمنية.',
            'timezone.timezone' => 'المنطقة الزمنية غير صحيحة.',
        ];
    }
}
