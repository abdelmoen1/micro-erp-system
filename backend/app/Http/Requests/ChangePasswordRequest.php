<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\Validator;

/** PATCH /me/password: the current password proves it is the account holder, not only a session. */
class ChangePasswordRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'current_password' => ['required', 'string'],
            'password' => ['required', 'string', 'confirmed', 'different:current_password', Password::defaults()],
        ];
    }

    public function messages(): array
    {
        return [
            'current_password.required' => 'اكتب كلمة المرور الحالية.',
            'password.required' => 'اكتب كلمة المرور الجديدة.',
            'password.confirmed' => 'تأكيد كلمة المرور لا يطابقها.',
            'password.different' => 'كلمة المرور الجديدة يجب أن تختلف عن الحالية.',
            'password.min' => 'كلمة المرور 8 أحرف على الأقل.',
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator) {
                if ($validator->errors()->has('current_password')) {
                    return;
                }
                $user = $this->user();
                // A Google-only account has no password to change; a session alone cannot set one.
                if ($user->password === null) {
                    $validator->errors()->add('current_password', 'حسابك يدخل بحساب Google، فليس له كلمة مرور لتغييرها.');
                } elseif (! Hash::check((string) $this->input('current_password'), $user->password)) {
                    $validator->errors()->add('current_password', 'كلمة المرور الحالية غير صحيحة.');
                }
            },
        ];
    }
}
