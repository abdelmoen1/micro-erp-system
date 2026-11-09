<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\SubscriptionController;
use App\Models\SubscriptionPlan;
use App\Services\AuditService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Platform admin: the three plans (price, currency, duration, features, limits, active, order). No app update needed. */
class SubscriptionPlanController extends Controller
{
    public function index()
    {
        return response()->json([
            'data' => SubscriptionPlan::query()->ordered()->get()->map(fn($p) => SubscriptionController::plan($p) + [
                'is_active' => $p->is_active,
                'sort_order' => $p->sort_order,
                'features_all' => $p->features === null,
                'orderable' => $p->isOrderable(),
            ])->values(),
            'meta' => ['features' => config('hisbah.features'), 'limits' => config('hisbah.limits'), 'currencies' => config('payments.currencies')],
        ]);
    }

    public function update(Request $request, SubscriptionPlan $plan, AuditService $audit)
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:100'],
            'description' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'duration_months' => ['sometimes', 'integer', Rule::in([1, 3, 6, 12, 24])],
            'price' => ['sometimes', 'nullable', 'numeric', 'decimal:0,2', 'min:0.01', 'max:99999999'],
            'currency' => ['sometimes', 'nullable', Rule::in(config('payments.currencies'))],
            'features' => ['sometimes', 'nullable', 'array'],
            'features.*' => ['string', Rule::in(array_keys(config('hisbah.features')))],
            'limits' => ['sometimes', 'nullable', 'array'],
            'limits.max_employees' => ['nullable', 'integer', 'min:0', 'max:1000'],
            'limits.max_products' => ['nullable', 'integer', 'min:1', 'max:1000000'],
            'is_active' => ['sometimes', 'boolean'],
            'sort_order' => ['sometimes', 'integer', 'min:0', 'max:1000'],
        ]);
        if (array_key_exists('limits', $data) && $data['limits'] !== null) {
            $data['limits'] = array_intersect_key($data['limits'], config('hisbah.limits'));
        }

        $before = $plan->only(array_keys($data));
        $plan->fill($data);
        if ($plan->is_active && !$plan->isOrderable()) {
            return response()->json(['code' => 'VALIDATION_FAILED', 'message' => 'حدّد السعر والعملة قبل تفعيل الباقة.', 'errors' => ['price' => ['حدّد السعر والعملة قبل تفعيل الباقة.']]], 422);
        }
        $plan->save();
        $audit->record('platform.plan_updated', $plan, ['code' => $plan->code, 'before' => $before, 'after' => $plan->only(array_keys($data))]);

        return response()->json(['data' => SubscriptionController::plan($plan) + ['is_active' => $plan->is_active, 'sort_order' => $plan->sort_order, 'orderable' => $plan->isOrderable()]]);
    }
}
