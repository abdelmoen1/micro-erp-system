<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Models\Obligation;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** «الالتزامات»: the store's running costs, kept by the owner and managers (costs stay off staff phones). */
class ObligationController extends Controller
{
    public function index(Request $request)
    {
        $this->authorizeManage($request);

        $obligations = Obligation::query()->forStore($request->user()->store_id)
            ->orderByDesc('active')->orderBy('name')->get();

        return response()->json(['data' => $obligations->map(fn(Obligation $o) => $this->present($o))->values()]);
    }

    public function store(Request $request)
    {
        $this->authorizeManage($request);
        $data = $request->validate($this->rules(), $this->messages());

        $obligation = Obligation::create([
            'store_id' => $request->user()->store_id,
            'name' => trim($data['name']),
            'amount' => Money::of($data['amount']),
            'frequency' => $data['frequency'],
            'active' => $data['active'] ?? true,
            'created_by' => $request->user()->id,
            'updated_by' => $request->user()->id,
        ]);

        return response()->json(['message' => 'تمت إضافة الالتزام.', 'data' => $this->present($obligation)], 201);
    }

    public function update(Request $request, Obligation $obligation)
    {
        $this->authorizeManage($request);
        $data = $request->validate($this->rules(partial: true), $this->messages());

        if (isset($data['name'])) {
            $data['name'] = trim($data['name']);
        }
        if (isset($data['amount'])) {
            $data['amount'] = Money::of($data['amount']);
        }
        $obligation->update($data + ['updated_by' => $request->user()->id]);

        return response()->json(['message' => 'تم تحديث الالتزام.', 'data' => $this->present($obligation->fresh())]);
    }

    public function destroy(Request $request, Obligation $obligation)
    {
        $this->authorizeManage($request);
        $obligation->update(['active' => false, 'updated_by' => $request->user()->id]);
        $obligation->delete();

        return response()->json(['message' => 'تم حذف الالتزام.']);
    }

    private function rules(bool $partial = false): array
    {
        $required = $partial ? ['sometimes', 'required'] : ['required'];

        return [
            'name' => [...$required, 'string', 'max:120'],
            'amount' => [...$required, ...Money::inputRules()],
            'frequency' => [...$required, Rule::in(Obligation::FREQUENCIES)],
            'active' => ['sometimes', 'boolean'],
        ];
    }

    private function messages(): array
    {
        return [
            'name.required' => 'اكتب اسم الالتزام، مثل: إيجار المحل.',
            'name.max' => 'اسم الالتزام طويل جدًا.',
            'amount.required' => 'اكتب المبلغ.',
            'amount.numeric' => 'المبلغ يجب أن يكون رقمًا.',
            'amount.decimal' => 'المبلغ يقبل خانتين عشريتين على الأكثر.',
            'amount.gt' => 'المبلغ يجب أن يكون أكبر من صفر.',
            'amount.max' => 'المبلغ أكبر من المسموح.',
            'frequency.required' => 'اختر كل متى يُدفع.',
            'frequency.in' => 'اختر: يوميًا أو أسبوعيًا أو شهريًا أو سنويًا.',
        ];
    }

    private function present(Obligation $obligation): array
    {
        return [
            'id' => $obligation->id,
            'name' => $obligation->name,
            'amount' => Money::of($obligation->amount),
            'frequency' => $obligation->frequency,
            'active' => (bool) $obligation->active,
            'created_at' => $obligation->created_at?->toISOString(),
        ];
    }

    private function authorizeManage(Request $request): void
    {
        if (!$request->user()->hasRole([UserRole::OWNER->value, UserRole::MANAGER->value])) {
            abort(403, 'لا تملك صلاحية إدارة الالتزامات.');
        }
    }
}
