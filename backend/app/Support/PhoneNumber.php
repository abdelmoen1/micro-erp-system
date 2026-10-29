<?php

namespace App\Support;

/**
 * A mobile number used to sign in. Stored in one local form, `05XXXXXXXX`, whatever the person
 * typed (spaces, dashes, Arabic-Indic digits, +970 / 00970 / +972). Jawwal (059) and Ooredoo (056)
 * are Palestinian (+970); other 05 numbers are Israeli networks (+972), used in Jerusalem and the
 * West Bank.
 */
final class PhoneNumber
{
    public const PATTERN = '/^05\d{8}$/';

    /** The local form, or null when the text is not a mobile number. */
    public static function normalize(?string $input): ?string
    {
        if ($input === null) {
            return null;
        }

        $digits = strtr(trim($input), [
            '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4',
            '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
            '۰' => '0', '۱' => '1', '۲' => '2', '۳' => '3', '۴' => '4',
            '۵' => '5', '۶' => '6', '۷' => '7', '۸' => '8', '۹' => '9',
        ]);
        $digits = preg_replace('/[\s\-().]/u', '', $digits);
        $digits = preg_replace('/^(\+|00)/', '', $digits);
        $digits = preg_replace('/^(970|972)0?(5\d{8})$/', '0$2', $digits);

        return preg_match(self::PATTERN, $digits) ? $digits : null;
    }

    /** E.164 for the SMS gateway: +970 for Jawwal / Ooredoo, +972 otherwise. */
    public static function international(string $local): string
    {
        $country = in_array(substr($local, 0, 3), ['059', '056'], true) ? '970' : '972';

        return '+' . $country . substr($local, 1);
    }

    /** `059•••••56` for messages and logs. */
    public static function masked(string $local): string
    {
        return substr($local, 0, 3) . '•••••' . substr($local, -2);
    }
}
