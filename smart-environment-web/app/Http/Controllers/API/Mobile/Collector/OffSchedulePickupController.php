<?php

namespace App\Http\Controllers\API\Mobile\Collector;

use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use App\Models\WasteDelivery;
use App\Models\WastePricing;
use App\Models\Waste;
use App\Models\PocketSize;
use App\Services\OffSchedulePickupService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class OffSchedulePickupController extends Controller
{
    public function __construct(private OffSchedulePickupService $service)
    {
    }

    public function index(Request $request)
    {
        $collector = $request->user();

        $query = WasteDelivery::with(['serviceAccount.area', 'serviceAccount.user'])
            ->where('pickup_type', 'request')
            ->where(function ($q) use ($collector) {
                $q->where('assigned_collector_id', $collector->id)
                  ->orWhereNull('assigned_collector_id');
            })
            ->whereNotIn('status', ['cancelled'])
            ->orderByDesc('requested_at');

        if ($status = $request->input('status')) {
            if ($status === 'pending') {
                $query->whereIn('request_status', ['pending', 'sent', 'processing']);
            } else {
                $query->where('request_status', $status);
            }
        }

        $pickups = $query->paginate($request->input('per_page', 15));

        return response()->json([
            'success' => true,
            'data' => $pickups->getCollection()->map(fn ($delivery) => $this->transform($delivery)),
            'meta' => [
                'current_page' => $pickups->currentPage(),
                'last_page' => $pickups->lastPage(),
                'per_page' => $pickups->perPage(),
                'total' => $pickups->total(),
            ],
        ]);
    }

    public function show(Request $request, int $id)
    {
        $delivery = $this->getCollectorDelivery($request->user()->id, $id);

        return response()->json([
            'success' => true,
            'data' => $this->transform($delivery->load(['serviceAccount.area', 'serviceAccount.user'])),
        ]);
    }

    public function complete(Request $request, int $id)
    {
        $delivery = $this->getCollectorDelivery($request->user()->id, $id);

        $data = $request->validate([
            'photo' => 'required|string',
            'collector_notes' => 'nullable|string',
            'waste_items' => 'required|array|min:1',
            'waste_items.*.waste_id' => 'required|exists:wastes,id',
            'waste_items.*.pocket_size_id' => 'required|exists:pocket_sizes,id',
            'waste_items.*.quantity' => 'required|integer|min:1',
        ]);

        DB::beginTransaction();
        try {
            $photoPath = $this->storePhoto($data['photo'], $delivery->id);

            // Calculate totals from waste_items
            $totalAmount = 0;
            $totalBagCount = 0;

            // Clear existing waste items
            $delivery->wasteDeliveryItems()->delete();

            foreach ($data['waste_items'] as $item) {
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
                $totalBagCount += $item['quantity'];
            }

            // Get off-schedule surcharge from app settings
            $settings = AppSetting::first();
            $surcharge = (float) ($settings?->off_schedule_surcharge ?? 0);

            // Calculate final total with surcharge
            $baseAmount = $totalAmount;
            $finalTotal = $baseAmount + $surcharge;

            // Update delivery
            $delivery->update([
                'assigned_collector_id' => $delivery->assigned_collector_id ?? $request->user()->id,
                'bag_count' => $totalBagCount,
                'base_amount' => $baseAmount,
                'extra_fee' => $surcharge,
                'total_amount' => $finalTotal,
                'photo_url' => $photoPath,
                'collector_notes' => $data['collector_notes'] ?? null,
                'collected_at' => now(),
                'status' => 'collected',
                'request_status' => 'pending',
            ]);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Pickup berhasil diperbarui dan menunggu konfirmasi warga',
                'data' => $this->transform($delivery->fresh()->load(['wasteDeliveryItems.waste', 'wasteDeliveryItems.pocketSize'])),
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Gagal menyimpan pickup: ' . $e->getMessage(),
            ], 500);
        }
    }

    public function skip(Request $request, int $id)
    {
        $delivery = $this->getCollectorDelivery($request->user()->id, $id);

        $data = $request->validate([
            'reason' => 'required|string',
            'notes' => 'nullable|string',
        ]);

        $delivery->update([
            'status' => 'cancelled',
            'request_status' => 'rejected',
            'rejection_reason' => $data['reason'],
            'collector_notes' => $data['notes'],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Request dibatalkan oleh kolektor',
            'data' => $this->transform($delivery->fresh()),
        ]);
    }

    protected function getCollectorDelivery(int $collectorId, int $deliveryId): WasteDelivery
    {
        return WasteDelivery::where('pickup_type', 'request')
            ->where('id', $deliveryId)
            ->where(function ($q) use ($collectorId) {
                $q->where('assigned_collector_id', $collectorId)
                  ->orWhereNull('assigned_collector_id');
            })
            ->firstOrFail();
    }

    /**
     * Get waste types and pocket sizes for collector form
     */
    public function getWasteOptions()
    {
        $wastes = Waste::all()->map(fn($w) => [
            'id' => $w->id,
            'name' => $w->name,
        ]);

        $pocketSizes = PocketSize::all()->map(fn($p) => [
            'id' => $p->id,
            'name' => $p->name,
        ]);

        // Get current pricing
        $pricings = WastePricing::where('effective_from', '<=', today())
            ->where(function($q) {
                $q->whereNull('effective_to')
                  ->orWhere('effective_to', '>=', today());
            })
            ->get()
            ->map(fn($p) => [
                'waste_id' => $p->waste_id,
                'pocket_size_id' => $p->pocket_size_id,
                'price' => $p->price,
            ]);

        // Get off-schedule surcharge
        $settings = AppSetting::first();
        $surcharge = (float) ($settings?->off_schedule_surcharge ?? 0);

        return response()->json([
            'success' => true,
            'data' => [
                'wastes' => $wastes,
                'pocket_sizes' => $pocketSizes,
                'pricings' => $pricings,
                'off_schedule_surcharge' => $surcharge,
            ],
        ]);
    }

    protected function transform(WasteDelivery $delivery): array
    {
        return [
            'id' => $delivery->id,
            'service_account' => [
                'id' => $delivery->serviceAccount?->id,
                'name' => $delivery->serviceAccount?->name,
                'address' => $delivery->serviceAccount?->address,
                'latitude' => $delivery->serviceAccount?->latitude,
                'longitude' => $delivery->serviceAccount?->longitude,
                'resident_name' => $delivery->serviceAccount?->user?->name,
                'phone_number' => $delivery->serviceAccount?->contact_phone ?? $delivery->serviceAccount?->user?->phone_number,
            ],
            'requested_pickup_date' => optional($delivery->requested_pickup_date)->toDateString(),
            'requested_pickup_time' => $delivery->requested_pickup_time
                ? substr($delivery->requested_pickup_time, 0, 5)
                : null,
            'bag_count' => $delivery->bag_count,
            'base_amount' => $delivery->base_amount,
            'surcharge' => $delivery->extra_fee,
            'total_amount' => $delivery->total_amount,
            'request_status' => $delivery->request_status,
            'photo_url' => $delivery->photo_url ? Storage::url($delivery->photo_url) : null,
            'collector_notes' => $delivery->collector_notes,
            'resident_note' => $delivery->resident_note,
            'waste_items' => $delivery->wasteDeliveryItems?->map(fn($item) => [
                'waste_id' => $item->waste_id,
                'waste_name' => $item->waste?->name,
                'pocket_size_id' => $item->pocket_size_id,
                'pocket_size_name' => $item->pocketSize?->name,
                'quantity' => $item->quantity,
                'unit_price' => $item->unit_price,
                'total_price' => $item->total_price,
            ]) ?? [],
        ];
    }

    protected function storePhoto(string $base64Image, int $deliveryId): string
    {
        $image = preg_replace('#^data:image/\w+;base64,#i', '', $base64Image);
        $image = str_replace(' ', '+', $image);

        $imageName = 'off_schedule_' . $deliveryId . '_' . time() . '.jpg';

        Storage::disk('public')->put('pickups/' . $imageName, base64_decode($image));

        return 'pickups/' . $imageName;
    }
}
