<?php

namespace App\Http\Requests;

use App\Support\PhoneNumber;
use Illuminate\Validation\Rule;

/**
 * The sign-in phone of a new or changed account: normalised to `05XXXXXXXX` before validation,
 * one account per number, with the same Arabic messages on every form.
 */
final class SignInPhone
{
    /** The normalised value to merge before validation; the raw text when it is not a number. */
    public static function prepare(mixed $value): mixed
    {
        return is_string($value) && trim($value) !== '' ? (PhoneNumber::normalize($value) ?? $value) : $value;
    }

    public static function rules(bool $required = true, ?int $ignoreUserId = null): array
    {
        return [
            $required ? 'required' : 'nullable',
            'string',
            'regex:' . PhoneNumber::PATTERN,
            Rule::unique('users', 'phone')->ignore($ignoreUserId),
        ];
    }

    /** @return array<string, string> */
    public static function messages(string $field): array
    {
        return [
            "{$field}.required" => 'اكتب رقم الجوال.',
            "{$field}.regex" => 'رقم الجوال غير صحيح. اكتبه هكذا: 0599123456',
            "{$field}.unique" => 'هذا الرقم مسجّل لحساب آخر. سجّل الدخول به، أو استعمل «نسيت كلمة المرور».',
        ];
    }
}
