<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\CreateInvitationRequest;
use App\Services\AuditService;
use App\Services\AuthService;
use Illuminate\Support\Facades\DB;

class InvitationController extends Controller
{
    public function __construct(
        private readonly AuthService $authService,
        private readonly AuditService $audit,
    ) {}

    public function store(CreateInvitationRequest $request)
    {
        [$invitation, $token] = DB::transaction(function () use ($request) {
            [$invitation, $token] = $this->authService->createInvitation(
                $request->user(),
                $request->validated(),
            );

            $this->audit->record('invitation.created', $invitation, [
                'role' => $invitation->role->value,
                'email' => $invitation->email,
            ]);

            return [$invitation, $token];
        });

        return response()->json([
            'message' => 'تم إنشاء الدعوة بنجاح',
            'invitation' => [
                'id' => $invitation->id,
                'email' => $invitation->email,
                'role' => $invitation->role,
                'expires_at' => $invitation->expires_at,
                'token' => $token,
            ],
        ], 201);
    }
}
