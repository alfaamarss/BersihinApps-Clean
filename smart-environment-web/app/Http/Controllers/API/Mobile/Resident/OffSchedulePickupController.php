<?php

namespace App\Http\Controllers\API\Mobile\Resident;

use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use App\Models\ServiceAccount;
use App\Models\WasteDelivery;
use App\Notifications\Admin\NewPickupRequestNotification;
use App\Services\NotificationService;
use App\Services\OffSchedulePickupService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class OffSchedulePickupController extends Controller
{
    public function __construct(private OffSchedulePickupService $service)
    {
    }

    /**
     * Get pricing info including off-schedule surcharge
     * Allows resident to see additional fee before creating request
     */
    public function getPricingInfo()
    {
        $settings = AppSetting::first();
        $surcharge = (float) ($settings?->off_schedule_surcharge ?? 0);

        return response()->json([
            'success' => true,
            'data' => [
                'off_schedule_surcharge' => $surcharge,
                'surcharge_label' => 'Biaya tambahan pickup di luar jadwal',
                'note' => 'Biaya ini akan ditambahkan ke total tagihan Anda untuk setiap request pickup di luar jadwal.',
            ],
        ]);
    }

    /**
     * Preview scheduled pickups that will be skipped if skip_next_scheduled is enabled
     * Allows resident to see what pickups will be cancelled before creating request
     */
    public function previewSkipScheduled(Request $request)
    {
        $resident = $request->user();

        $data = $request->validate([
            'service_account_id' => 'required|exists:service_accounts,id',
            'requested_pickup_date' => 'required|date|after_or_equal:today',
        ]);

        // Verify service account belongs to resident
        $serviceAccount = ServiceAccount::query()
            ->where('id', $data['service_account_id'])
            ->where('user_id', $resident->id)
            ->first();

        if (!$serviceAccount) {
            return response()->json([
                'success' => false,
                'message' => 'Service account tidak ditemukan atau bukan milik Anda.',
            ], 404);
        }

        $requestedDate = Carbon::parse($data['requested_pickup_date'])->startOfDay();
        
        $scheduledPickups = $this->service->getNextScheduledPickupsInWeek(
            $serviceAccount->id,
            $requestedDate
        );

        return response()->json([
            'success' => true,
            'data' => [
                'requested_pickup_date' => $requestedDate->toDateString(),
                'week_end_date' => $requestedDate->copy()->endOfWeek(Carbon::SUNDAY)->toDateString(),
                'scheduled_pickups_to_skip' => $scheduledPickups->map(fn ($pickup) => [
                    'id' => $pickup->id,
                    'pickup_date' => $pickup->pickup_date->toDateString(),
                    'day_name' => $pickup->pickup_date->translatedFormat('l'),
                    'schedule_time' => $pickup->schedule?->pickup_time 
                        ? Carbon::parse($pickup->schedule->pickup_time)->format('H:i')
                        : null,
                    'status' => $pickup->status,
                ]),
                'total_pickups_to_skip' => $scheduledPickups->count(),
                'note' => $scheduledPickups->count() > 0 
                    ? 'Jadwal pickup di atas akan di-skip jika Anda memilih opsi skip_next_scheduled.'
                    : 'Tidak ada jadwal pickup yang akan di-skip dalam minggu ini.',
            ],
        ]);
    }

    /**
     * Check if a specific date has scheduled pickup
     * Allows mobile app to validate before submitting request
     * 
     * GET /api/v1/mobile/resident/off-schedule-pickups/check-date
     */
    public function checkDate(Request $request)
    {
        $resident = $request->user();

        $data = $request->validate([
            'service_account_id' => 'required|exists:service_accounts,id',
            'date' => 'required|date|after_or_equal:today',
        ]);

        // Verify service account belongs to resident
        $serviceAccount = ServiceAccount::query()
            ->where('id', $data['service_account_id'])
            ->where('user_id', $resident->id)
            ->first();

        if (!$serviceAccount) {
            return response()->json([
                'success' => false,
                'message' => 'Service account tidak ditemukan atau bukan milik Anda.',
            ], 404);
        }

        $requestedDate = Carbon::parse($data['date'])->startOfDay();
        
        // Check if there's a scheduled pickup on this date
        $hasScheduledPickup = WasteDelivery::query()
            ->where('service_account_id', $serviceAccount->id)
            ->where('pickup_type', 'scheduled')
            ->whereDate('pickup_date', $requestedDate)
            ->whereNotIn('status', ['cancelled', 'skipped'])
            ->whereNotIn('confirmation_status', ['skipped', 'no_waste'])
            ->exists();

        return response()->json([
            'success' => true,
            'data' => [
                'date' => $requestedDate->toDateString(),
                'day_name' => $requestedDate->translatedFormat('l'),
                'has_scheduled_pickup' => $hasScheduledPickup,
                'can_request' => !$hasScheduledPickup,
                'message' => $hasScheduledPickup 
                    ? 'Tanggal ini sudah ada jadwal pengambilan rutin. Silakan pilih tanggal lain.'
                    : 'Tanggal ini tersedia untuk request pengambilan.',
            ],
        ]);
    }

    public function index(Request $request)
    {
        $resident = $request->user();

        $query = WasteDelivery::with(['serviceAccount.area', 'assignedCollector', 'invoice'])
            ->whereHas('serviceAccount', function ($q) use ($resident) {
                $q->where('user_id', $resident->id);
            })
            ->where('pickup_type', 'request')
            ->latest('requested_at');

        if ($status = $request->input('status')) {
            $query->where('request_status', $status);
        }

        $requests = $query->paginate($request->input('per_page', 15));

        return response()->json([
            'success' => true,
            'data' => $requests->getCollection()->map(fn ($delivery) => $this->transform($delivery)),
            'meta' => [
                'current_page' => $requests->currentPage(),
                'last_page' => $requests->lastPage(),
                'per_page' => $requests->perPage(),
                'total' => $requests->total(),
            ],
        ]);
    }

    public function store(Request $request)
    {
        $resident = $request->user();

        if ($request->filled('requested_pickup_time') && is_string($request->input('requested_pickup_time'))) {
            $timeStr = trim($request->input('requested_pickup_time'));
            if (preg_match('/^(\d{1,2}:\d{2})/', $timeStr, $matches)) {
                $timeParts = explode(':', $matches[1]);
                $request->merge(['requested_pickup_time' => sprintf('%02d:%02d', (int)$timeParts[0], (int)$timeParts[1])]);
            }
        }

        $data = $request->validate([
            'service_account_id' => 'required|exists:service_accounts,id',
            'requested_pickup_date' => 'required|date|after_or_equal:today',
            'requested_pickup_time' => 'nullable|date_format:H:i',
            'resident_note' => 'nullable|string',
            'skip_next_scheduled' => 'nullable|boolean',
        ]);

        $result = $this->service->createRequest($resident, $data);

        // Handle result - bisa delivery saja atau dengan skipped pickups
        if (is_array($result)) {
            [$delivery, $skippedPickups] = $result;
        } else {
            $delivery = $result;
            $skippedPickups = [];
        }

        $response = [
            'success' => true,
            'message' => 'Request pengambilan berhasil dikirim',
            'data' => $this->transform($delivery),
        ];

        if (!empty($skippedPickups)) {
            $response['skipped_pickups'] = collect($skippedPickups)->map(fn ($pickup) => [
                'id' => $pickup->id,
                'pickup_date' => $pickup->pickup_date->toDateString(),
                'day_name' => $pickup->pickup_date->translatedFormat('l'),
            ]);
            $response['message'] = 'Request pengambilan berhasil dikirim. Jadwal pickup berikutnya dalam minggu ini telah di-skip.';
        }

        // Send notification to admins about new pickup request
        try {
            $notificationService = app(NotificationService::class);
            $notificationService->sendToAdmins(new NewPickupRequestNotification($delivery));
        } catch (\Exception $e) {
            Log::error('Failed to send new pickup request notification: ' . $e->getMessage());
        }

        return response()->json($response, 201);
    }

    public function show(Request $request, int $id)
    {
        $delivery = $this->getResidentDelivery($request->user()->id, $id);

        return response()->json([
            'success' => true,
            'data' => $this->transform($delivery->load(['invoice', 'assignedCollector', 'serviceAccount.area'])),
        ]);
    }

    public function confirm(Request $request, int $id)
    {
        $delivery = $this->getResidentDelivery($request->user()->id, $id);

        if ($delivery->request_status !== 'pending') {
            throw ValidationException::withMessages([
                'status' => 'Request ini belum dapat dikonfirmasi.',
            ]);
        }

        [$updatedDelivery, $invoice] = $this->service->markResidentConfirmation($delivery);

        return response()->json([
            'success' => true,
            'message' => 'Pickup dikonfirmasi, silakan lanjutkan pembayaran',
            'data' => array_merge(
                $this->transform($updatedDelivery),
                [
                    'invoice' => $invoice ? [
                        'id' => $invoice->id,
                        'invoice_number' => $invoice->invoice_number,
                        'status' => $invoice->status,
                        'total_amount' => $invoice->total_amount,
                    ] : null,
                ]
            ),
        ]);
    }

    protected function getResidentDelivery(int $residentId, int $deliveryId): WasteDelivery
    {
        return WasteDelivery::where('pickup_type', 'request')
            ->where('id', $deliveryId)
            ->whereHas('serviceAccount', function ($q) use ($residentId) {
                $q->where('user_id', $residentId);
            })
            ->firstOrFail();
    }

    protected function transform(WasteDelivery $delivery): array
    {
        return [
            'id' => $delivery->id,
            'service_account_id' => $delivery->service_account_id,
            'service_account_name' => $delivery->serviceAccount?->name,
            'address' => $delivery->serviceAccount?->address,
            'pickup_type' => $delivery->pickup_type,
            'request_status' => $delivery->request_status,
            'status' => $delivery->status,
            'bag_count' => $delivery->bag_count,
            'unit_price' => $delivery->unit_price_snapshot,
            'base_amount' => $delivery->base_amount,
            'extra_fee' => $delivery->extra_fee,
            'total_amount' => $delivery->total_amount,
            'requested_at' => optional($delivery->requested_at)->toIso8601String(),
            'requested_pickup_date' => optional($delivery->requested_pickup_date)->toDateString(),
            'requested_pickup_time' => $delivery->requested_pickup_time
                ? substr($delivery->requested_pickup_time, 0, 5)
                : null,
            'assigned_collector' => $delivery->assignedCollector?->only(['id', 'name']),
            'rejection_reason' => $delivery->rejection_reason,
            'photo_url' => $delivery->photo_url ? Storage::url($delivery->photo_url) : null,
            'invoice' => $delivery->invoice ? [
                'id' => $delivery->invoice->id,
                'status' => $delivery->invoice->status,
                'total_amount' => $delivery->invoice->total_amount,
            ] : null,
        ];
    }
}
