<?php

namespace App\Http\Controllers\API\Mobile\Resident;

use App\Http\Controllers\Controller;
use App\Models\WasteDelivery;
use App\Models\ServiceAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Carbon\Carbon;

class PickupController extends Controller
{
    /**
     * Daftar pickup yang akan datang untuk resident
     *
     * GET /api/mobile/resident/pickups/upcoming
     */
    public function upcoming(Request $request)
    {
        $resident = $request->user();

        // Jika ada parameter service_account_id, gunakan itu
        // Jika tidak, ambil service account pertama yang active
        $serviceAccountId = $request->input('service_account_id');

        if ($serviceAccountId) {
            // Verifikasi service account milik user ini
            $serviceAccount = ServiceAccount::where('user_id', $resident->id)
                ->where('id', $serviceAccountId)
                ->first();
        } else {
            // Fallback: ambil service account pertama yang active
            $serviceAccount = ServiceAccount::where('user_id', $resident->id)
                ->where('status', 'active')
                ->first();
        }

        if (!$serviceAccount) {
            return response()->json([
                'success' => false,
                'message' => 'Service account tidak ditemukan',
            ], 404);
        }

        // Get upcoming pickups (hari ini dan ke depan)
        $pickups = WasteDelivery::with(['schedule.collectorAssignments.user'])
            ->where('service_account_id', $serviceAccount->id)
            ->where('pickup_date', '>=', today())
            ->whereNotIn('status', ['completed', 'cancelled'])
            ->orderBy('pickup_date', 'asc')
            ->get()
            ->map(function($delivery) {
                $collector = $delivery->collector;

                return [
                    'id' => $delivery->id,
                    'pickup_date' => $delivery->pickup_date ? $delivery->pickup_date->format('Y-m-d') : null,
                    'day_name' => $delivery->pickup_date ? $delivery->pickup_date->translatedFormat('l') : null,
                    'status' => $delivery->status,
                    'confirmation_status' => $delivery->confirmation_status,

                    'schedule_info' => [
                        'day_of_week' => $delivery->schedule->day_of_week,
                        'time_start' => $delivery->schedule->time_start,
                        'time_end' => $delivery->schedule->time_end,
                    ],

                    'collector_info' => $collector ? [
                        'name' => $collector->name,
                        'phone_number' => $collector->phone_number,
                    ] : null,

                    'can_confirm' => $delivery->confirmation_status === 'pending',
                    'resident_note' => $delivery->resident_note,
                    'collector_notes' => $delivery->collector_notes,
                    'total_amount' => $delivery->total_amount,
                    'photo_url' => $delivery->photo_url ? Storage::url($delivery->photo_url) : null,
                    'waste_items' => $delivery->wasteDeliveryItems->map(function($item) {
                        return [
                            'waste_category' => $item->waste?->category ?? 'Unknown',
                            'pocket_size' => $item->pocketSize?->name ?? null,
                            'quantity' => $item->quantity,
                            'unit_price' => $item->unit_price,
                            'total_price' => $item->total_price,
                        ];
                    }),
                ];
            });

        return response()->json([
            'success' => true,
            'data' => $pickups,
        ]);
    }

    /**
     * History pickup yang sudah selesai
     *
     * GET /api/mobile/resident/pickups/history
     */
    public function history(Request $request)
    {
        $resident = $request->user();

        // Jika ada parameter service_account_id, gunakan itu
        // Jika tidak, ambil service account pertama yang active
        $serviceAccountId = $request->input('service_account_id');

        if ($serviceAccountId) {
            // Verifikasi service account milik user ini
            $serviceAccount = ServiceAccount::where('user_id', $resident->id)
                ->where('id', $serviceAccountId)
                ->first();
        } else {
            // Fallback: ambil service account pertama yang active
            $serviceAccount = ServiceAccount::where('user_id', $resident->id)
                ->where('status', 'active')
                ->first();
        }

        if (!$serviceAccount) {
            return response()->json([
                'success' => false,
                'message' => 'Service account tidak ditemukan',
            ], 404);
        }

        $perPage = $request->input('per_page', 20);

        $pickups = WasteDelivery::with(['wasteDeliveryItems.waste', 'wasteDeliveryItems.pocketSize'])
            ->where('service_account_id', $serviceAccount->id)
            ->whereIn('status', ['collected', 'completed', 'cancelled', 'skipped'])
            ->orderBy('pickup_date', 'desc')
            ->paginate($perPage);

        $pickups->getCollection()->transform(function($delivery) {
            return [
                'id' => $delivery->id,
                'pickup_date' => $delivery->pickup_date ? $delivery->pickup_date->format('Y-m-d') : null,
                'status' => $delivery->status,
                'confirmation_status' => $delivery->confirmation_status,
                'total_amount' => $delivery->total_amount,
                'photo_url' => $delivery->photo_url ? Storage::url($delivery->photo_url) : null,
                'collector_notes' => $delivery->collector_notes,

                'waste_items' => $delivery->wasteDeliveryItems->map(function($item) {
                    return [
                        'waste_category' => $item->waste->category,
                        'pocket_size' => $item->pocketSize->name ?? null,
                        'quantity' => $item->quantity,
                        'unit_price' => $item->unit_price,
                        'total_price' => $item->total_price,
                    ];
                }),

                'collected_at' => $delivery->collected_at?->format('Y-m-d H:i:s'),
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $pickups->items(),
            'pagination' => [
                'current_page' => $pickups->currentPage(),
                'last_page' => $pickups->lastPage(),
                'per_page' => $pickups->perPage(),
                'total' => $pickups->total(),
            ],
        ]);
    }

    /**
     * Detail pickup tertentu
     *
     * GET /api/mobile/resident/pickups/{id}
     */
    public function show(Request $request, $id)
    {
        $resident = $request->user();

        // Ambil semua service account milik user
        $serviceAccountIds = ServiceAccount::where('user_id', $resident->id)
            ->where('status', 'active')
            ->pluck('id');

        if ($serviceAccountIds->isEmpty()) {
            return response()->json([
                'success' => false,
                'message' => 'Service account tidak ditemukan',
            ], 404);
        }

        $delivery = WasteDelivery::with([
            'schedule.collectorAssignments.user',
            'wasteDeliveryItems.waste',
            'wasteDeliveryItems.pocketSize',
            'invoice'
        ])
        ->whereIn('service_account_id', $serviceAccountIds)
        ->findOrFail($id);

        $collector = $delivery->collector;

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $delivery->id,
                'pickup_date' => $delivery->pickup_date ? $delivery->pickup_date->format('Y-m-d') : null,
                'status' => $delivery->status,
                'confirmation_status' => $delivery->confirmation_status,

                'schedule_info' => [
                    'day_of_week' => $delivery->schedule->day_of_week,
                    'time_start' => $delivery->schedule->time_start,
                    'time_end' => $delivery->schedule->time_end,
                ],

                'collector_info' => $collector ? [
                    'name' => $collector->name,
                    'phone_number' => $collector->phone_number,
                ] : null,

                'resident_note' => $delivery->resident_note,
                'collector_notes' => $delivery->collector_notes,

                'total_amount' => $delivery->total_amount,
                'photo_url' => $delivery->photo_url ? Storage::url($delivery->photo_url) : null,

                'waste_items' => $delivery->wasteDeliveryItems->map(function($item) {
                    return [
                        'waste_category' => $item->waste->category,
                        'waste_code' => $item->waste->code,
                        'pocket_size' => $item->pocketSize->name ?? null,
                        'quantity' => $item->quantity,
                        'unit_price' => $item->unit_price,
                        'total_price' => $item->total_price,
                    ];
                }),

                'invoice' => $delivery->invoice ? [
                    'invoice_number' => $delivery->invoice->invoice_number,
                    'invoice_date' => ($delivery->invoice->issued_at ?? $delivery->invoice->created_at)?->format('Y-m-d'),
                    'due_date' => $delivery->invoice->va_expiry_at?->format('Y-m-d'),
                    'total_amount' => $delivery->invoice->total_amount,
                    'status' => $delivery->invoice->status,
                ] : null,

                'confirmed_at' => $delivery->confirmed_at?->format('Y-m-d H:i:s'),
                'collected_at' => $delivery->collected_at?->format('Y-m-d H:i:s'),
                'completed_at' => $delivery->completed_at?->format('Y-m-d H:i:s'),
            ],
        ]);
    }

    /**
     * Confirm pickup (warga konfirmasi ada sampah)
     *
     * PUT /api/mobile/resident/pickups/{id}/confirm
     */
    public function confirm(Request $request, $id)
    {
        try {
            $resident = $request->user();

            // Ambil semua service account milik user
            $serviceAccountIds = ServiceAccount::where('user_id', $resident->id)
                ->where('status', 'active')
                ->pluck('id');

            if ($serviceAccountIds->isEmpty()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Service account tidak ditemukan',
                ], 404);
            }

            $validated = $request->validate([
                'confirmation_status' => 'required|in:confirmed,no_waste',
                'resident_note' => 'nullable|string|max:500',
            ]);

            // Cari delivery dari semua service account milik user
            $delivery = WasteDelivery::whereIn('service_account_id', $serviceAccountIds)
                ->find($id);

            if (!$delivery) {
                return response()->json([
                    'success' => false,
                    'message' => 'Pickup tidak ditemukan atau bukan milik Anda',
                ], 404);
            }

            // Cek apakah sudah dikonfirmasi sebelumnya
            if ($delivery->confirmation_status !== 'pending') {
                return response()->json([
                    'success' => false,
                    'message' => 'Pickup sudah dikonfirmasi sebelumnya',
                ], 400);
            }

            $updateData = [
                'confirmation_status' => $validated['confirmation_status'],
                'confirmed_at' => now(),
                'resident_note' => $validated['resident_note'] ?? null,
            ];

            if ($validated['confirmation_status'] === 'no_waste') {
                $updateData['status'] = 'skipped';
            }

            $delivery->update($updateData);

            return response()->json([
                'success' => true,
                'message' => 'Pickup berhasil dikonfirmasi',
                'data' => [
                    'id' => $delivery->id,
                    'confirmation_status' => $delivery->confirmation_status,
                    'confirmed_at' => $delivery->confirmed_at->format('Y-m-d H:i:s'),
                ],
            ]);
        } catch (\Exception $e) {
            \Log::error('Error confirming pickup: ' . $e->getMessage(), [
                'user_id' => $request->user()->id ?? null,
                'pickup_id' => $id,
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan saat mengkonfirmasi pickup',
                'errors' => [
                    'message' => $e->getMessage(),
                ],
            ], 500);
        }
    }

    /**
     * Update note untuk pickup
     *
     * PUT /api/mobile/resident/pickups/{id}/note
     */
    public function updateNote(Request $request, $id)
    {
        $resident = $request->user();

        // Ambil semua service account milik user
        $serviceAccountIds = ServiceAccount::where('user_id', $resident->id)
            ->where('status', 'active')
            ->pluck('id');

        if ($serviceAccountIds->isEmpty()) {
            return response()->json([
                'success' => false,
                'message' => 'Service account tidak ditemukan',
            ], 404);
        }

        $validated = $request->validate([
            'resident_note' => 'required|string|max:500',
        ]);

        $delivery = WasteDelivery::whereIn('service_account_id', $serviceAccountIds)
            ->where('pickup_date', '>=', today())
            ->findOrFail($id);

        $delivery->update([
            'resident_note' => $validated['resident_note'],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Catatan berhasil diupdate',
            'data' => [
                'id' => $delivery->id,
                'resident_note' => $delivery->resident_note,
            ],
        ]);
    }

    /**
     * Get statistics untuk resident dashboard
     *
     * GET /api/mobile/resident/pickups/statistics
     */
    public function statistics(Request $request)
    {
        $resident = $request->user();

        $serviceAccount = ServiceAccount::where('user_id', $resident->id)
            ->where('status', 'active')
            ->first();

        if (!$serviceAccount) {
            return response()->json([
                'success' => false,
                'message' => 'Service account tidak ditemukan',
            ], 404);
        }

        // Get stats untuk bulan ini
        $thisMonth = WasteDelivery::where('service_account_id', $serviceAccount->id)
            ->whereMonth('pickup_date', now()->month)
            ->whereYear('pickup_date', now()->year);

        // Get stats untuk tahun ini
        $thisYear = WasteDelivery::where('service_account_id', $serviceAccount->id)
            ->whereYear('pickup_date', now()->year);

        // Next pickup
        $nextPickup = WasteDelivery::with('schedule')
            ->where('service_account_id', $serviceAccount->id)
            ->where('pickup_date', '>=', today())
            ->whereNotIn('status', ['completed', 'cancelled'])
            ->orderBy('pickup_date', 'asc')
            ->first();

        return response()->json([
            'success' => true,
            'data' => [
                'this_month' => [
                    'total_pickups' => $thisMonth->clone()->where('status', 'completed')->count(),
                    'total_weight' => $thisMonth->clone()->where('status', 'completed')->sum('weight'),
                    'total_amount' => $thisMonth->clone()->where('status', 'completed')->sum('total_amount'),
                ],
                'this_year' => [
                    'total_pickups' => $thisYear->clone()->where('status', 'completed')->count(),
                    'total_weight' => $thisYear->clone()->where('status', 'completed')->sum('weight'),
                    'total_amount' => $thisYear->clone()->where('status', 'completed')->sum('total_amount'),
                ],
                'next_pickup' => $nextPickup ? [
                    'id' => $nextPickup->id,
                    'pickup_date' => $nextPickup->pickup_date ? $nextPickup->pickup_date->format('Y-m-d') : null,
                    'day_name' => $nextPickup->pickup_date ? $nextPickup->pickup_date->translatedFormat('l') : null,
                    'time_range' => $nextPickup->schedule->time_start . ' - ' . $nextPickup->schedule->time_end,
                    'confirmation_status' => $nextPickup->confirmation_status,
                ] : null,
            ],
        ]);
    }
}
