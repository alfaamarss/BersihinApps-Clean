<?php

namespace App\Http\Controllers\API\Mobile\Collector;

use App\Http\Controllers\Controller;
use App\Models\WasteDelivery;
use App\Models\Waste;
use App\Models\WastePricing;
use App\Models\PocketSize;
use App\Models\Invoice;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Log;

class PickupController extends Controller
{
    /**
     * Daftar pickup hari ini untuk collector
     *
     * GET /api/mobile/collector/pickups/today
     */
    public function today(Request $request)
    {
        try {
            $collector = $request->user();
            
            if (!$collector) {
                return response()->json([
                    'success' => false,
                    'message' => 'Unauthorized',
                ], 401);
            }

            Log::info("Fetching today pickups for collector {$collector->id}");

            // Get waste deliveries untuk collector ini berdasarkan assignment
            $pickups = WasteDelivery::with([
                'serviceAccount.user',
                'serviceAccount.area',
                'serviceAccount.rw',
                'schedule',
                'wasteDeliveryItems.waste',
                'wasteDeliveryItems.pocketSize'
            ])
            ->whereNotNull('schedule_id') // Pastikan ada schedule
            ->whereHas('schedule', function($q) {
                $q->whereNotNull('id'); // Schedule exists
            })
            ->whereHas('schedule.collectorAssignments', function($q) use ($collector) {
                $q->where('user_id', $collector->id)
                  ->where('start_date', '<=', now())
                  ->where(function($q) {
                      $q->whereNull('end_date')
                        ->orWhere('end_date', '>=', now());
                  });
            })
            // Uncomment line below to filter only active service accounts
            // ->whereHas('serviceAccount', function($q) {
            //     $q->where('status', 'active');
            // })
            ->where('pickup_date', today())
            ->whereNotIn('status', ['completed', 'cancelled', 'skipped'])
            ->whereNotIn('confirmation_status', ['no_waste', 'skipped'])
            ->get();

            // On-demand fallback: Jika belum ada delivery hari ini, generate otomatis dari schedule collector
            if ($pickups->isEmpty()) {
                try {
                    $generator = app(\App\Services\WasteDeliveryGeneratorService::class);
                    $assignments = \App\Models\CollectorAssignment::with('schedule')
                        ->where('user_id', $collector->id)
                        ->where('start_date', '<=', now())
                        ->where(function($q) {
                            $q->whereNull('end_date')->orWhere('end_date', '>=', now());
                        })
                        ->get();

                    $generatedAny = false;
                    foreach ($assignments as $assignment) {
                        if ($assignment->schedule && $assignment->schedule->is_active) {
                            $count = $generator->generateForSchedule($assignment->schedule, 1);
                            if ($count > 0) {
                                $generatedAny = true;
                            }
                        }
                    }

                    if ($generatedAny) {
                        $pickups = WasteDelivery::with([
                            'serviceAccount.user',
                            'serviceAccount.area',
                            'serviceAccount.rw',
                            'schedule',
                            'wasteDeliveryItems.waste',
                            'wasteDeliveryItems.pocketSize'
                        ])
                        ->whereNotNull('schedule_id')
                        ->whereHas('schedule', function($q) {
                            $q->whereNotNull('id');
                        })
                        ->whereHas('schedule.collectorAssignments', function($q) use ($collector) {
                            $q->where('user_id', $collector->id)
                              ->where('start_date', '<=', now())
                              ->where(function($q) {
                                  $q->whereNull('end_date')->orWhere('end_date', '>=', now());
                              });
                        })
                        ->where('pickup_date', today())
                        ->whereNotIn('status', ['completed', 'cancelled', 'skipped'])
                        ->whereNotIn('confirmation_status', ['no_waste', 'skipped'])
                        ->get();
                    }
                } catch (\Exception $e) {
                    Log::warning("On-demand delivery generation fallback error: " . $e->getMessage());
                }
            }

            $results = $pickups->map(function($delivery) use ($request) {
                // Safety check untuk relasi
                if (!$delivery->serviceAccount || !$delivery->schedule) {
                    Log::warning("Delivery {$delivery->id} missing serviceAccount or schedule");
                    return null;
                }
            return [
                'id' => $delivery->id,
                'service_account_id' => $delivery->service_account_id,
                'schedule_id' => $delivery->schedule_id,
                'pickup_date' => $delivery->pickup_date ? $delivery->pickup_date->format('Y-m-d') : null,

                'house_info' => [
                    'account_number' => $delivery->serviceAccount->name ?? 'N/A',
                    'address' => $delivery->serviceAccount->address ?? 'Alamat tidak tersedia',
                    'resident_name' => optional($delivery->serviceAccount->user)->name ?? 'N/A',
                    'phone_number' => $delivery->serviceAccount->contact_phone ?? optional($delivery->serviceAccount->user)->phone_number ?? 'N/A',
                    'area' => optional($delivery->serviceAccount->area)->name ?? 'N/A',
                    'rw' => optional($delivery->serviceAccount->rw)->name,
                    'latitude' => $delivery->serviceAccount->latitude ?? 0,
                    'longitude' => $delivery->serviceAccount->longitude ?? 0,
                ],
                'service_account' => [
                    'id' => $delivery->serviceAccount->id,
                    'name' => $delivery->serviceAccount->name,
                    'account_number' => $delivery->serviceAccount->account_number ?? $delivery->serviceAccount->name,
                    'address' => $delivery->serviceAccount->address,
                    'contact_phone' => $delivery->serviceAccount->contact_phone,
                    'latitude' => $delivery->serviceAccount->latitude,
                    'longitude' => $delivery->serviceAccount->longitude,
                ],

                'status' => $delivery->status,
                'confirmation_status' => $delivery->confirmation_status,

                'waste_types' => $delivery->wasteDeliveryItems->groupBy('waste_id')->map(function($items) {
                    return [
                        'type' => $items->first()->waste->category ?? 'Unknown',
                        'count' => $items->sum('quantity'),
                    ];
                })->values(),

                'distance' => $this->calculateDistance(
                    $request->input('latitude'),
                    $request->input('longitude'),
                    $delivery->serviceAccount->latitude,
                    $delivery->serviceAccount->longitude
                ),

                'resident_note' => $delivery->resident_note,
            ];
        })
        ->filter() // Remove null entries
        ->sortBy('distance')
        ->values();

            $summary = [
                'total' => $pickups->count(),
                'confirmed' => $pickups->where('confirmation_status', 'confirmed')->count(),
                'pending' => $pickups->where('confirmation_status', 'pending')->count(),
                'skipped' => $pickups->where('confirmation_status', 'skipped')->count(),
                'no_waste' => $pickups->where('confirmation_status', 'no_waste')->count(),
            ];

            Log::info("Found {$pickups->count()} pickups for collector {$collector->id}");

            return response()->json([
                'success' => true,
                'summary' => $summary,
                'items' => $results,
            ]);
            
        } catch (\Exception $e) {
            Log::error("Error fetching today pickups: " . $e->getMessage());
            Log::error("Stack trace: " . $e->getTraceAsString());
            
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan saat mengambil data pickup: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Detail pickup tertentu
     *
     * GET /api/mobile/collector/pickups/{id}
     */
    public function show(Request $request, $id)
    {
        $collector = $request->user();

        $delivery = WasteDelivery::with([
            'serviceAccount.user',
            'serviceAccount.area',
            'schedule',
            'wasteDeliveryItems.waste',
            'wasteDeliveryItems.pocketSize'
        ])
        ->whereHas('schedule.collectorAssignments', function($q) use ($collector) {
            $q->where('user_id', $collector->id)
              ->where('start_date', '<=', now())
              ->where(function($q) {
                  $q->whereNull('end_date')
                    ->orWhere('end_date', '>=', now());
              });
        })
        // Uncomment line below to filter only active service accounts
        // ->whereHas('serviceAccount', function($q) {
        //     $q->where('status', 'active');
        // })
        ->findOrFail($id);

        // Get history pickups dari service account ini
        $history = WasteDelivery::where('service_account_id', $delivery->service_account_id)
            ->where('status', 'completed')
            ->orderBy('pickup_date', 'desc')
            ->limit(5)
            ->get()
            ->map(function($item) {
                return [
                    'date' => $item->pickup_date->format('Y-m-d'),
                    'status' => $item->status,
                    'amount' => $item->total_amount,
                ];
            });

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $delivery->id,
                'service_account_id' => $delivery->service_account_id,
                'pickup_date' => $delivery->pickup_date ? $delivery->pickup_date->format('Y-m-d') : null,

                'house_info' => [
                    'account_number' => $delivery->serviceAccount->account_number,
                    'address' => $delivery->serviceAccount->full_address,
                    'resident_name' => $delivery->serviceAccount->user->name,
                    'phone_number' => $delivery->serviceAccount->user->phone_number,
                    'area' => $delivery->serviceAccount->area->name,
                ],

                'waste_info' => [
                    'types' => Waste::all()->map(function($waste) {
                        return [
                            'id' => $waste->id,
                            'code' => $waste->code,
                            'category' => $waste->category,
                        ];
                    }),
                    'pocket_sizes' => PocketSize::all()->map(function($size) {
                        return [
                            'id' => $size->id,
                            'name' => $size->name,
                            'size' => $size->size,
                        ];
                    }),
                ],

                'status' => $delivery->status,
                'confirmation_status' => $delivery->confirmation_status,
                'resident_note' => $delivery->resident_note,
                'collector_notes' => $delivery->collector_notes,
                'photo_url' => $delivery->photo_url ? Storage::url($delivery->photo_url) : null,

                'history' => $history,
            ],
        ]);
    }

    /**
     * Mark pickup sebagai on the way / in progress
     *
     * PUT /api/mobile/collector/pickups/{id}/start
     */
    public function start(Request $request, $id)
    {
        $collector = $request->user();

        $delivery = WasteDelivery::whereHas('schedule.collectorAssignments', function($q) use ($collector) {
            $q->where('user_id', $collector->id)
              ->where('start_date', '<=', now())
              ->where(function($q) {
                  $q->whereNull('end_date')
                    ->orWhere('end_date', '>=', now());
              });
        })
        // Uncomment line below to filter only active service accounts
        // ->whereHas('serviceAccount', function($q) {
        //     $q->where('status', 'active');
        // })
        ->findOrFail($id);

        $delivery->update([
            'status' => 'in_progress',
            // 'confirmation_status' => 'confirmed', // Auto-confirm when collector starts pickup
            // 'confirmed_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Pickup started',
            'data' => [
                'id' => $delivery->id,
                'status' => $delivery->status,
            ],
        ]);
    }

    /**
     * Complete pickup dengan foto dan berat
     *
     * PUT /api/mobile/collector/pickups/{id}/complete
     */
    public function complete(Request $request, $id)
    {
        $collector = $request->user();

        // Verify delivery belongs to this collector
        $delivery = WasteDelivery::with(['serviceAccount', 'schedule'])
            ->whereHas('schedule.collectorAssignments', function($q) use ($collector) {
                $q->where('user_id', $collector->id)
                  ->where('start_date', '<=', now())
                  ->where(function($q) {
                      $q->whereNull('end_date')
                        ->orWhere('end_date', '>=', now());
                  });
            })
            // Uncomment line below to filter only active service accounts
            // ->whereHas('serviceAccount', function($q) {
            //     $q->where('status', 'active');
            // })
            ->findOrFail($id);

        $validated = $request->validate([
            'photo' => 'required|string',
            'collector_notes' => 'nullable|string',
            'waste_items' => 'required|array',
            'waste_items.*.waste_id' => 'required|exists:wastes,id',
            'waste_items.*.pocket_size_id' => 'required|exists:pocket_sizes,id',
            'waste_items.*.quantity' => 'required|integer|min:1',
        ]);

        DB::beginTransaction();
        try {
            // Upload photo
            $photoPath = $this->uploadPhoto($validated['photo'], $delivery->id);

            // Update delivery
            $delivery->update([
                'status' => 'collected',
                'confirmation_status' => 'pending', // Menunggu konfirmasi warga
                'confirmed_at' => null, // Reset confirmed_at jika sebelumnya terisi
                'collected_at' => now(),
                'photo_url' => $photoPath,
                'collector_notes' => $validated['collector_notes'] ?? null,
            ]);

            // Save waste items
            $delivery->wasteDeliveryItems()->delete(); // Clear existing items

            $totalAmount = 0;
            $totalBagCount = 0;
            foreach ($validated['waste_items'] as $item) {
                // Get current pricing
                $pricing = WastePricing::where('waste_id', $item['waste_id'])
                    ->where('pocket_size_id', $item['pocket_size_id'])
                    ->where('effective_from', '<=', today())
                    ->where(function($q) {
                        $q->whereNull('effective_to')
                          ->orWhere('effective_to', '>=', today());
                    })
                    ->first();

                $unitPrice = $pricing ? $pricing->price : 0;
                $itemTotal = $item['quantity'] * $unitPrice;

                $delivery->wasteDeliveryItems()->create([
                    'waste_id' => $item['waste_id'],
                    'pocket_size_id' => $item['pocket_size_id'],
                    'quantity' => $item['quantity'],
                    'unit_price' => $unitPrice,
                    'total_price' => $itemTotal,
                ]);

                $totalAmount += $itemTotal;
                $totalBagCount += (int) $item['quantity'];
            }

            // Update total amount, base amount, and bag count
            $extraFee = (float) ($delivery->extra_fee ?? 0);
            $delivery->update([
                'bag_count' => $totalBagCount,
                'base_amount' => $totalAmount,
                'total_amount' => $totalAmount + $extraFee,
            ]);

            // Generate invoice
            $invoice = $delivery->invoice()->create([
                'service_account_id' => $delivery->service_account_id,
                'invoice_number' => $this->generateInvoiceNumber(),
                'issued_at' => now(),
                'total_amount' => $totalAmount,
                'status' => 'not_paid',
            ]);

            DB::commit();

            Log::info("Pickup completed by collector {$collector->id} for delivery {$delivery->id}");

            return response()->json([
                'success' => true,
                'message' => 'Pickup berhasil disimpan, menunggu konfirmasi warga',
                'data' => [
                    'waste_delivery_id' => $delivery->id,
                    'status' => $delivery->status,
                    'collected_at' => $delivery->collected_at->format('Y-m-d H:i:s'),
                    'total_amount' => $totalAmount,
                    'invoice_id' => $invoice->id,
                    'invoice_number' => $invoice->invoice_number,
                    'photo_url' => $delivery->photo_url ? Storage::url($delivery->photo_url) : null,
                ],
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error("Failed to complete pickup: {$e->getMessage()}");

            return response()->json([
                'success' => false,
                'message' => 'Gagal konfirmasi pickup: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Skip pickup (warga tidak ada sampah / tidak di rumah)
     *
     * PUT /api/mobile/collector/pickups/{id}/skip
     */
    public function skip(Request $request, $id)
    {
        $collector = $request->user();

        $validated = $request->validate([
            'reason' => 'required|in:no_waste,not_home,other',
            'notes' => 'nullable|string',
        ]);

        $delivery = WasteDelivery::whereHas('schedule.collectorAssignments', function($q) use ($collector) {
            $q->where('user_id', $collector->id)
              ->where('start_date', '<=', now())
              ->where(function($q) {
                  $q->whereNull('end_date')
                    ->orWhere('end_date', '>=', now());
              });
        })
        // Uncomment line below to filter only active service accounts
        // ->whereHas('serviceAccount', function($q) {
        //     $q->where('status', 'active');
        // })
        ->findOrFail($id);

        $delivery->update([
            'status' => 'skipped',
            'confirmation_status' => $validated['reason'] === 'no_waste' ? 'no_waste' : 'skipped',
            'collector_notes' => $validated['notes'] ?? null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Pickup ditandai sebagai skip',
            'data' => [
                'id' => $delivery->id,
                'status' => $delivery->status,
                'confirmation_status' => $delivery->confirmation_status,
            ],
        ]);
    }

    /**
     * Helper: Upload photo
     */
    private function uploadPhoto($base64Image, $deliveryId)
    {
        $image = str_replace('data:image/jpeg;base64,', '', $base64Image);
        $image = str_replace('data:image/png;base64,', '', $image);
        $image = str_replace(' ', '+', $image);

        $imageName = 'pickup_' . $deliveryId . '_' . time() . '.jpg';

        Storage::disk('public')->put('pickups/' . $imageName, base64_decode($image));

        return 'pickups/' . $imageName; // Return relative path without 'storage/' prefix
    }

    /**
     * Helper: Generate invoice number
     */
    private function generateInvoiceNumber(): string
    {
        $prefix = 'INV';
        $date = now()->format('Ymd');
        $lastInvoice = Invoice::whereDate('created_at', today())
            ->lockForUpdate()
            ->orderBy('id', 'desc')
            ->first();

        $sequence = 1;
        if ($lastInvoice && preg_match('/-(\d{4})(?:-\d+)?$/', $lastInvoice->invoice_number, $matches)) {
            $sequence = intval($matches[1]) + 1;
        } elseif ($lastInvoice) {
            $sequence = $lastInvoice->id + 1;
        }

        $entropy = str_pad((string) random_int(100, 999), 3, '0', STR_PAD_LEFT);
        return $prefix . '-' . $date . '-' . str_pad((string) $sequence, 4, '0', STR_PAD_LEFT) . '-' . $entropy;
    }

    /**
     * Riwayat pengambilan yang sudah completed untuk collector
     *
     * GET /api/mobile/collector/pickups/history
     */
    public function history(Request $request)
    {
        try {
            $collector = $request->user();
            
            if (!$collector) {
                return response()->json([
                    'success' => false,
                    'message' => 'Unauthorized',
                ], 401);
            }

            $limit = $request->input('limit', 20);

            Log::info("Fetching pickup history for collector {$collector->id}, limit: {$limit}");

            // Get completed pickups untuk collector ini (baik reguler maupun off-schedule)
            $pickups = WasteDelivery::with([
                'serviceAccount.user',
                'serviceAccount.area',
                'schedule.collectorAssignments',
                'wasteDeliveryItems.waste',
                'wasteDeliveryItems.pocketSize'
            ])
            ->where(function($q) use ($collector) {
                // Pickup terjadwal reguler
                $q->where(function($sub) use ($collector) {
                    $sub->whereNotNull('schedule_id')
                        ->whereHas('schedule.collectorAssignments', function($a) use ($collector) {
                            $a->where('user_id', $collector->id);
                        });
                })
                // ATAU pickup luar jadwal (request) yang ditugaskan ke kolektor ini
                ->orWhere(function($sub) use ($collector) {
                    $sub->where('pickup_type', 'request')
                        ->where('assigned_collector_id', $collector->id);
                });
            })
            ->whereIn('status', ['collected', 'completed'])
            ->orderByRaw('COALESCE(collected_at, pickup_date, requested_pickup_date, created_at) DESC')
            ->limit($limit)
            ->get()
            ->filter(function($delivery) use ($collector) {
                if (!$delivery->serviceAccount) {
                    Log::warning("Delivery {$delivery->id} in history missing serviceAccount");
                    return false;
                }

                // Jika off-schedule / request
                if ($delivery->pickup_type === 'request' || !$delivery->schedule_id) {
                    return $delivery->assigned_collector_id == $collector->id;
                }
                
                // Check apakah ada assignment untuk collector ini pada tanggal pickup
                $hasAssignment = $delivery->schedule?->collectorAssignments
                    ->where('user_id', $collector->id)
                    ->filter(function($assignment) use ($delivery) {
                        $pickupDate = $delivery->pickup_date;
                        if (!$pickupDate) return true;
                        $startDate = \Carbon\Carbon::parse($assignment->start_date);
                        $endDate = $assignment->end_date ? \Carbon\Carbon::parse($assignment->end_date) : null;
                        
                        // Check if assignment was active on pickup date
                        $afterStart = $pickupDate >= $startDate;
                        $beforeEnd = $endDate === null || $pickupDate <= $endDate;
                        
                        return $afterStart && $beforeEnd;
                    })
                    ->isNotEmpty();
                
                return $hasAssignment ?? false;
            })
            ->take($limit)
            ->map(function($delivery) {
            $wasteItems = $delivery->wasteDeliveryItems->map(function($item) {
                return [
                    'waste_category' => $item->waste->category ?? 'Unknown',
                    'pocket_size' => $item->pocketSize->name ?? 'N/A',
                    'quantity' => $item->quantity,
                    'unit_price' => (float) $item->unit_price,
                    'total_price' => (float) $item->total_price,
                ];
            });

            $effectiveDate = $delivery->pickup_date ?? $delivery->requested_pickup_date;

            return [
                'id' => $delivery->id,
                'service_account_id' => $delivery->service_account_id,
                'pickup_date' => $effectiveDate ? $effectiveDate->format('Y-m-d') : null,
                'day_name' => $effectiveDate ? $this->getDayName($effectiveDate->dayOfWeek) : null,
                'pickup_type' => $delivery->pickup_type ?? 'scheduled',

                'house_info' => [
                    'account_number' => $delivery->serviceAccount->name ?? 'N/A',
                    'address' => $delivery->serviceAccount->address ?? 'N/A',
                    'resident_name' => optional($delivery->serviceAccount->user)->name ?? 'N/A',
                    'area' => optional($delivery->serviceAccount->area)->name ?? 'N/A',
                ],

                'status' => $delivery->status,
                'confirmation_status' => $delivery->confirmation_status,
                'total_amount' => (float) $delivery->total_amount,

                'waste_items' => $wasteItems,
                'photo_url' => $delivery->photo_url ? Storage::url($delivery->photo_url) : null,
                'collector_notes' => $delivery->collector_notes,
                'resident_note' => $delivery->resident_note,
            ];
        })
        ->filter() // Remove null entries
        ->values();

            Log::info("Found {$pickups->count()} history pickups for collector {$collector->id}");

            return response()->json([
                'success' => true,
                'data' => $pickups,
            ]);
            
        } catch (\Exception $e) {
            Log::error("Error fetching pickup history: " . $e->getMessage());
            Log::error("Stack trace: " . $e->getTraceAsString());
            
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan saat mengambil riwayat pickup: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Helper: Get day name in Indonesian
     */
    private function getDayName($dayOfWeek)
    {
        $days = [
            1 => 'Senin',
            2 => 'Selasa',
            3 => 'Rabu',
            4 => 'Kamis',
            5 => 'Jumat',
            6 => 'Sabtu',
            0 => 'Minggu',
        ];
        return $days[$dayOfWeek] ?? 'N/A';
    }

    /**
     * Helper: Calculate distance between two coordinates
     */
    /**
     * Get waste items with current pricing
     *
     * GET /api/mobile/collector/waste-items
     */
    public function wasteItems(Request $request)
    {
        $wastes = Waste::all();
        $pocketSizes = PocketSize::all();

        $items = [];
        foreach ($wastes as $waste) {
            foreach ($pocketSizes as $size) {
                // Get current pricing
                $pricing = WastePricing::where('waste_id', $waste->id)
                    ->where('pocket_size_id', $size->id)
                    ->where('effective_from', '<=', today())
                    ->where(function($q) {
                        $q->whereNull('effective_to')
                          ->orWhere('effective_to', '>=', today());
                    })
                    ->first();

                $items[] = [
                    'waste_id' => $waste->id,
                    'waste_code' => $waste->code,
                    'waste_category' => $waste->category,
                    'pocket_size_id' => $size->id,
                    'pocket_size_name' => $size->name,
                    'name' => ucfirst($waste->category) . ' ' . $size->name,
                    'price' => $pricing ? (float) $pricing->price : 0.0,
                ];
            }
        }

        return response()->json([
            'success' => true,
            'data' => $items,
        ]);
    }

    private function calculateDistance($lat1, $lon1, $lat2, $lon2)
    {
        if (!$lat1 || !$lon1 || !$lat2 || !$lon2) {
            return null;
        }

        $earthRadius = 6371; // km

        $latDiff = deg2rad($lat2 - $lat1);
        $lonDiff = deg2rad($lon2 - $lon1);

        $a = sin($latDiff / 2) * sin($latDiff / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($lonDiff / 2) * sin($lonDiff / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        $distance = $earthRadius * $c;

        return round($distance, 1) . ' km';
    }
}
