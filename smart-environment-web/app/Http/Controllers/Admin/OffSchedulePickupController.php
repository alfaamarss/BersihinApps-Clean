<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\WasteDelivery;
use App\Services\OffSchedulePickupService;
use Illuminate\Http\Request;

class OffSchedulePickupController extends Controller
{
    public function __construct(private OffSchedulePickupService $service)
    {
    }

    public function index(Request $request)
    {
        $query = WasteDelivery::with(['serviceAccount.area', 'assignedCollector', 'invoice', 'wasteDeliveryItems'])
            ->where('pickup_type', 'request')
            ->latest('requested_at');

        if ($status = $request->input('status')) {
            $query->where('request_status', $status);
        }

        if ($search = $request->input('search')) {
            $query->whereHas('serviceAccount', function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('address', 'like', "%{$search}%");
            });
        }

        $deliveries = $query->paginate(20)->withQueryString();

        return view('admin.off_schedule_pickups.index', compact('deliveries'));
    }

    public function show(int $id)
    {
        $delivery = WasteDelivery::with(['serviceAccount.area', 'serviceAccount.user', 'assignedCollector', 'invoice', 'wasteDeliveryItems.waste', 'wasteDeliveryItems.pocketSize'])
            ->where('pickup_type', 'request')
            ->findOrFail($id);

        // Get collectors with their active status
        $collectors = User::role('collector')
            ->whereNull('deleted_at')
            ->orderBy('name')
            ->get(['id', 'name']);

        // Get default surcharge from app settings
        $settings = \App\Models\AppSetting::first();
        $defaultSurcharge = (float) ($settings?->off_schedule_surcharge ?? 0);

        return view('admin.off_schedule_pickups.show', compact('delivery', 'collectors', 'defaultSurcharge'));
    }

    public function assignCollector(Request $request, int $id)
    {
        $delivery = $this->findDelivery($id);

        // Log incoming request for debugging
        \Log::info('Assignment Request', [
            'delivery_id' => $id,
            'collector_id' => $request->input('collector_id'),
            'bag_count' => $request->input('bag_count'),
            'extra_fee' => $request->input('extra_fee'),
        ]);

        $data = $request->validate([
            'collector_id' => 'required|exists:users,id',
            'bag_count' => 'nullable|integer|min:0',
            'extra_fee' => 'nullable|numeric|min:0',
        ]);

        // Verify the user has collector role
        $collector = User::findOrFail($data['collector_id']);
        
        if (!$collector->hasRole('collector')) {
            \Log::warning('Invalid collector role', ['user_id' => $collector->id, 'roles' => $collector->getRoleNames()]);
            return back()->withErrors(['collector_id' => 'User yang dipilih bukan kolektor.']);
        }

        try {
            $this->service->assignCollector(
                $delivery,
                $collector,
                $data['bag_count'] ?? null,
                $data['extra_fee'] ?? null
            );

            \Log::info('Collector assigned successfully', ['delivery_id' => $id, 'collector_id' => $collector->id]);
            
            return back()->with('success', 'Kolektor berhasil ditugaskan.');
        } catch (\Exception $e) {
            \Log::error('Assignment failed', ['error' => $e->getMessage()]);
            return back()->withErrors(['error' => 'Gagal menugaskan kolektor: ' . $e->getMessage()]);
        }
    }

    public function updateCost(Request $request, int $id)
    {
        $delivery = $this->findDelivery($id);

        // Validasi: tidak bisa update biaya jika status sudah processing
        if ($delivery->request_status === 'processing') {
            return back()->with('error', 'Biaya tidak dapat diubah setelah kolektor ditugaskan.');
        }

        $data = $request->validate([
            'bag_count' => 'required|integer|min:0',
            'extra_fee' => 'nullable|numeric|min:0',
        ]);

        $this->service->updateCosts($delivery, $data['bag_count'], $data['extra_fee'] ?? null);

        return back()->with('success', 'Perkiraan biaya berhasil diperbarui.');
    }

    public function reject(Request $request, int $id)
    {
        $delivery = $this->findDelivery($id);

        $data = $request->validate([
            'reason' => 'required|string|min:10',
        ]);

        $this->service->reject($delivery, $data['reason']);

        return redirect()->route('admin.off-schedule-pickups.index')
            ->with('success', 'Request berhasil ditolak.');
    }

    protected function findDelivery(int $id): WasteDelivery
    {
        return WasteDelivery::where('pickup_type', 'request')->findOrFail($id);
    }
}
