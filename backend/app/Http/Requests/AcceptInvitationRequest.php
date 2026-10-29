<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

/**
 * Staff joining by an invitation link: they sign in with their mobile number. The link itself
 * proves the invitation, so no SMS code is spent here.
 */
class AcceptInvitationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return !$this->user();
    }

    protected function prepareForValidation(): void
    {
        $this->merge(['phone' => SignInPhone::prepare($this->input('phone'))]);
    }

    public function rules(): array
    {
        return [
            'token' => ['required', 'string'],
            'name' => ['required', 'string', 'max:255'],
            'phone' => SignInPhone::rules(),
            'password' => ['required', 'confirmed', Password::defaults()],
        ];
    }

    public function messages(): array
    {
        return SignInPhone::messages('phone');
    }
}
