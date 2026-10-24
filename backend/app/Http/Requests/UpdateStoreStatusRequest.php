<?php

namespace App\Http\Requests;

use App\Models\Store;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** Platform admin: open or suspend a store's account access (not its subscription). */
class UpdateStoreStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return (bool) $this->user()?->isPlatformAdmin();
    }

    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in([Store::STATUS_ACTIVE, Store::STATUS_SUSPENDED])],
            'reason' => ['nullable', 'string', 'max:500'],
        ];
    }

    public function messages(): array
    {
        return [
            'status.required' => 'يرجى تحديد حالة الحساب.',
            'status.in' => 'حالة الحساب غير صحيحة.',
            'reason.max' => 'السبب طويل جداً (500 حرف كحد أقصى).',
        ];
    }
}
