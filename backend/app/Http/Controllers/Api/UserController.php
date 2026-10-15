<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateUserRoleRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\AuditService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class UserController extends Controller
{
    public function __construct(private readonly AuditService $audit) {}

    /**
     * Display employees belonging to the authenticated owner's store.
     */
    public function index(Request $request)
    {
        $this->authorize('viewAny', User::class);

        $users = User::query()
            ->where('store_id', $request->user()->store_id)
            ->whereIn('role', [
                UserRole::EMPLOYEE->value,
                UserRole::MANAGER->value,
            ])
            ->select([
                'id',
                'name',
                'email',
                'role',
                'status',
                'deactivated_at',
                'created_at',
            ])
            ->latest()
            ->paginate(20);

        return UserResource::collection($users);
    }

    /**
     * Update only the role of a user.
     */
    public function updateRole(
        UpdateUserRoleRequest $request,
        User $user
    ) {
        $this->authorize('updateRole', $user);

        DB::transaction(function () use ($request, $user) {
            $oldRole = $user->role->value;
            $user->update(['role' => $request->validated('role')]);

            $this->audit->record('user.role_changed', $user, [
                'old_role' => $oldRole,
                'new_role' => $user->role->value,
            ]);
        });

        return new UserResource($user->refresh());
    }

    /**
     * Deactivate a staff member (D-13). Users are never deleted, so the
     * history they created keeps its attribution; their tokens are revoked.
     */
    public function deactivate(Request $request, User $user)
    {
        $this->authorize('deactivate', $user);

        DB::transaction(function () use ($user) {
            if (!$user->isActive()) {
                return;
            }

            $user->forceFill([
                'status' => User::STATUS_INACTIVE,
                'deactivated_at' => now(),
            ])->save();

            $user->tokens()->delete();

            $this->audit->record('user.deactivated', $user, [
                'role' => $user->role->value,
            ]);
        });

        return response()->json([
            'message' => 'تم إيقاف حساب المستخدم بنجاح',
            'data' => new UserResource($user->refresh()),
        ]);
    }
}
