<?php

namespace App\Http\Requests;

use App\Support\PhoneNumber;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

/** POST /auth/password/reset: a forgotten password, by the SMS code sent to the account's number. */
class ResetPasswordRequest extends FormRequest
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
            'phone' => ['required', 'string', 'regex:' . PhoneNumber::PATTERN],
            'otp_code' => ['required', 'digits:6'],
            'password' => ['required', 'string', 'confirmed', Password::defaults()],
        ];
    }

    public function messages(): array
    {
        return SignInPhone::messages('phone') + [
            'otp_code.required' => 'اكتب الرمز الذي وصلك برسالة.',
            'otp_code.digits' => 'الرمز 6 أرقام.',
            'password.required' => 'اكتب كلمة المرور الجديدة.',
            'password.confirmed' => 'تأكيد كلمة المرور لا يطابقها.',
            'password.min' => 'كلمة المرور 8 أحرف على الأقل.',
        ];
    }
}
