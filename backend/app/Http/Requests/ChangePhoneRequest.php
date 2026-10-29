<?php

namespace App\Http\Requests;

use App\Services\OtpService;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/**
 * PATCH /me/phone: the number this account signs in with (accounts made with an e-mail add one
 * here). The current password guards it; with SMS codes on, the new number is confirmed too.
 */
class ChangePhoneRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $this->merge(['phone' => SignInPhone::prepare($this->input('phone'))]);
    }

    public function rules(): array
    {
        return [
            'phone' => SignInPhone::rules(ignoreUserId: $this->user()->id),
            // An account without a password (an old Google one) has none to give.
            'current_password' => [Rule::requiredIf(fn() => $this->user()->password !== null), 'nullable', 'string'],
            'otp_code' => [Rule::requiredIf(fn() => app(OtpService::class)->enabled()), 'nullable', 'digits:6'],
        ];
    }

    public function messages(): array
    {
        return SignInPhone::messages('phone') + [
            'current_password.required' => 'اكتب كلمة المرور الحالية.',
            'otp_code.required' => 'اكتب الرمز الذي وصلك برسالة.',
            'otp_code.digits' => 'الرمز 6 أرقام.',
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator) {
                $password = $this->user()->password;
                if ($password !== null && !$validator->errors()->has('current_password')
                    && !Hash::check((string) $this->input('current_password'), $password)) {
                    $validator->errors()->add('current_password', 'كلمة المرور الحالية غير صحيحة.');
                }
            },
        ];
    }
}
