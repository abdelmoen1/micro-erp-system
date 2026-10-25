<?php

namespace App\Http\Requests;

/**
 * Store location fields shared by registration and the owner's store settings: the area
 * (city / governorate) and optional map coordinates, which come as a pair or not at all.
 */
final class StoreLocation
{
    public static function rules(): array
    {
        return [
            'area' => ['nullable', 'string', 'max:100'],
            'latitude' => ['nullable', 'required_with:longitude', 'numeric', 'between:-90,90', 'decimal:0,6'],
            'longitude' => ['nullable', 'required_with:latitude', 'numeric', 'between:-180,180', 'decimal:0,6'],
        ];
    }

    public static function messages(): array
    {
        return [
            'area.max' => 'اسم المنطقة طويل جداً (100 حرف كحد أقصى).',
            'latitude.required_with' => 'أدخل خط العرض مع خط الطول.',
            'longitude.required_with' => 'أدخل خط الطول مع خط العرض.',
            'latitude.numeric' => 'خط العرض يجب أن يكون رقماً.',
            'longitude.numeric' => 'خط الطول يجب أن يكون رقماً.',
            'latitude.between' => 'خط العرض يجب أن يكون بين ‎-90 و 90.',
            'longitude.between' => 'خط الطول يجب أن يكون بين ‎-180 و 180.',
            'latitude.decimal' => 'خط العرض: 6 منازل عشرية كحد أقصى.',
            'longitude.decimal' => 'خط الطول: 6 منازل عشرية كحد أقصى.',
        ];
    }
}
