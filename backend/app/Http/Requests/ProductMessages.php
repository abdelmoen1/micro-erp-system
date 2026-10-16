<?php

namespace App\Http\Requests;

/** Arabic validation messages shared by the product requests. */
final class ProductMessages
{
    public static function all(): array
    {
        return [
            'name.required' => 'اسم المنتج مطلوب',
            'name.max' => 'اسم المنتج يجب ألا يزيد عن 255 حرفًا',
            'barcode.unique' => 'الباركود مستخدم لمنتج آخر في متجرك',
            'barcode.max' => 'الباركود يجب ألا يزيد عن 64 حرفًا',
            'selling_price.required' => 'سعر البيع مطلوب',
            'selling_price.gt' => 'سعر البيع يجب أن يكون أكبر من صفر',
            'selling_price.decimal' => 'سعر البيع يقبل خانتين عشريتين كحد أقصى',
            'cost_price.min' => 'سعر التكلفة لا يمكن أن يكون سالبًا',
            'current_stock.required' => 'الكمية الافتتاحية مطلوبة',
            'current_stock.integer' => 'الكمية يجب أن تكون عددًا صحيحًا',
            'current_stock.min' => 'الكمية لا يمكن أن تكون سالبة',
            'current_stock.prohibited' => 'لا يمكن تعديل المخزون مباشرة؛ استخدم تعديل المخزون',
            'minimum_stock.integer' => 'حد التنبيه يجب أن يكون عددًا صحيحًا',
            'minimum_stock.min' => 'حد التنبيه لا يمكن أن يكون سالبًا',
            'status.in' => 'حالة المنتج غير صالحة',
        ];
    }
}
