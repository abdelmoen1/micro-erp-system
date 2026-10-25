<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

/** Platform admin: permanent store deletion, confirmed by typing the store's exact name. */
class DeleteStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return (bool) $this->user()?->isPlatformAdmin();
    }

    public function rules(): array
    {
        return [
            'confirm_name' => ['required', 'string', 'max:255'],
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator) {
                $typed = trim((string) $this->input('confirm_name'));
                if (!$validator->errors()->has('confirm_name') && $typed !== trim($this->route('store')->name)) {
                    $validator->errors()->add('confirm_name', 'اسم المتجر غير مطابق.');
                }
            },
        ];
    }

    public function messages(): array
    {
        return [
            'confirm_name.required' => 'اكتب اسم المتجر لتأكيد الحذف.',
        ];
    }
}
