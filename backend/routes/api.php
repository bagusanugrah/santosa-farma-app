<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\MidtransWebhookController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\ReceiptController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\StoreStatusController;
use App\Http\Controllers\Api\TransactionController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes — Apotek Santosa Farma
|--------------------------------------------------------------------------
*/

// ==========================================
// 1. STORE STATUS & LIFECYCLE
// ==========================================
Route::get('/store/status', [StoreStatusController::class, 'status']);
Route::post('/store/open', [StoreStatusController::class, 'open']);
Route::post('/store/close', [StoreStatusController::class, 'close']);

// ==========================================
// 2. AUTHENTICATION
// ==========================================
Route::prefix('auth')->group(function () {
    // Staff Auth
    Route::post('/staff/login', [AuthController::class, 'staffLogin']);
    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/staff/me', [AuthController::class, 'staffMe']);
        Route::post('/staff/logout', [AuthController::class, 'staffLogout']);
    });

    // Customer Auth (Web Client)
    Route::post('/customer/register', [AuthController::class, 'customerRegister']);
    Route::post('/customer/verify-otp', [AuthController::class, 'customerVerifyOtp']);
    Route::post('/customer/resend-otp', [AuthController::class, 'customerResendOtp']);
    Route::post('/customer/login', [AuthController::class, 'customerLogin']);
    Route::post('/customer/forgot-password', [AuthController::class, 'customerForgotPassword']);
    Route::post('/customer/reset-password', [AuthController::class, 'customerResetPassword']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/customer/profile', [AuthController::class, 'customerProfile']);
        Route::put('/customer/profile', [AuthController::class, 'customerUpdateProfile']);
        Route::post('/customer/add-contact', [AuthController::class, 'customerAddContact']);
        Route::post('/customer/verify-add-contact', [AuthController::class, 'customerVerifyAddContact']);
        Route::post('/customer/change-password', [AuthController::class, 'customerChangePassword']);
    });
});

// ==========================================
// 3. PRODUCTS (Catalog & Management)
// ==========================================
Route::get('/products', [ProductController::class, 'index']);
Route::get('/products/{id}', [ProductController::class, 'show']);

Route::middleware(['auth:sanctum', 'role:super_admin'])->group(function () {
    Route::post('/products', [ProductController::class, 'store']);
    Route::put('/products/{id}', [ProductController::class, 'update']);
    Route::post('/products/{id}', [ProductController::class, 'update']); // For multipart form-data updates
    Route::delete('/products/{id}', [ProductController::class, 'destroy']);
});

// ==========================================
// 4. TRANSACTIONS & POS
// ==========================================
// Public / Semi-public receipt stream
Route::get('/receipts/{id}/pdf', [ReceiptController::class, 'downloadReceipt']);

// Staff Transactions & POS
Route::middleware(['auth:sanctum', 'role:super_admin,admin_kasir'])->group(function () {
    Route::get('/transactions', [TransactionController::class, 'index']);
    Route::get('/transactions/show/{id}', [TransactionController::class, 'show']);
    Route::post('/transactions/pos', [TransactionController::class, 'posCheckout']);
    Route::get('/transactions/pos/active-qris', [TransactionController::class, 'activeQris']);
    Route::get('/transactions/qr/{qrToken}', [TransactionController::class, 'getOrderByQr']);
    Route::post('/transactions/pickup/{qrToken}', [TransactionController::class, 'confirmPickup']);
    Route::delete('/transactions/{id}', [TransactionController::class, 'destroy']);
});

// Customer Online Checkout
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/transactions/checkout', [TransactionController::class, 'onlineCheckout']);
    Route::get('/transactions/customer/my-orders', [TransactionController::class, 'myOrders']);
});

// ==========================================
// 5. MIDTRANS WEBHOOK
// ==========================================
Route::post('/webhooks/midtrans', [MidtransWebhookController::class, 'handle']);

// ==========================================
// 6. REPORTS & ANALYTICS (Super Admin Only)
// ==========================================
Route::middleware(['auth:sanctum', 'role:super_admin'])->prefix('reports')->group(function () {
    Route::get('/sales-pdf', [ReportController::class, 'salesPdf']);
    Route::get('/products-excel', [ReportController::class, 'productsExcel']);
    Route::get('/analytics', [ReportController::class, 'analytics']);
});
