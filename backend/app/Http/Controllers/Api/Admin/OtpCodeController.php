<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\SignInPhone;
use App\Models\PhoneOtp;
use App\Services\AuditService;
use App\Services\OtpService;
use App\Support\PhoneNumber;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Platform admin: a sign-up or reset code for someone whose SMS did not arrive. The person asks on
 * WhatsApp, the admin reads the code back. Only its use is audited; the code itself is never stored.
 */
class OtpCodeController extends Controller
{
    public function __invoke(Request $request, OtpService $otp, AuditService $audit)
    {
        $request->merge(['phone' => SignInPhone::prepare($request->input('phone'))]);
        $data = $request->validate([
            'phone' => ['required', 'string', 'regex:' . PhoneNumber::PATTERN],
            'purpose' => ['required', Rule::in([PhoneOtp::PURPOSE_REGISTER, PhoneOtp::PURPOSE_RESET])],
        ], SignInPhone::messages('phone'));

        $code = $otp->issue($data['phone'], $data['purpose']);
        $audit->record('platform.otp_issued', 'PhoneOtp', [
            'phone' => PhoneNumber::masked($data['phone']),
            'purpose' => $data['purpose'],
        ]);

        return response()->json(['data' => ['code' => $code, 'expires_in_minutes' => OtpService::TTL_MINUTES]], 201);
    }
}
