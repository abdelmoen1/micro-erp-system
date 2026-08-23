<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\DashboardRequest;
use App\Http\Resources\DashboardResource;
use App\Services\DashboardService;

class DashboardController extends Controller
{
    public function __construct(private readonly DashboardService $dashboardService) {}

    public function index(DashboardRequest $request): DashboardResource
    {
        return new DashboardResource(
            $this->dashboardService->dashboard(
                (int) $request->user()->store_id,
                $request->period(),
            )
        );
    }
}
