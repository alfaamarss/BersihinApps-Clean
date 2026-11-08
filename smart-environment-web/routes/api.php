<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\UsersController;
use App\Http\Controllers\API\RolesController;
use App\Http\Controllers\API\MenusController;
use App\Http\Controllers\API\AreasController;
use App\Http\Controllers\API\RwsController;
use App\Http\Controllers\API\ServiceAccountsController;
use App\Http\Controllers\API\SchedulesController;
use App\Http\Controllers\API\CollectorAssignmentsController;
use App\Http\Controllers\API\WastesController;
use App\Http\Controllers\API\PocketSizesController;
use App\Http\Controllers\API\WastePricingsController;
use App\Http\Controllers\API\WasteDeliveriesController;
use App\Http\Controllers\API\WasteDeliveryItemsController;
use App\Http\Controllers\API\GarbageDumpsController;
use App\Http\Controllers\API\InvoicesController;
use App\Http\Controllers\API\PaymentsController;
use App\Http\Controllers\API\ComplaintsController;
use App\Http\Controllers\API\ArticlesController;
use App\Http\Controllers\API\AuditLogsController;
use App\Http\Controllers\API\Mobile\AreasController as MobileAreasController;
use App\Http\Controllers\API\Mobile\DashboardController as MobileDashboardController;
use App\Http\Controllers\API\Mobile\ServiceAccountsController as MobileServiceAccountsController;
use App\Http\Controllers\API\Mobile\AppSettingsController as MobileAppSettingsController;

// Mobile Collector Controllers
use App\Http\Controllers\API\Mobile\Collector\DashboardController as CollectorDashboardController;
use App\Http\Controllers\API\Mobile\Collector\ScheduleController as CollectorScheduleController;
use App\Http\Controllers\API\Mobile\Collector\DeliveryController as CollectorDeliveryController;
use App\Http\Controllers\API\Mobile\Collector\PickupController as CollectorPickupController;
use App\Http\Controllers\API\Mobile\Collector\OffSchedulePickupController as CollectorOffSchedulePickupController;
use App\Http\Controllers\API\Mobile\Collector\ComplaintController as CollectorComplaintController;
use App\Http\Controllers\API\Mobile\Collector\ProfileController as CollectorProfileController;
use App\Http\Controllers\API\Mobile\Collector\TpsDepositController as CollectorTpsDepositController;

// Mobile Resident Controllers
use App\Http\Controllers\API\Mobile\Resident\WasteDeliveryController as ResidentWasteDeliveryController;
use App\Http\Controllers\API\Mobile\Resident\ArticleController as ResidentArticleController;
use App\Http\Controllers\API\Mobile\Resident\ComplaintController as ResidentComplaintController;
use App\Http\Controllers\API\Mobile\Resident\ProfileController as ResidentProfileController;
use App\Http\Controllers\API\Mobile\Resident\InvoiceController as ResidentInvoiceController;
use App\Http\Controllers\API\Mobile\Resident\PickupController as ResidentPickupController;
use App\Http\Controllers\API\Mobile\Resident\PaymentController as ResidentPaymentController;
use App\Http\Controllers\API\Mobile\Resident\OffSchedulePickupController as ResidentOffSchedulePickupController;

// Webhook Controllers
use App\Http\Controllers\API\MidtransWebhookController;
use App\Http\Controllers\API\NotificationsController;

// Password Reset & Email Verification Controllers
use App\Http\Controllers\API\Mobile\Auth\PasswordResetController;
use App\Http\Controllers\API\Mobile\Auth\EmailVerificationController;

Route::prefix('v1')->group(function () {
    // Auth
    Route::post('/auth/register', [AuthController::class, 'register']);
    Route::post('/auth/login', [AuthController::class, 'login']);
    
    // Password Reset (Public routes)
    Route::post('/mobile/auth/password/forgot', [PasswordResetController::class, 'forgotPassword']);
    Route::post('/mobile/auth/password/reset', [PasswordResetController::class, 'resetPassword']);
    Route::post('/mobile/auth/password/verify-token', [PasswordResetController::class, 'verifyToken']);
    
    // Email Verification (Public route for verification link)
    Route::get('/mobile/auth/email/verify/{id}/{hash}', [EmailVerificationController::class, 'verify'])
        ->name('mobile.verification.verify');

    Route::middleware('auth:api')->group(function () {
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        
        // Email Verification (Authenticated routes)
        Route::post('/mobile/auth/email/resend-verification', [EmailVerificationController::class, 'resendVerification']);
        Route::get('/mobile/auth/email/verification-status', [EmailVerificationController::class, 'checkStatus']);

        // Mobile Routes
        Route::prefix('mobile')->group(function () {
            // Notifications (for all authenticated mobile users)
            Route::prefix('notifications')->group(function () {
                Route::get('/', [NotificationsController::class, 'index']);
                Route::get('/unread', [NotificationsController::class, 'unread']);
                Route::get('/unread-count', [NotificationsController::class, 'unreadCount']);
                Route::get('/categories', [NotificationsController::class, 'categories']);
                Route::get('/{id}', [NotificationsController::class, 'show']);
                Route::post('/{id}/read', [NotificationsController::class, 'markAsRead']);
                Route::post('/read-all', [NotificationsController::class, 'markAllAsRead']);
                Route::post('/read-multiple', [NotificationsController::class, 'markMultipleAsRead']);
                Route::delete('/{id}', [NotificationsController::class, 'destroy']);
                Route::delete('/clear-read', [NotificationsController::class, 'clearRead']);
                Route::post('/delete-multiple', [NotificationsController::class, 'destroyMultiple']);
            });

            // General mobile routes (for both resident & collector)
            Route::get('/dashboard', MobileDashboardController::class);
            Route::get('/areas', [MobileAreasController::class, 'index']);
            Route::get('/areas/{area_id}/rws', [MobileAreasController::class, 'rws']);
            Route::get('/settings', MobileAppSettingsController::class);
            Route::apiResource('service-accounts', MobileServiceAccountsController::class)
                ->parameters(['service-accounts' => 'id'])
                ->names([
                    'index' => 'mobile.service-accounts.index',
                    'store' => 'mobile.service-accounts.store',
                    'show' => 'mobile.service-accounts.show',
                    'update' => 'mobile.service-accounts.update',
                    'destroy' => 'mobile.service-accounts.destroy',
                ]);

            // Collector-specific routes
            Route::prefix('collector')->middleware('role:collector|admin,sanctum')->group(function () {
                Route::get('/dashboard', CollectorDashboardController::class);
                Route::get('/schedules', [CollectorScheduleController::class, 'index']);
                Route::get('/schedules/deliveries', [CollectorScheduleController::class, 'deliveries']);

                // Delivery status updates (LEGACY - for old system)
                Route::get('/deliveries/{id}', [CollectorDeliveryController::class, 'show']);
                Route::patch('/deliveries/{id}/status', [CollectorDeliveryController::class, 'updateStatus']);

                // Schedule-based Pickups (NEW)
                Route::get('/pickups/today', [CollectorPickupController::class, 'today']);
                Route::get('/pickups/history', [CollectorPickupController::class, 'history']);
                Route::get('/pickups/{id}', [CollectorPickupController::class, 'show']);
                Route::put('/pickups/{id}/start', [CollectorPickupController::class, 'start']);
                Route::put('/pickups/{id}/complete', [CollectorPickupController::class, 'complete']);
                Route::put('/pickups/{id}/skip', [CollectorPickupController::class, 'skip']);

                // Off-schedule pickups assignments
                Route::get('/off-schedule-pickups', [CollectorOffSchedulePickupController::class, 'index']);
                Route::get('/off-schedule-pickups/waste-options', [CollectorOffSchedulePickupController::class, 'getWasteOptions']);
                Route::get('/off-schedule-pickups/{id}', [CollectorOffSchedulePickupController::class, 'show']);
                Route::put('/off-schedule-pickups/{id}/complete', [CollectorOffSchedulePickupController::class, 'complete']);
                Route::put('/off-schedule-pickups/{id}/skip', [CollectorOffSchedulePickupController::class, 'skip']);

                // Waste Items with Pricing
                Route::get('/waste-items', [CollectorPickupController::class, 'wasteItems']);

                // Complaints assigned to collector
                Route::get('/complaints', [CollectorComplaintController::class, 'index']);
                Route::get('/complaints/statistics', [CollectorComplaintController::class, 'statistics']);
                Route::get('/complaints/{id}', [CollectorComplaintController::class, 'show']);
                Route::post('/complaints/{id}/update-status', [CollectorComplaintController::class, 'updateStatus']);

                // Profile management
                Route::get('/profile', [CollectorProfileController::class, 'show']);
                Route::put('/profile', [CollectorProfileController::class, 'update']);
                Route::post('/profile/change-password', [CollectorProfileController::class, 'changePassword']);
                Route::delete('/profile', [CollectorProfileController::class, 'deleteAccount']);

                // TPS Deposits (Setor ke TPS)
                Route::get('/tps', [CollectorTpsDepositController::class, 'getAvailableTps']);
                Route::get('/tps-deposits', [CollectorTpsDepositController::class, 'index']);
                Route::post('/tps-deposits', [CollectorTpsDepositController::class, 'store']);
                Route::get('/tps-deposits/{id}', [CollectorTpsDepositController::class, 'show']);
            });

            // Resident-specific routes
            Route::prefix('resident')->middleware('role:warga|resident|admin,sanctum')->group(function () {
                // Aliases for resident convenience & contract backward-compatibility
                Route::get('/dashboard', MobileDashboardController::class);
                Route::get('/service-accounts', [MobileServiceAccountsController::class, 'index']);
                Route::get('/notifications', [NotificationsController::class, 'index']);
                Route::get('/notifications/unread-count', [NotificationsController::class, 'unreadCount']);

                // Waste Deliveries
                Route::get('/waste-deliveries', [ResidentWasteDeliveryController::class, 'index']);
                Route::get('/waste-deliveries/{id}', [ResidentWasteDeliveryController::class, 'show']);
                Route::get('/waste-deliveries/next/pickup', [ResidentWasteDeliveryController::class, 'nextPickup']);
                Route::get('/waste-deliveries/statistics', [ResidentWasteDeliveryController::class, 'statistics']);
                Route::post('/waste-deliveries/{id}/confirm', [ResidentWasteDeliveryController::class, 'confirmPickup']);

                // Schedule-based Pickups (NEW)
                Route::get('/pickups/upcoming', [ResidentPickupController::class, 'upcoming']);
                Route::get('/pickups/history', [ResidentPickupController::class, 'history']);
                Route::get('/pickups/statistics', [ResidentPickupController::class, 'statistics']);
                Route::get('/pickups/{id}', [ResidentPickupController::class, 'show']);
                Route::put('/pickups/{id}/confirm', [ResidentPickupController::class, 'confirm']);
                Route::put('/pickups/{id}/note', [ResidentPickupController::class, 'updateNote']);

                // Off-schedule pickups
                Route::get('/off-schedule-pickups/pricing-info', [ResidentOffSchedulePickupController::class, 'getPricingInfo']);
                Route::get('/off-schedule-pickups/check-date', [ResidentOffSchedulePickupController::class, 'checkDate']);
                Route::post('/off-schedule-pickups/preview-skip', [ResidentOffSchedulePickupController::class, 'previewSkipScheduled']);
                Route::get('/off-schedule-pickups', [ResidentOffSchedulePickupController::class, 'index']);
                Route::post('/off-schedule-pickups', [ResidentOffSchedulePickupController::class, 'store']);
                Route::get('/off-schedule-pickups/{id}', [ResidentOffSchedulePickupController::class, 'show']);
                Route::put('/off-schedule-pickups/{id}/confirm', [ResidentOffSchedulePickupController::class, 'confirm']);

                // Articles
                Route::get('/articles', [ResidentArticleController::class, 'index']);
                Route::get('/articles/featured', [ResidentArticleController::class, 'featured']);
                Route::get('/articles/{id}', [ResidentArticleController::class, 'show']);

                // Complaints
                Route::get('/complaints', [ResidentComplaintController::class, 'index']);
                Route::post('/complaints', [ResidentComplaintController::class, 'store']);
                Route::get('/complaints/statistics', [ResidentComplaintController::class, 'statistics']);
                Route::get('/complaints/{id}', [ResidentComplaintController::class, 'show']);
                Route::put('/complaints/{id}', [ResidentComplaintController::class, 'update']);
                Route::post('/complaints/{id}/cancel', [ResidentComplaintController::class, 'cancel']);
                Route::post('/complaints/{id}/confirm-resolution', [ResidentComplaintController::class, 'confirmResolution']);

                // Profile
                Route::get('/profile', [ResidentProfileController::class, 'show']);
                Route::put('/profile', [ResidentProfileController::class, 'update']);
                Route::post('/profile/change-password', [ResidentProfileController::class, 'changePassword']);
                Route::delete('/profile', [ResidentProfileController::class, 'deleteAccount']);

                // Invoices
                Route::get('/invoices', [ResidentInvoiceController::class, 'index']);
                Route::get('/invoices/unpaid', [ResidentInvoiceController::class, 'unpaid']);
                Route::get('/invoices/statistics', [ResidentInvoiceController::class, 'statistics']);
                Route::get('/invoices/{id}', [ResidentInvoiceController::class, 'show']);
                Route::post('/invoices/{id}/dummy-pay', [ResidentInvoiceController::class, 'dummyPay']);

                // Payments (Midtrans)
                Route::get('/payments', [ResidentPaymentController::class, 'index']);
                Route::get('/payments/pending', [ResidentPaymentController::class, 'getPendingPayments']);
                Route::post('/payments/create', [ResidentPaymentController::class, 'createPayment']);
                Route::post('/payments/{orderId}/cancel', [ResidentPaymentController::class, 'cancelPayment']);
                Route::post('/payments/{orderId}/simulate-pay', [ResidentPaymentController::class, 'simulatePay']);
                Route::get('/payments/{orderId}', [ResidentPaymentController::class, 'getPaymentDetail']);
                Route::get('/payments/{orderId}/status', [ResidentPaymentController::class, 'checkPaymentStatus']);
            });
        });

        // Resourceful CRUD
        Route::apiResource('users', UsersController::class)->parameters(['users' => 'id']);
        Route::apiResource('roles', RolesController::class)->parameters(['roles' => 'id']);
        Route::apiResource('menus', MenusController::class)->parameters(['menus' => 'id']);

        Route::apiResource('areas', AreasController::class)->parameters(['areas' => 'id']);
        Route::apiResource('rws', RwsController::class)->parameters(['rws' => 'id']);
        Route::apiResource('service-accounts', ServiceAccountsController::class)->parameters(['service-accounts' => 'id']);
        Route::apiResource('schedules', SchedulesController::class)->parameters(['schedules' => 'id']);
        Route::apiResource('collector-assignments', CollectorAssignmentsController::class)->parameters(['collector-assignments' => 'id']);
        Route::apiResource('wastes', WastesController::class)->parameters(['wastes' => 'id']);
        Route::apiResource('pocket-sizes', PocketSizesController::class)->parameters(['pocket-sizes' => 'id']);
        Route::apiResource('waste-pricings', WastePricingsController::class)->parameters(['waste-pricings' => 'id']);
        Route::apiResource('waste-deliveries', WasteDeliveriesController::class)->parameters(['waste-deliveries' => 'id']);
        Route::apiResource('waste-delivery-items', WasteDeliveryItemsController::class)->parameters(['waste-delivery-items' => 'id']);
        Route::apiResource('garbage-dumps', GarbageDumpsController::class)->parameters(['garbage-dumps' => 'id']);
        Route::apiResource('invoices', InvoicesController::class)->parameters(['invoices' => 'id']);
        Route::post('invoices/{id}/confirm-payment', [InvoicesController::class, 'confirmPayment'])->middleware('role:admin');
        Route::get('invoices/{id}/va-status', [InvoicesController::class, 'checkVAStatus']);
        Route::apiResource('payments', PaymentsController::class)->parameters(['payments' => 'id']);
        Route::apiResource('complaints', ComplaintsController::class)->parameters(['complaints' => 'id']);
        Route::apiResource('articles', ArticlesController::class)->parameters(['articles' => 'id']);
        Route::apiResource('audit-logs', AuditLogsController::class)->only(['index','show'])->parameters(['audit-logs' => 'id']);

        // Admin - Pickup Monitoring
        Route::prefix('admin')->group(function () {
            Route::get('/pickups/monitor', [\App\Http\Controllers\Admin\PickupMonitorController::class, 'monitor']);
            Route::get('/pickups/statistics', [\App\Http\Controllers\Admin\PickupMonitorController::class, 'statistics']);
            Route::get('/pickups/{id}', [\App\Http\Controllers\Admin\PickupMonitorController::class, 'show']);
        });
    });

    // Midtrans Webhook (No Auth Required)
    Route::post('/payments/webhook', [ResidentPaymentController::class, 'webhook']);
    Route::post('/midtrans/webhook', [MidtransWebhookController::class, 'handleNotification']); // Legacy
    Route::get('/midtrans/webhook/test', [MidtransWebhookController::class, 'test']);
});
