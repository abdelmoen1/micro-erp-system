<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\AccountDeletionRequest;
use App\Services\AccountDeletionService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Platform admin: deletion requests, and the manual ones (no password) to verify and complete. */
class DeletionRequestController extends Controller
{
    public function index(Request $request)
    {
        $filters = $request->validate(['status' => ['nullable', 'string', 'max:20']]);
        $rows = AccountDeletionRequest::query()
            ->when($filters['status'] ?? null, fn($q, $s) => $q->where('status', $s))
            ->latest('id')->limit(200)->get();

        return response()->json(['data' => $rows->map(fn($r) => $r->publicView() + [
            'id' => $r->id,
            'source' => $r->source,
            'phone_masked' => $r->phone_masked,
            'store_name' => $r->store_name,
            'store_id' => $r->store_id,
            'has_account' => $r->user_id !== null || $r->status === AccountDeletionRequest::COMPLETED,
            'reason' => $r->reason,
            'result' => $r->result,
        ])->values()]);
    }

    public function update(Request $request, AccountDeletionRequest $deletionRequest, AccountDeletionService $deletion)
    {
        $data = $request->validate(['action' => ['required', Rule::in(['approve', 'reject'])], 'note' => ['nullable', 'string', 'max:1000']]);

        if ($data['action'] === 'approve') {
            $result = $deletion->approve($deletionRequest, $request->user());
        } else {
            abort_unless($deletionRequest->status === AccountDeletionRequest::PENDING_REVIEW, 409);
            $deletionRequest->forceFill([
                'status' => AccountDeletionRequest::REJECTED,
                'processed_by' => $request->user()->id,
                'result' => ['note' => $data['note'] ?? null],
            ])->save();
            $result = $deletionRequest;
        }

        return response()->json(['data' => $result->publicView()]);
    }
}
