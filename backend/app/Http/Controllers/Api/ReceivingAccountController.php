<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\PaymentMethods;
use App\Models\ReceivingAccount;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ReceivingAccountController extends Controller
{
    public function index(Request $request)
    {
        $includeInactive = $request->boolean('include_inactive');
        if ($includeInactive) {
            $this->authorizeManage($request);
        }
        $provider = $request->validate([
            'provider' => ['nullable', Rule::in(PaymentMethods::TRANSFER_PROVIDERS)],
        ])['provider'] ?? null;
        $query = ReceivingAccount::query()->forStore($request->user()->store_id)
            ->whereNull('deleted_at')->orderBy('provider')->orderBy('account_name');
        if ($provider !== null) {
            $query->where('provider', $provider);
        }
        if (!$includeInactive) {
            $query->where('active', true);
        }
        return response()->json(['data' => $query->get()]);
    }

    public function store(Request $request)
    {
        $this->authorizeManage($request);
        $data = $request->validate([
            'provider' => ['required', Rule::in(PaymentMethods::TRANSFER_PROVIDERS)],
            'account_name' => ['required', 'string', 'max:255'],
            'account_identifier' => ['required', 'string', 'max:255'],
            'active' => ['sometimes', 'boolean'],
        ]);
        $account = ReceivingAccount::create($data + [
            'store_id' => $request->user()->store_id,
            'created_by' => $request->user()->id,
            'updated_by' => $request->user()->id,
        ]);
        return response()->json(['message' => 'تم إضافة حساب الاستقبال.', 'data' => $account], 201);
    }

    public function update(Request $request, ReceivingAccount $account)
    {
        $this->authorizeManage($request);
        if ($account->store_id !== $request->user()->store_id) {
            abort(404);
        }
        $data = $request->validate([
            'provider' => ['sometimes', 'required', Rule::in(PaymentMethods::TRANSFER_PROVIDERS)],
            'account_name' => ['sometimes', 'required', 'string', 'max:255'],
            'account_identifier' => ['sometimes', 'required', 'string', 'max:255'],
            'active' => ['sometimes', 'boolean'],
        ]);
        $account->update($data + ['updated_by' => $request->user()->id]);
        return response()->json(['message' => 'تم تحديث حساب الاستقبال.', 'data' => $account->fresh()]);
    }

    public function destroy(Request $request, ReceivingAccount $account)
    {
        $this->authorizeManage($request);
        if ($account->store_id !== $request->user()->store_id) {
            abort(404);
        }
        $account->update(['active' => false, 'updated_by' => $request->user()->id]);
        $account->delete();
        return response()->json(['message' => 'تمت أرشفة حساب الاستقبال.']);
    }

    private function authorizeManage(Request $request): void
    {
        if (!$request->user()->hasRole([UserRole::OWNER->value, UserRole::MANAGER->value])) {
            abort(403, 'لا تملك صلاحية إدارة حسابات الاستقبال.');
        }
    }
}
