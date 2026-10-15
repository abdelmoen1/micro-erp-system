<?php

namespace App\Http\Requests;

use App\Enums\UserRole;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateUserRoleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // UserPolicy::updateRole is checked in the controller.
    }

    public function rules(): array
    {
        // DEF-04: the owner role can never be assigned through the API.
        return [
            'role' => ['required', Rule::in([UserRole::MANAGER->value, UserRole::EMPLOYEE->value])],
        ];
    }

    public function messages(): array
    {
        return [
            'role.required' => 'يرجى تحديد الدور.',
            'role.in' => 'الدور المحدد غير مسموح.',
        ];
    }
}
