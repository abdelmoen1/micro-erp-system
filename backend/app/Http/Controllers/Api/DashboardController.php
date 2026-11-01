<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\DashboardRequest;
use App\Http\Resources\DashboardResource;
use App\Models\Product;
use App\Services\DashboardService;

class DashboardController extends Controller
{
    public function __construct(private readonly DashboardService $dashboardService) {}

    public function index(DashboardRequest $request): DashboardResource
    {
        return new DashboardResource(
            $this->dashboardService->dashboard(
                $request->user()->store,
                $request->period(),
                // Costs and what the store owes stay off staff phones.
                $request->user()->can('adjustStock', Product::class),
            )
        );
    }
}
