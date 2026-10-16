<?php

use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\CustomerDebtController;
use App\Http\Controllers\Api\DebtController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\InvoiceController;
use App\Http\Controllers\Api\InvitationController;
use App\Http\Controllers\Api\StoreSettingsController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\ProductController;

// All routes are served under /api/v1 (bootstrap/app.php, D-22).

// Authentication (login throttling lives in AuthService: 5 failures/min per email+IP)
Route::post('/login', [AuthController::class, 'login']);
Route::middleware('throttle:register')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/register/invitation', [AuthController::class, 'acceptInvitation']);
});


// Protected API
Route::middleware(['auth:sanctum', 'active', 'store'])->group(function () {


    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::get('/dashboard', [DashboardController::class, 'index']);
    Route::post('/invitations', [InvitationController::class, 'store']);
    Route::get('/users', [UserController::class, 'index']);

    Route::patch('/users/{user}/role', [
        UserController::class,
        'updateRole',
    ]);

    // D-13: staff are deactivated, never deleted.
    Route::post('/users/{user}/deactivate', [
        UserController::class,
        'deactivate',
    ]);

    // Current user's store
    Route::get('/my-store', [StoreSettingsController::class, 'show']);
    Route::patch('/my-store', [StoreSettingsController::class, 'update']);


    // Products (US-0401). No DELETE: products are deactivated (BR-04). `lookup` precedes {product}.
    Route::get('products/lookup', [ProductController::class, 'lookup']);
    Route::get('products', [ProductController::class, 'index']);
    Route::post('products', [ProductController::class, 'store']);
    Route::get('products/{product}', [ProductController::class, 'show']);
    Route::patch('products/{product}', [ProductController::class, 'update']);
    Route::post('products/{product}/deactivate', [ProductController::class, 'deactivate']);

    // Customers
    Route::apiResource('customers', CustomerController::class);

    Route::get(
        '/customers/{customer}/debts',
        [CustomerDebtController::class, 'index']
    );

    // Financial writes require an Idempotency-Key (US-0101).
    Route::post(
        '/customers/{customer}/debts/pay-all',
        [CustomerDebtController::class, 'payAll']
    )->middleware('idempotent');


    // Invoices
    Route::apiResource('invoices', InvoiceController::class)->except('store');
    Route::post('invoices', [InvoiceController::class, 'store'])->middleware('idempotent');

    // Debts
    Route::get('debts', [DebtController::class, 'index']);
    Route::post('debts', [DebtController::class, 'store'])->middleware('idempotent');
    Route::get('debts/{debt}', [DebtController::class, 'show']);
    Route::get('debts/{debt}/details', [DebtController::class, 'details']);
    Route::put('debts/{debt}', [DebtController::class, 'update']);
    Route::patch('debts/{debt}', [DebtController::class, 'update']);
    Route::delete('debts/{debt}', [DebtController::class, 'destroy']);

    // Payments
    Route::get('payments', [PaymentController::class, 'index']);
    Route::post('payments', [PaymentController::class, 'store'])->middleware('idempotent');

    Route::post(
        '/payments/{payment}/reverse',
        [PaymentController::class, 'is_reverse']
    )->middleware('idempotent');

    Route::post(
        '/payment-groups/{paymentGroupId}/reverse',
        [PaymentController::class, 'reverseGroup']
    )->middleware('idempotent');
});
