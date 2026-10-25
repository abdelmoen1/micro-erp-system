<?php

namespace App\Support;

/**
 * Wholesale cartons: a piece product may also be sold or received by the carton, `pack_size`
 * pieces for `pack_price`. Stock always stays in pieces; a carton moves pack_size of them.
 *
 * One rule set for the product requests and the CSV import, so a carton is never ambiguous: both
 * fields or neither, pieces only, at least 2 per carton, and a carton dearer than one piece (a
 * carton price at or under one piece is the per-piece price typed in the wrong field).
 */
final class Pack
{
    public const MIN_SIZE = 2;

    public const MAX_SIZE = 10000;

    /** The value a sale line or an adjustment sends to mean "by the carton". */
    public const SALE_UNIT = 'pack';

    public static function rules(): array
    {
        return [
            'pack_size' => ['nullable', 'integer', 'min:' . self::MIN_SIZE, 'max:' . self::MAX_SIZE],
            'pack_price' => ['nullable', ...Money::inputRules()],
        ];
    }

    /**
     * Problems with the product's carton as it would be saved (after merging an update onto the
     * stored product). @return array<string, string> field => Arabic message
     */
    public static function problems(?string $unit, mixed $size, mixed $price, mixed $sellingPrice): array
    {
        $hasSize = !blank($size);
        $hasPrice = !blank($price);

        if (!$hasSize && !$hasPrice) {
            return [];
        }
        if ($unit === Quantity::UNIT_KG) {
            return ['pack_size' => 'الكرتونة للمنتجات المباعة بالقطعة فقط؛ المنتج الموزون يُباع بالكيلو.'];
        }
        if (!$hasSize) {
            return ['pack_size' => 'أدخل عدد القطع في الكرتونة مع سعرها.'];
        }
        if (!$hasPrice) {
            return ['pack_price' => 'أدخل سعر الكرتونة كاملة مع عدد قطعها.'];
        }
        if (is_numeric($price) && is_numeric($sellingPrice) && Money::compare((string) $price, (string) $sellingPrice) <= 0) {
            return ['pack_price' => 'سعر الكرتونة يجب أن يكون أعلى من سعر القطعة الواحدة. هل أدخلت سعر القطعة هنا؟'];
        }

        return [];
    }

    public static function messages(): array
    {
        return [
            'pack_size.integer' => 'عدد القطع في الكرتونة يجب أن يكون عددًا صحيحًا.',
            'pack_size.min' => 'الكرتونة تحتوي قطعتين على الأقل.',
            'pack_size.max' => 'عدد القطع في الكرتونة أكبر من الحد المسموح (' . self::MAX_SIZE . ').',
            'pack_price.numeric' => 'سعر الكرتونة يجب أن يكون رقمًا.',
            'pack_price.gt' => 'سعر الكرتونة يجب أن يكون أكبر من صفر.',
            'pack_price.decimal' => 'سعر الكرتونة يقبل خانتين عشريتين كحد أقصى.',
            'pack_price.max' => 'سعر الكرتونة أكبر من الحد المسموح.',
        ];
    }

    /** Base units moved by [quantity] sold or received in this line's unit. */
    public static function baseQuantity(string $quantity, ?int $packSize): string
    {
        return $packSize ? Quantity::of(bcmul(Quantity::of($quantity), (string) $packSize, Quantity::SCALE)) : Quantity::of($quantity);
    }
}
