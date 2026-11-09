<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\SignInPhone;
use App\Models\AccountDeletionRequest;
use App\Models\User;
use App\Services\AccountDeletionService;
use App\Services\AuditService;
use App\Services\AuthService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * Account deletion from the app/website (signed in) and from the public /delete-account page
 * (no app, no session). See ACCOUNT_DELETION_PLAN.md.
 */
class AccountDeletionController extends Controller
{
    public function __construct(private readonly AccountDeletionService $deletion) {}

    /** GET /me/deletion: what deleting means for this account, and any request in progress. */
    public function show(Request $request)
    {
        $user = $request->user();
        $current = AccountDeletionRequest::where('user_id', $user->id)->latest('id')->first();

        return response()->json(['data' => [
            'type' => $user->hasRole(UserRole::OWNER) ? AccountDeletionRequest::TYPE_STORE : AccountDeletionRequest::TYPE_STAFF,
            'store_name' => $user->store?->name,
            'grace_days' => (int) config('hisbah.deletion_grace_days'),
            'request' => $current?->publicView(),
        ]]);
    }

    /** POST /me/deletion {password, confirm_store_name (owner)}. */
    public function store(Request $request)
    {
        $user = $request->user();
        $data = $request->validate([
            'password' => ['required', 'string'],
            'confirm_store_name' => [$user->hasRole(UserRole::OWNER) ? 'required' : 'nullable', 'string', 'max:255'],
            'reason' => ['nullable', 'string', 'max:1000'],
        ], ['password.required' => 'اكتب كلمة المرور لتأكيد الحذف.', 'confirm_store_name.required' => 'اكتب اسم المتجر لتأكيد الحذف.']);

        if (!$user->password || !Hash::check($data['password'], $user->password)) {
            throw ApiException::businessRule('VALIDATION_FAILED', 'كلمة المرور غير صحيحة.', ['password' => ['كلمة المرور غير صحيحة.']]);
        }

        $result = $this->deletion->request($user, $request->header('X-Client') === 'app' ? 'app' : 'web', $data['confirm_store_name'] ?? null, $data['reason'] ?? null);

        return response()->json(['data' => $result->publicView()], 201);
    }

    /** DELETE /me/deletion: the owner keeps the store (before the scheduled date). */
    public function cancel(Request $request)
    {
        return response()->json(['data' => $this->deletion->cancelClosure($request->user())->publicView()]);
    }

    /**
     * POST /account-deletion (public): {phone, password[, confirm_store_name]} does what the app does.
     * {phone, no_password: true} files a request a platform admin verifies by hand; the answer is the
     * same whether or not the number has an account.
     */
    public function publicRequest(Request $request, AuthService $auth)
    {
        $request->merge(['phone' => SignInPhone::prepare($request->input('phone'))]);
        $data = $request->validate([
            // Format only: whether the number has an account is never revealed here.
            'phone' => ['required', 'string', 'regex:' . \App\Support\PhoneNumber::PATTERN],
            'password' => ['required_without:no_password', 'nullable', 'string'],
            'no_password' => ['nullable', 'boolean'],
            'confirm_store_name' => ['nullable', 'string', 'max:255'],
            'reason' => ['nullable', 'string', 'max:1000'],
        ], SignInPhone::messages('phone'));

        if (!empty($data['no_password']) && empty($data['password'])) {
            $result = $this->deletion->manualRequest($data['phone'], $data['reason'] ?? null);

            return response()->json(['data' => $result->publicView(), 'message' => 'استلمنا طلبك. سنتحقق من صاحب الرقم قبل الحذف.'], 202);
        }

        $user = $auth->verifyCredentials($data['phone'], (string) $data['password'], (string) $request->ip());
        $result = $this->deletion->request($user, 'public', $data['confirm_store_name'] ?? null, $data['reason'] ?? null);

        return response()->json(['data' => $result->publicView()], 201);
    }

    /** GET /account-deletion/{reference}: status only (the reference is an unguessable UUID). */
    public function status(string $reference)
    {
        $request = AccountDeletionRequest::where('reference', $reference)->firstOrFail();

        return response()->json(['data' => $request->publicView()]);
    }

    /**
     * POST /my-store/transfer-ownership {user_id, password}: the owner hands the store to an active
     * manager and becomes a manager (who may then delete their own account without closing the store).
     */
    public function transferOwnership(Request $request, AuditService $audit)
    {
        $owner = $request->user();
        if (!$owner->hasRole(UserRole::OWNER)) {
            throw new ApiException(403, 'FORBIDDEN', 'صاحب المتجر فقط ينقل الملكية.');
        }
        $data = $request->validate(['user_id' => ['required', 'integer'], 'password' => ['required', 'string']]);
        if (!Hash::check($data['password'], (string) $owner->password)) {
            throw ApiException::businessRule('VALIDATION_FAILED', 'كلمة المرور غير صحيحة.', ['password' => ['كلمة المرور غير صحيحة.']]);
        }
        $target = User::where('store_id', $owner->store_id)->whereKey($data['user_id'])->first();
        if (!$target || !$target->isActive() || !$target->hasRole(UserRole::MANAGER)) {
            throw ApiException::businessRule('VALIDATION_FAILED', 'اختر مديراً نشطاً في متجرك.', ['user_id' => ['اختر مديراً نشطاً في متجرك.']]);
        }

        DB::transaction(function () use ($owner, $target, $audit) {
            $target->forceFill(['role' => UserRole::OWNER])->save();
            $owner->forceFill(['role' => UserRole::MANAGER])->save();
            $audit->record('store.ownership_transferred', $owner->store, ['from' => $owner->id, 'to' => $target->id], $owner);
        });

        return response()->json(['message' => 'تم نقل ملكية المتجر.', 'data' => ['owner_id' => $target->id]]);
    }
}
