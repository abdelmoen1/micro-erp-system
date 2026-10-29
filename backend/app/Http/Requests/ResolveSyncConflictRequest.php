<?php

namespace App\Http\Requests;

use App\Models\SyncConflict;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** POST /sync/conflicts/{conflict}/resolve (US-1106): Owner / Manager; a void needs a reason. */
class ResolveSyncConflictRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('resolve', $this->route('conflict'));
    }

    public function rules(): array
    {
        return [
            'resolution' => ['required', Rule::in([
                SyncConflict::RESOLUTION_ACKNOWLEDGED,
                SyncConflict::RESOLUTION_APPLIED,
                SyncConflict::RESOLUTION_REFUNDED,
                SyncConflict::RESOLUTION_VOIDED,
            ])],
            'note' => ['nullable', 'required_if:resolution,' . SyncConflict::RESOLUTION_VOIDED, 'string', 'max:500'],
        ];
    }

    public function messages(): array
    {
        return [
            'resolution.required' => 'يجب اختيار طريقة المعالجة.',
            'resolution.in' => 'طريقة المعالجة غير صالحة.',
            'note.required_if' => 'يجب كتابة سبب الإلغاء.',
            'note.max' => 'الملاحظة طويلة جدًا.',
        ];
    }
}
