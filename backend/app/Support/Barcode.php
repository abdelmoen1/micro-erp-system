<?php

namespace App\Support;

/**
 * One spelling per barcode, so the same item matches everywhere (store products and the shared
 * catalog). Arabic-Indic digits become ASCII, whitespace goes, letters are upper-cased, and the
 * GTIN forms of one item collapse to GTIN-13: a 12-digit UPC-A gets its leading 0 and a GTIN-14
 * with a leading 0 (GS1 `(01)` / Digital Link) loses it.
 */
final class Barcode
{
    public static function normalize(?string $raw): ?string
    {
        if ($raw === null) {
            return null;
        }

        $code = strtr($raw, [
            '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4',
            '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
            '۰' => '0', '۱' => '1', '۲' => '2', '۳' => '3', '۴' => '4',
            '۵' => '5', '۶' => '6', '۷' => '7', '۸' => '8', '۹' => '9',
        ]);
        $code = strtoupper(preg_replace('/\s+/u', '', $code));

        if (ctype_digit($code)) {
            if (strlen($code) === 12) {
                $code = '0' . $code;
            } elseif (strlen($code) === 14 && $code[0] === '0') {
                $code = substr($code, 1);
            }
        }

        return $code === '' ? null : $code;
    }

    /**
     * Only real, globally assigned GTINs enter the shared catalog: 8, 13 or 14 digits with a valid
     * check digit, and not a restricted-circulation code (in-store / variable-weight 02x, 04x, 2xx;
     * coupons 98x–99x; GTIN-8 0 and 2), which every shop reuses for its own items.
     * Other codes still work as store barcodes, they are just not shared.
     */
    public static function isGlobal(?string $code): bool
    {
        if ($code === null || !ctype_digit($code) || !in_array(strlen($code), [8, 13, 14], true)) {
            return false;
        }

        // A GTIN-14's first digit is its packaging indicator; the company prefix follows it.
        $prefix = strlen($code) === 14 ? substr($code, 1) : $code;
        if (strlen($code) === 8 ? in_array($code[0], ['0', '2'], true) : preg_match('/^(0[24]|2|9[89])/', $prefix)) {
            return false;
        }

        $sum = 0;
        $digits = strrev(substr($code, 0, -1));
        for ($i = 0; $i < strlen($digits); $i++) {
            $sum += (int) $digits[$i] * ($i % 2 === 0 ? 3 : 1);
        }

        return (10 - $sum % 10) % 10 === (int) substr($code, -1);
    }
}
