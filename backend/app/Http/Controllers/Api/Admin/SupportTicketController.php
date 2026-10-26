<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\SupportTicketResource;
use App\Models\SupportTicket;
use App\Services\AuditService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Platform admin: every store's complaints, newest first; status and one written reply. */
class SupportTicketController extends Controller
{
    public function index(Request $request)
    {
        $filters = $request->validate([
            'status' => ['nullable', Rule::in(SupportTicket::STATUSES)],
            'type' => ['nullable', Rule::in(SupportTicket::TYPES)],
            'search' => ['nullable', 'string', 'max:255'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $tickets = SupportTicket::query()
            ->with(['store', 'user'])
            ->when($filters['status'] ?? null, fn($query, string $status) => $query->where('status', $status))
            ->when($filters['type'] ?? null, fn($query, string $type) => $query->where('type', $type))
            ->when($filters['search'] ?? null, function ($query, string $search) {
                $like = '%' . $search . '%';
                $query->where(fn($q) => $q->where('subject', 'like', $like)
                    ->orWhere('details', 'like', $like)
                    ->orWhereHas('store', fn($s) => $s->where('name', 'like', $like)));
            })
            ->latest('id')
            ->paginate($filters['per_page'] ?? 20);

        return SupportTicketResource::collection($tickets)
            ->additional(['meta' => ['open_count' => SupportTicket::where('status', SupportTicket::STATUS_OPEN)->count()]]);
    }

    public function update(Request $request, SupportTicket $ticket, AuditService $audit)
    {
        $data = $request->validate([
            'status' => ['required', Rule::in(SupportTicket::STATUSES)],
            'reply' => ['nullable', 'string', 'max:3000'],
        ], [
            'status.required' => 'اختر الحالة.',
            'status.in' => 'الحالة غير صحيحة.',
            'reply.max' => 'الرد طويل جداً (3000 حرف كحد أقصى).',
        ]);

        $ticket->status = $data['status'];
        if (array_key_exists('reply', $data)) {
            $reply = trim((string) $data['reply']);
            if ($reply !== (string) $ticket->reply) {
                $ticket->reply = $reply === '' ? null : $reply;
                $ticket->replied_by = $reply === '' ? null : $request->user()->id;
                $ticket->replied_at = $reply === '' ? null : now();
            }
        }
        $ticket->save();
        $audit->record('support_ticket.updated', $ticket, ['status' => $ticket->status], storeId: $ticket->store_id);

        return response()->json([
            'message' => 'حُفظ الرد.',
            'data' => new SupportTicketResource($ticket->load(['store', 'user'])),
        ]);
    }
}
