<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/** Onboarding after Google sign-in: the account comes from the onboarding token, the rest from the form. */
class GoogleRegisterStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return !$this->user();
    }

    /** The owner's phone is optional here (Google is the sign-in) but still one account per number. */
    protected function prepareForValidation(): void
    {
        $this->merge(['owner_phone' => SignInPhone::prepare($this->input('owner_phone'))]);
    }

    public function rules(): array
    {
        return [
            'onboarding_token' => ['required', 'string', 'max:4096'],
            'store_name' => ['required', 'string', 'max:255'],
            'owner_name' => ['required', 'string', 'max:255'],
            'owner_phone' => SignInPhone::rules(required: false),
            'phone' => ['nullable', 'string', 'max:10'],
            'address' => ['nullable', 'string', 'max:255'],
            ...StoreLocation::rules(),
            'timezone' => ['nullable', 'timezone:all'],
        ];
    }

    public function messages(): array
    {
        return StoreLocation::messages() + SignInPhone::messages('owner_phone');
    }
}
