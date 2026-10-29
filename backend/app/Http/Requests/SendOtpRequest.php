<?php

namespace App\Http\Requests;

use App\Models\PhoneOtp;
use App\Support\PhoneNumber;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** POST /auth/otp: a code for sign-up, a forgotten password, or the signed-in user's new number. */
class SendOtpRequest extends FormRequest
{
    /** A code for a new number is for the signed-in account only. */
    public function authorize(): bool
    {
        return $this->input('purpose') !== PhoneOtp::PURPOSE_CHANGE_PHONE || $this->user('sanctum') !== null;
    }

    protected function prepareForValidation(): void
    {
        $this->merge(['phone' => SignInPhone::prepare($this->input('phone'))]);
    }

    public function rules(): array
    {
        $purpose = $this->input('purpose');
        // Sign-up and a new number need a free number; a reset needs one that has an account.
        $phone = match ($purpose) {
            PhoneOtp::PURPOSE_RESET => ['required', 'string', 'regex:' . PhoneNumber::PATTERN],
            default => SignInPhone::rules(ignoreUserId: $this->user('sanctum')?->id),
        };

        return [
            'purpose' => ['required', Rule::in(PhoneOtp::PURPOSES)],
            'phone' => $phone,
        ];
    }

    public function messages(): array
    {
        return SignInPhone::messages('phone') + ['purpose.in' => 'نوع الرمز غير معروف.'];
    }
}
