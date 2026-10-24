<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/** POST /sales/{id}/void (US-0503): Owner / Manager, reason required. */
class VoidSaleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('void', $this->route('invoice'));
    }

    public function rules(): array
    {
        return [
            'reason' => ['required', 'string', 'max:500'],
        ];
    }

    public function messages(): array
    {
        return [
            'reason.required' => 'يجب كتابة سبب إلغاء الفاتورة.',
            'reason.max' => 'السبب طويل جدًا.',
        ];
    }
}
