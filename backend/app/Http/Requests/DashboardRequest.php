<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class DashboardRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'period' => [
                'sometimes',
                'string',
                Rule::in(['today', 'this_week', 'this_month', 'this_year']),
            ],
            'store_id' => ['prohibited'],
        ];
    }

    public function period(): string
    {
        return $this->validated('period', 'this_month');
    }
}
