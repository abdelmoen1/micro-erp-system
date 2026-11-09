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
use App\Http\Controllers\Api\PurchaseController;
use App\Http\Controllers\Api\StockAdjustmentController;
use App\Http\Controllers\Api\SubscriptionController;
use App\Http\Controllers\Api\SupplierController;
use App\Http\Controllers\Api\Admin\OtpCodeController as AdminOtpCodeController;
use App\Http\Controllers\Api\SupportTicketController;
use App\Http\Controllers\Api\AccountDeletionController;
use App\Http\Controllers\Api\PaymentWebhookController;
use App\Http\Controllers\Api\Admin\DeletionRequestController as AdminDeletionRequestController;
use App\Http\Controllers\Api\Admin\SubscriptionOrderController as AdminSubscriptionOrderController;
use App\Http\Controllers\Api\Admin\SubscriptionPlanController as AdminSubscriptionPlanController;
use App\Http\Controllers\Api\SyncController;
use App\Http\Controllers\Api\Admin\OverviewController as AdminOverviewController;
use App\Http\Controllers\Api\Admin\ProductController as AdminProductController;
use App\Http\Controllers\Api\Admin\StoreController as AdminStoreController;
use App\Http\Controllers\Api\Admin\SupplierController as AdminSupplierController;
use App\Http\Controllers\Api\Admin\SupportTicketController as AdminSupportTicketController;

// All routes are served under /api/v1 (bootstrap/app.php, D-22).

// Authentication by mobile number (login throttling lives in AuthService: 5 failures/min per number + IP)
Route::post('/login', [AuthController::class, 'login']);
// Sign-in by mobile number: what the screens offer, one-time SMS codes, and a forgotten password.
Route::get('/auth/options', [AuthController::class, 'options']);
Route::post('/auth/otp', [AuthController::class, 'sendOtp'])->middleware('throttle:otp');
Route::post('/auth/password/reset', [AuthController::class, 'resetPassword'])->middleware('throttle:register');
Route::middleware('throttle:register')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/register/invitation', [AuthController::class, 'acceptInvitation']);
    // Public account deletion (the website's /delete-account page): no app and no session needed.
    Route::post('/account-deletion', [AccountDeletionController::class, 'publicRequest']);
});
Route::get('/account-deletion/{reference}', [AccountDeletionController::class, 'status'])->whereUuid('reference')->middleware('throttle:30,1');

// Online payment notifications. Unauthenticated: the provider adapter verifies the signature.
// No provider is enabled yet, so this answers 404 (config/payments.php).
Route::post('/payments/webhooks/{provider}', PaymentWebhookController::class)->where('provider', '[a-z_]{2,30}')->middleware('throttle:120,1');


// Platform owner (users.is_platform_admin, granted only by `php artisan hisbah:platform-admin`).
// Not under `store`: the admin works across stores. Account access and subscription are separate writes.
Route::middleware(['auth:sanctum', 'active', 'platform.admin', 'throttle:api'])->prefix('admin')->group(function () {
    Route::get('overview', AdminOverviewController::class);
    Route::get('stores', [AdminStoreController::class, 'index']);
    Route::get('stores/{store}', [AdminStoreController::class, 'show']);
    Route::get('stores/{store}/products', [AdminStoreController::class, 'products']);
    Route::post('stores/{store}/status', [AdminStoreController::class, 'updateStatus']);
    Route::post('stores/{store}/subscription', [AdminStoreController::class, 'updateSubscription']);
    Route::delete('stores/{store}', [AdminStoreController::class, 'destroy']);
    Route::get('products', [AdminProductController::class, 'index']);
    Route::get('catalog-products', [AdminProductController::class, 'catalogIndex']);
    Route::get('catalog-products/{catalogProduct}', [AdminProductController::class, 'catalog']);
    Route::get('suppliers', [AdminSupplierController::class, 'index']);
    Route::get('suppliers/{supplier}', [AdminSupplierController::class, 'show'])->whereNumber('supplier');
    Route::get('support-tickets', [AdminSupportTicketController::class, 'index']);
    Route::patch('support-tickets/{ticket}', [AdminSupportTicketController::class, 'update']);
    Route::post('otp-codes', AdminOtpCodeController::class)->middleware('throttle:20,1');
    // Plans and subscription requests (manual WhatsApp payments are confirmed here, by hand).
    Route::get('subscription-plans', [AdminSubscriptionPlanController::class, 'index']);
    Route::patch('subscription-plans/{plan}', [AdminSubscriptionPlanController::class, 'update']);
    Route::get('subscription-orders', [AdminSubscriptionOrderController::class, 'index']);
    Route::get('subscription-orders/{order}', [AdminSubscriptionOrderController::class, 'show']);
    Route::post('subscription-orders/{order}/status', [AdminSubscriptionOrderController::class, 'transition']);
    Route::post('subscription-orders/{order}/notes', [AdminSubscriptionOrderController::class, 'note']);
    Route::post('subscription-orders/{order}/confirm-payment', [AdminSubscriptionOrderController::class, 'confirmPayment'])->middleware('throttle:20,1');
    Route::get('deletion-requests', [AdminDeletionRequestController::class, 'index']);
    Route::patch('deletion-requests/{deletionRequest}', [AdminDeletionRequestController::class, 'update']);
});

// Protected API (`throttle:api`: 300 calls a minute per account, AppServiceProvider)
Route::middleware(['auth:sanctum', 'active', 'store', 'throttle:api'])->group(function () {


    // Session routes: open to a store whose trial or subscription has ended, so it can still sign in,
    // see why, and recover as soon as the platform admin activates the subscription.
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::patch('/me/password', [AuthController::class, 'changePassword'])->middleware('throttle:6,1');
    Route::patch('/me/phone', [AuthController::class, 'changePhone'])->middleware('throttle:6,1');
    Route::get('/subscription', [SubscriptionController::class, 'show']);
    // Buying a plan (the WEBSITE; the Android app never calls these): open after expiry, to renew.
    Route::get('/subscription/plans', [SubscriptionController::class, 'plans']);
    Route::get('/subscription/orders', [SubscriptionController::class, 'orders']);
    Route::post('/subscription/orders', [SubscriptionController::class, 'store'])->middleware('throttle:10,1');
    // Account deletion: open after expiry too (Play: deletion must stay reachable).
    Route::get('/me/deletion', [AccountDeletionController::class, 'show']);
    Route::post('/me/deletion', [AccountDeletionController::class, 'store'])->middleware('throttle:6,1');
    Route::delete('/me/deletion', [AccountDeletionController::class, 'cancel']);
    Route::post('/my-store/transfer-ownership', [AccountDeletionController::class, 'transferOwnership'])->middleware('throttle:6,1');
    // Technical support: reachable after the subscription ends, when the store needs it most.
    Route::get('/support-tickets', [SupportTicketController::class, 'index']);
    Route::post('/support-tickets', [SupportTicketController::class, 'store'])->middleware('throttle:10,1');

    // Business routes: need a running trial or a valid paid subscription (403 SUBSCRIPTION_EXPIRED).
    Route::middleware('subscribed')->group(function () {
    Route::get('/dashboard', [DashboardController::class, 'index']);
    Route::post('/invitations', [InvitationController::class, 'store'])->middleware('entitled:staff');
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


    // Products (US-0401). No DELETE: products are deactivated (BR-04). `lookup` and `low-stock` precede {product}.
    Route::get('products/lookup', [ProductController::class, 'lookup']);
    // Shared catalog: my product and the platform-wide item for a barcode, before adding one.
    Route::get('products/catalog-lookup', [ProductController::class, 'catalogLookup']);
    Route::get('products/low-stock', [ProductController::class, 'lowStock']);
    Route::get('products/negative-stock', [ProductController::class, 'negativeStock']);
    Route::get('products/stock-value', [ProductController::class, 'stockValue']);
    Route::post('products/import', [ProductController::class, 'import'])->middleware('entitled:csv_import');
    Route::get('products', [ProductController::class, 'index']);
    Route::post('products', [ProductController::class, 'store']);
    Route::get('products/{product}', [ProductController::class, 'show']);
    Route::patch('products/{product}', [ProductController::class, 'update']);
    Route::post('products/{product}/deactivate', [ProductController::class, 'deactivate']);
    Route::get('products/{product}/movements', [ProductController::class, 'movements']);

    // Stock adjustments (US-0402): idempotent like the financial writes (05 §2).
    Route::post('stock-adjustments', [StockAdjustmentController::class, 'store'])->middleware('idempotent');

    // Goods from suppliers: invoice, stock and payment together; later payments on the account.
    // Plan feature `suppliers` gates new supplier writes; history stays readable.
    Route::post('purchases', [SupplierController::class, 'purchase'])->middleware(['idempotent', 'entitled:suppliers']);
    Route::get('purchases', [PurchaseController::class, 'index']);
    Route::get('purchases/{purchaseInvoice}', [PurchaseController::class, 'show']);
    // Goods back to the supplier: the balance first, then a refund (the mirror of US-0601).
    Route::post('purchases/{purchaseInvoice}/returns', [PurchaseController::class, 'storeReturn'])->middleware(['idempotent', 'entitled:suppliers']);
    Route::get('returns/purchases', [PurchaseController::class, 'purchaseReturns']);
    Route::get('returns/sales', [PurchaseController::class, 'saleReturns']);
    Route::get('suppliers', [SupplierController::class, 'index']);
    Route::get('suppliers/{supplier}', [SupplierController::class, 'show']);
    Route::get('suppliers/{supplier}/products/{product}', [SupplierController::class, 'product']);
    Route::post('suppliers/{supplier}/payments', [SupplierController::class, 'pay'])->middleware(['idempotent', 'entitled:suppliers']);

    // Customers
    Route::apiResource('customers', CustomerController::class);
    Route::get('customers/{customer}/summary', [CustomerController::class, 'summary']);
    Route::get('customers/{customer}/statement', [CustomerController::class, 'statement']);
    Route::post('customers/{customer}/deactivate', [CustomerController::class, 'deactivate']);
    Route::post('customers/{customer}/reactivate', [CustomerController::class, 'reactivate']);

    Route::get(
        '/customers/{customer}/debts',
        [CustomerDebtController::class, 'index']
    );

    // Financial writes require an Idempotency-Key (US-0101).
    Route::post(
        '/customers/{customer}/debts/pay-all',
        [CustomerDebtController::class, 'payAll']
    )->middleware('idempotent');


    // Sales (US-0501 – US-0503, 05 §3). Final at creation (D-06): no DELETE and no financial edit;
    // PATCH changes notes only, and a mistake is corrected by a void. `/invoices` is an alias.
    foreach (['sales', 'invoices'] as $sales) {
        Route::get($sales, [InvoiceController::class, 'index']);
        Route::get("{$sales}/{invoice}", [InvoiceController::class, 'show']);
        Route::match(['put', 'patch'], "{$sales}/{invoice}", [InvoiceController::class, 'update']);
        Route::post("{$sales}/{invoice}/void", [InvoiceController::class, 'void'])->middleware('idempotent');
        // US-0601: return lines of a sale (D-05 debt first, then cash refund).
        Route::post("{$sales}/{invoice}/returns", [InvoiceController::class, 'storeReturn'])->middleware('idempotent');
    }
    Route::post('sales', [InvoiceController::class, 'store'])->middleware('idempotent');

    // Debts
    Route::get('debts', [DebtController::class, 'index']);
    Route::get('debts/balances', [DebtController::class, 'balances']);
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

    // R2 offline sync (doc 16). The batch carries one Idempotency-Key per item, each run through
    // the same idempotency layer as POST /sales and pay-all, so the route itself has none.
    Route::get('sync/bootstrap', [SyncController::class, 'bootstrap']);
    Route::post('sync/batch', [SyncController::class, 'batch'])->middleware('throttle:60,1');
    Route::get('sync/conflicts', [SyncController::class, 'conflicts']);
    Route::post('sync/conflicts/{conflict}/resolve', [SyncController::class, 'resolve'])->middleware('idempotent');
    }); // subscribed
});
