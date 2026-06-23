<?php

use App\Http\Controllers\Api\AIController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BudgetController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\ReceiptController;
use App\Http\Controllers\Api\TransactionController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Every route in this file is automatically prefixed with "/api".
| For example, the route below becomes  POST /api/register.
|
| Public routes (register, login) need no token.
| All routes inside the "auth:api" group require a valid JWT sent as:
|     Authorization: Bearer <access_token>
|
*/

// ---- Public routes (no token required) ----
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

// ---- Protected routes (valid JWT required) ----
Route::middleware('auth:api')->group(function () {

    // Auth helpers
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);

    // Transactions.
    // IMPORTANT: declare the fixed "/transactions/..." routes BEFORE the apiResource,
    // otherwise Laravel would treat "summary"/"auto-categorize" as a {transaction} id.
    Route::get('/transactions/summary', [TransactionController::class, 'summary']);
    Route::post('/transactions/auto-categorize', [TransactionController::class, 'autoCategorize']);
    Route::apiResource('transactions', TransactionController::class);

    // Categories (read-only list of default + custom categories)
    Route::get('/categories', [CategoryController::class, 'index']);

    // Budgets
    Route::get('/budgets', [BudgetController::class, 'index']);
    Route::post('/budgets', [BudgetController::class, 'store']);

    // ---- AI features (Phase 2) ----
    Route::post('/receipt/scan', [ReceiptController::class, 'scan']); // receipt OCR via GPT-4o Vision
    Route::post('/ai/chat', [AIController::class, 'chat']);           // chat with your finances
});
