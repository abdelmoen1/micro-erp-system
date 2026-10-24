<?php

namespace App\Http\Requests;

use App\Models\Store;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Platform admin: activate a subscription by hand after verifying a payment, or deactivate it.
 * `expires_at` is optional (open-ended) and must be in the future.
 */
class UpdateStoreSubscriptionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return (bool) $this->user()?->isPlatformAdmin();
    }

    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in([Store::SUBSCRIPTION_ACTIVE, Store::SUBSCRIPTION_INACTIVE])],
            'expires_at' => ['nullable', 'date', 'after:now', Rule::prohibitedIf($this->input('status') === Store::SUBSCRIPTION_INACTIVE)],
            'note' => ['nullable', 'string', 'max:500'],
        ];
    }

    public function messages(): array
    {
        return [
            'status.required' => 'يرجى تحديد حالة الاشتراك.',
            'status.in' => 'حالة الاشتراك غير صحيحة.',
            'expires_at.date' => 'تاريخ الانتهاء غير صحيح.',
            'expires_at.after' => 'تاريخ الانتهاء يجب أن يكون في المستقبل.',
            'expires_at.prohibited' => 'لا يُحدَّد تاريخ انتهاء عند إيقاف الاشتراك.',
            'note.max' => 'الملاحظة طويلة جداً (500 حرف كحد أقصى).',
        ];
    }
}
