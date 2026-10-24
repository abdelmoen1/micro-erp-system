<?php

namespace App\Http\Requests;

use App\Exceptions\ApiException;
use Illuminate\Foundation\Http\FormRequest;

/**
 * PATCH /sales/{id} (US-0503, D-06): an invoice is final at creation; only `notes` change.
 * Every financial field is rejected with 422 INVOICE_IMMUTABLE (after the role check, so an
 * employee still gets 403).
 */
class UpdateInvoiceRequest extends FormRequest
{
    /** Fields that would rewrite a recorded sale (DEF-05, DEF-06, DEF-11). */
    public const FINANCIAL_FIELDS = [
        'customer_id',
        'items',
        'total_amount',
        'paid_amount',
        'has_debt',
        'payment_method',
        'status',
        'source',
        'due_date',
    ];

    public function authorize(): bool
    {
        // DEF-05 containment: employees can no longer change sales (US-0105).
        return $this->user()->can('update', $this->route('invoice'));
    }

    public function rules(): array
    {
        return [
            'notes' => ['present', 'nullable', 'string', 'max:1000'],
        ];
    }

    public function after(): array
    {
        return [
            function () {
                $attempted = array_values(array_intersect(self::FINANCIAL_FIELDS, array_keys($this->all())));

                if ($attempted !== []) {
                    throw ApiException::businessRule(
                        'INVOICE_IMMUTABLE',
                        'الفاتورة نهائية بعد إنشائها. للتصحيح ألغِ الفاتورة أو أنشئ مرتجعًا.',
                        array_fill_keys($attempted, ['لا يمكن تعديل هذا الحقل بعد إنشاء الفاتورة.']),
                    );
                }
            },
        ];
    }

    public function messages(): array
    {
        return [
            'notes.present' => 'يمكن تعديل الملاحظات فقط.',
            'notes.max' => 'الملاحظات طويلة جدًا.',
        ];
    }
}
