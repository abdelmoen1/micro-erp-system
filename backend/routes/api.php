<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\CustomerDebtController;
use App\Http\Controllers\Api\DebtController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\InvoiceController;
use App\Http\Controllers\Api\InvitationController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\DashboardController;


// Authentication
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/register/invitation', [AuthController::class, 'acceptInvitation']);


// Protected API
Route::middleware(['auth:sanctum', 'store'])->group(function () {


    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::get('/dashboard', [DashboardController::class, 'index']);
    Route::post('/invitations', [InvitationController::class, 'store']);
    Route::get('/users', [UserController::class, 'index']);

    Route::patch('/users/{user}/role', [
        UserController::class,
        'updateRole',
    ]);

    Route::delete('/users/{user}', [
        UserController::class,
        'destroy',
    ]);

    // Current user's store
    Route::get('/my-store', function (Request $request) {
        return response()->json([
            'user' => $request->user()->name,
            'store' => $request->user()->store,
        ]);
    });


    // Customers
    Route::apiResource('customers', CustomerController::class);

    Route::get(
        '/customers/{customer}/debts',
        [CustomerDebtController::class, 'index']
    );

    Route::post(
        '/customers/{customer}/debts/pay-all',
        [CustomerDebtController::class, 'payAll']
    );


    // Invoices
    Route::apiResource('invoices', InvoiceController::class);

    // Debts
    Route::get('debts', [DebtController::class, 'index']);
    Route::post('debts', [DebtController::class, 'store']);
    Route::get('debts/{debt}', [DebtController::class, 'show']);
    Route::get('debts/{debt}/details', [DebtController::class, 'details']);
    Route::put('debts/{debt}', [DebtController::class, 'update']);
    Route::patch('debts/{debt}', [DebtController::class, 'update']);
    Route::delete('debts/{debt}', [DebtController::class, 'destroy']);

    // Payments
    Route::apiResource('payments', PaymentController::class)
        ->only(['index', 'store']);

    Route::post(
        '/payments/{payment}/reverse',
        [PaymentController::class, 'is_reverse']
    );

    Route::post(
        '/payment-groups/{paymentGroupId}/reverse',
        [PaymentController::class, 'reverseGroup']
    );
});
