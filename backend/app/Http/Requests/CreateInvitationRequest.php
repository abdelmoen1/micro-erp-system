<?php

namespace App\Http\Requests;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CreateInvitationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('invite', User::class);
    }

    public function rules(): array
    {
        $allowedRoles = [UserRole::MANAGER->value, UserRole::EMPLOYEE->value];

        return [
            'role' => ['required', Rule::in($allowedRoles)],
            'expires_in_hours' => ['nullable', 'integer', 'min:1', 'max:168'],
        ];
    }
}
