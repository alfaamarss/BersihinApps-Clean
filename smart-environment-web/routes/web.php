<?php

use App\Http\Controllers\HomeController;
use App\Http\Controllers\Web\AuthController as WebAuthController;
use App\Http\Controllers\MenuController;
use App\Http\Controllers\PermissionController;
use App\Http\Controllers\RoleController;
use App\Http\Controllers\UserController;
use Illuminate\Support\Facades\View;
use App\Http\Controllers\AreaController;
use App\Http\Controllers\WasteController;
use App\Http\Controllers\Admin\CollectorAssignmentController;
use App\Http\Controllers\Admin\OffSchedulePickupController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;

Route::get('/', function () {
    // if (Auth::check()) {
    //     return redirect()->route('home');
    // }
    // return view('auth.login');
    return redirect()->route('login');
});

// Authentication routes
Route::middleware('guest')->group(function () {
    Route::get('/login', [WebAuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [WebAuthController::class, 'login'])->name('login.store');

    Route::get('/register', [WebAuthController::class, 'showRegister'])->name('register');
    Route::post('/register', [WebAuthController::class, 'register'])->name('register.store');

    Route::get('/forgot-password', [WebAuthController::class, 'showForgotPassword'])->name('password.request');
    Route::post('/forgot-password', [WebAuthController::class, 'sendResetLink'])->name('password.email');

    Route::get('/reset-password/{token}', [WebAuthController::class, 'showResetPassword'])->name('password.reset');
    Route::post('/reset-password', [WebAuthController::class, 'resetPassword'])->name('password.update');
});

Route::middleware('auth')->group(function () {
    Route::post('/logout', [WebAuthController::class, 'logout'])->name('logout');
    Route::get('/home', [HomeController::class, 'index'])->name('home')->middleware('role:admin');
    
    // Profile routes
    Route::get('/profile/edit', [\App\Http\Controllers\ProfileController::class, 'edit'])->name('profile.edit');
    Route::post('/profile/update', [\App\Http\Controllers\ProfileController::class, 'update'])->name('profile.update');
    Route::get('/profile/change-password', [\App\Http\Controllers\ProfileController::class, 'showChangePassword'])->name('profile.change-password');
    Route::post('/profile/change-password', [\App\Http\Controllers\ProfileController::class, 'updatePassword'])->name('profile.update-password');
});

// Admin routes
Route::middleware(['auth', 'role:admin'])->group(function () {
    Route::resource('manage-user', UserController::class);
    Route::post('manage-user/{id}/restore', [UserController::class, 'restore'])->name('manage-user.restore');
    Route::resource('manage-role', RoleController::class);
    Route::resource('manage-menu', MenuController::class);
    Route::resource('manage-permission', PermissionController::class)->only('store', 'destroy');

    // Admin pages (placeholder routes)
    Route::prefix('admin')->group(function () {
    // Dashboard route removed; main dashboard is at route('home')
    Route::get('/notifications', fn() => View::make('admin.notifications.index'))->name('admin.notifications');

    // Schedules
    Route::get('/schedules/kelurahans', [\App\Http\Controllers\Admin\ScheduleController::class, 'getKelurahans'])->name('admin.schedules.kelurahans');
    Route::get('/schedules/{schedule}/check-conflict', [\App\Http\Controllers\Admin\ScheduleController::class, 'checkConflict'])->name('admin.schedules.check-conflict');
    Route::get('/schedules/calendar', [\App\Http\Controllers\Admin\ScheduleController::class, 'calendar'])->name('admin.schedules.calendar');
    Route::get('/schedules/calendar-events', [\App\Http\Controllers\Admin\ScheduleController::class, 'calendarEvents'])->name('admin.schedules.calendar-events');
    Route::resource('schedules', \App\Http\Controllers\Admin\ScheduleController::class, ['as' => 'admin'])->except(['show']);

    // Collector Assignments (custom routes MUST be before resource routes)
    Route::prefix('collector-assignments')->name('admin.collector-assignments.')->controller(CollectorAssignmentController::class)->group(function () {
        Route::get('/kelurahans', 'getKelurahans')->name('kelurahans');
        Route::get('/schedules', 'getSchedules')->name('schedules');
        Route::get('/rws', 'getRws')->name('rws');
        Route::get('/rws-with-status', 'getRwsWithAssignmentStatus')->name('rws-with-status');
        Route::post('/quick-assign', 'quickAssign')->name('quick-assign');
        Route::get('/collectors', 'getCollectors')->name('collectors');
    });
    Route::resource('collector-assignments', CollectorAssignmentController::class, ['as' => 'admin'])->except(['show']);
    Route::get('/collectors/workload', fn() => View::make('admin.notifications.index', ['title' => 'Workload Collector']))->name('admin.collectors.workload');

    // Complaints
    Route::resource('complaints', \App\Http\Controllers\Admin\ComplaintController::class, ['as' => 'admin']);
    Route::post('complaints/{complaint}/assign-collector', [\App\Http\Controllers\Admin\ComplaintController::class, 'assignCollector'])->name('admin.complaints.assign-collector');
    Route::post('complaints/{complaint}/update-status', [\App\Http\Controllers\Admin\ComplaintController::class, 'updateStatus'])->name('admin.complaints.update-status');

    // Pickup Monitoring (Schedule-based)
    Route::get('/pickups/monitor', [\App\Http\Controllers\Admin\PickupMonitorController::class, 'index'])->name('admin.pickups.monitor');
    Route::get('/pickups/monitor-data', [\App\Http\Controllers\Admin\PickupMonitorController::class, 'monitor'])->name('admin.pickups.monitor.data');
    Route::get('/pickups/statistics', [\App\Http\Controllers\Admin\PickupMonitorController::class, 'statistics'])->name('admin.pickups.statistics');
    Route::get('/pickups/{id}/detail', [\App\Http\Controllers\Admin\PickupMonitorController::class, 'show'])->name('admin.pickups.detail');
    Route::get('/pickups/{id}', [\App\Http\Controllers\Admin\PickupMonitorController::class, 'showView'])->name('admin.pickups.show');
    Route::get('/pickups/kelurahan', [\App\Http\Controllers\Admin\PickupMonitorController::class, 'getKelurahan'])->name('admin.pickups.kelurahan');
    Route::post('/pickups/generate-deliveries', [\App\Http\Controllers\Admin\PickupMonitorController::class, 'generateDeliveries'])->name('admin.pickups.generate');
    Route::post('/pickups/{id}/approve', [\App\Http\Controllers\Admin\PickupMonitorController::class, 'approve'])->name('admin.pickups.approve');
    Route::post('/pickups/{id}/reject', [\App\Http\Controllers\Admin\PickupMonitorController::class, 'reject'])->name('admin.pickups.reject');

    // Off-schedule pickup requests
    Route::resource('off-schedule-pickups', OffSchedulePickupController::class, ['as' => 'admin']);
    Route::post('off-schedule-pickups/{id}/assign', [OffSchedulePickupController::class, 'assignCollector'])->name('admin.off-schedule-pickups.assign');
    Route::post('off-schedule-pickups/{id}/status', [OffSchedulePickupController::class, 'updateStatus'])->name('admin.off-schedule-pickups.status');
    Route::post('off-schedule-pickups/{id}/update-cost', [OffSchedulePickupController::class, 'updateCost'])->name('admin.off-schedule-pickups.update-cost');
    Route::post('off-schedule-pickups/{id}/reject', [OffSchedulePickupController::class, 'reject'])->name('admin.off-schedule-pickups.reject');

    // TPA Transports (Log Keluar dari TPS)
    Route::resource('tpa-transports', \App\Http\Controllers\Admin\TpaTransportController::class, ['as' => 'admin']);        // Analytics
    Route::get('/analytics/areas', fn() => View::make('admin.analytics.areas'))->name('admin.analytics.areas');

    // TPS Management
    Route::get('/garbage-dumps/kelurahans', [\App\Http\Controllers\Admin\GarbageDumpController::class, 'getKelurahans'])->name('admin.garbage-dumps.kelurahans');
    Route::get('/garbage-dumps/rws', [\App\Http\Controllers\Admin\GarbageDumpController::class, 'getRws'])->name('admin.garbage-dumps.rws');
    Route::post('/garbage-dumps/{id}/toggle-status', [\App\Http\Controllers\Admin\GarbageDumpController::class, 'toggleStatus'])->name('admin.garbage-dumps.toggle-status');
    Route::resource('garbage-dumps', \App\Http\Controllers\Admin\GarbageDumpController::class, ['as' => 'admin']);

    // TPS Deposits
    Route::get('/tps-deposits', [\App\Http\Controllers\Admin\TpsDepositController::class, 'index'])->name('admin.tps-deposits.index');
    Route::get('/tps-deposits/{tpsDeposit}', [\App\Http\Controllers\Admin\TpsDepositController::class, 'show'])->name('admin.tps-deposits.show');

    // Billing
    Route::resource('invoices', \App\Http\Controllers\Admin\InvoiceController::class, ['as' => 'admin']);
    Route::resource('payments', \App\Http\Controllers\Admin\PaymentController::class, ['as' => 'admin']);
    Route::get('payments/{payment}/download-receipt', [\App\Http\Controllers\Admin\PaymentController::class, 'downloadReceipt'])->name('admin.payments.downloadReceipt');

    // Notifications
    Route::get('/notifications', [\App\Http\Controllers\Admin\NotificationController::class, 'index'])->name('admin.notifications.index');
    Route::get('/notifications/unread', [\App\Http\Controllers\Admin\NotificationController::class, 'getUnread'])->name('admin.notifications.unread');
    Route::post('/notifications/read-all', [\App\Http\Controllers\Admin\NotificationController::class, 'markAllAsRead'])->name('admin.notifications.markAllAsRead');
    Route::delete('/notifications/clear-all', [\App\Http\Controllers\Admin\NotificationController::class, 'clearAll'])->name('admin.notifications.clearAll');
    Route::post('/notifications/{id}/read', [\App\Http\Controllers\Admin\NotificationController::class, 'markAsRead'])->name('admin.notifications.markAsRead');
    Route::delete('/notifications/{id}', [\App\Http\Controllers\Admin\NotificationController::class, 'destroy'])->name('admin.notifications.destroy');

    // Master Data
    Route::resource('areas', AreaController::class, ['as' => 'admin'])->except(['show']);
    Route::resource('rws', \App\Http\Controllers\Admin\RwController::class, ['as' => 'admin'])->except(['show']);
    Route::resource('wastes', \App\Http\Controllers\Admin\WasteController::class, ['as' => 'admin']);
    Route::post('/sampah/size', [\App\Http\Controllers\Admin\WasteController::class, 'storeSize'])->name('admin.sampah.size.store');
    Route::get('/service-accounts/kelurahans', [\App\Http\Controllers\Admin\ServiceAccountController::class, 'getKelurahans'])->name('admin.service-accounts.kelurahans');
    Route::resource('service-accounts', \App\Http\Controllers\Admin\ServiceAccountController::class, ['as' => 'admin']);

    // Settings
    Route::get('/settings', [\App\Http\Controllers\Admin\AppSettingsController::class, 'index'])->name('admin.settings.index');
    Route::post('/settings', [\App\Http\Controllers\Admin\AppSettingsController::class, 'store'])->name('admin.settings.store');

    // Content & Logs
        // Articles
    Route::get('/articles/{article}/preview', [\App\Http\Controllers\Admin\ArticleController::class, 'preview'])->name('admin.articles.preview');
    Route::resource('articles', \App\Http\Controllers\Admin\ArticleController::class, ['as' => 'admin']);
    Route::get('/audit-logs', fn() => View::make('admin.audit_logs.index'))->name('admin.audit_logs.index');
    });
});

Route::get('/storage/{path}', function ($path) {
    $filePath = storage_path('app/public/' . $path);
    if (!file_exists($filePath)) {
        abort(404);
    }
    return response()->file($filePath, [
        'Access-Control-Allow-Origin' => '*',
        'Access-Control-Allow-Methods' => 'GET, HEAD, OPTIONS',
        'Access-Control-Allow-Headers' => '*',
    ]);
})->where('path', '.*');
