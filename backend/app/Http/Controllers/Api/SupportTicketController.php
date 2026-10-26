<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\SupportTicketResource;
use App\Models\SupportTicket;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Technical support from the store's settings. Open to a store whose subscription has ended:
 * that is when it most needs to reach the Hisbah team. The owner and managers see the store's
 * complaints; an employee sees their own.
 */
class SupportTicketController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        $tickets = SupportTicket::query()
            ->where('store_id', $user->store_id)
            ->when($user->hasRole('employee'), fn($query) => $query->where('user_id', $user->id))
            ->with('user')
            ->latest('id')
            ->limit(50)
            ->get();

        return SupportTicketResource::collection($tickets);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'type' => ['required', Rule::in(SupportTicket::TYPES)],
            'subject' => ['required', 'string', 'max:150'],
            'details' => ['required', 'string', 'max:3000'],
        ], [
            'type.required' => 'اختر نوع الدعم.',
            'type.in' => 'نوع الدعم غير صحيح.',
            'subject.required' => 'اكتب موضوع المشكلة.',
            'subject.max' => 'الموضوع طويل جداً (150 حرفاً كحد أقصى).',
            'details.required' => 'اكتب تفاصيل المشكلة.',
            'details.max' => 'التفاصيل طويلة جداً (3000 حرف كحد أقصى).',
        ]);

        $user = $request->user();
        $ticket = SupportTicket::create([...$data, 'store_id' => $user->store_id, 'user_id' => $user->id]);

        return response()->json([
            'message' => 'وصلت شكواك إلى فريق حسبة، وسنرد عليك هنا.',
            'data' => new SupportTicketResource($ticket->load('user')),
        ], 201);
    }
}
