<?php

namespace App\Http\Requests;

use App\Services\OtpService;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

/**
 * A new store and its owner. The owner signs in with the mobile number (one account per number);
 * the e-mail is optional. With SMS codes on, the number is confirmed by the code it received.
 */
class RegisterStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return !$this->user();
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'owner_phone' => SignInPhone::prepare($this->input('owner_phone')),
            'email' => $this->filled('email') ? $this->input('email') : null,
        ]);
    }

    public function rules(): array
    {
        return [
            'store_name' => ['required', 'string', 'max:255'],
            'owner_name' => ['required', 'string', 'max:255'],
            'owner_phone' => SignInPhone::rules(),
            'phone' => ['nullable', 'string', 'max:10'],
            'address' => ['nullable', 'string', 'max:255'],
            ...StoreLocation::rules(),
            'timezone' => ['nullable', 'timezone:all'],
            'email' => ['nullable', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::defaults()],
            'otp_code' => [Rule::requiredIf(fn() => app(OtpService::class)->enabled()), 'nullable', 'digits:6'],
        ];
    }

    public function messages(): array
    {
        return StoreLocation::messages() + SignInPhone::messages('owner_phone') + [
            'otp_code.required' => 'اكتب الرمز الذي وصلك برسالة.',
            'otp_code.digits' => 'الرمز 6 أرقام.',
        ];
    }
}
