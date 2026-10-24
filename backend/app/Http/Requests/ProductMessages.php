<?php

namespace App\Http\Requests;

use App\Support\Quantity;

/** Arabic validation messages shared by the product requests. */
final class ProductMessages
{
    /** CR-13: a stock level in the product's unit (whole for pieces, up to 3 decimals for kg). */
    public static function stockRules(string $unit): array
    {
        return [
            'numeric',
            $unit === Quantity::UNIT_KG ? 'decimal:0,3' : 'integer',
            'min:0',
            'max:' . Quantity::MAX,
        ];
    }

    public static function all(): array
    {
        return [
            'name.required' => 'اسم المنتج مطلوب',
            'name.max' => 'اسم المنتج يجب ألا يزيد عن 255 حرفًا',
            'barcode.unique' => 'الباركود مستخدم لمنتج آخر في متجرك',
            'barcode.max' => 'الباركود يجب ألا يزيد عن 64 حرفًا',
            'unit.in' => 'وحدة البيع يجب أن تكون قطعة أو كيلوغرام',
            'selling_price.required' => 'سعر البيع مطلوب',
            'selling_price.gt' => 'سعر البيع يجب أن يكون أكبر من صفر',
            'selling_price.decimal' => 'سعر البيع يقبل خانتين عشريتين كحد أقصى',
            'cost_price.min' => 'سعر التكلفة لا يمكن أن يكون سالبًا',
            'current_stock.required' => 'الكمية الافتتاحية مطلوبة',
            'current_stock.numeric' => 'الكمية يجب أن تكون رقمًا',
            'current_stock.integer' => 'الكمية يجب أن تكون عددًا صحيحًا',
            'current_stock.decimal' => 'الوزن يقبل ثلاث خانات عشرية كحد أقصى',
            'current_stock.min' => 'الكمية لا يمكن أن تكون سالبة',
            'current_stock.prohibited' => 'لا يمكن تعديل المخزون مباشرة؛ استخدم تعديل المخزون',
            'minimum_stock.numeric' => 'حد التنبيه يجب أن يكون رقمًا',
            'minimum_stock.integer' => 'حد التنبيه يجب أن يكون عددًا صحيحًا',
            'minimum_stock.decimal' => 'حد التنبيه يقبل ثلاث خانات عشرية كحد أقصى',
            'minimum_stock.min' => 'حد التنبيه لا يمكن أن يكون سالبًا',
            'status.in' => 'حالة المنتج غير صالحة',
        ];
    }
}
