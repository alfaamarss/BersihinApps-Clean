<?php

namespace App\Http\Controllers\API\Mobile\Collector;

use App\Http\Controllers\Controller;
use App\Models\TpsDeposit;
use App\Models\GarbageDump;
use App\Support\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class TpsDepositController extends Controller
{
    use ApiResponse;

    /**
     * Get list of TPS available for current collector
     */
    public function getAvailableTps(Request $request)
    {
        $collector = $request->user();
        
        // Ambil semua TPS & TPA yang aktif
        $allTps = GarbageDump::where('status', 'active')
            ->with(['kecamatan', 'kelurahan', 'rw'])
            ->orderBy('name')
            ->get();

        $assignedIds = $collector->assignedTps()->pluck('garbage_dumps.id')->toArray();

        $tpsList = $allTps->map(function ($tps) use ($assignedIds) {
            return [
                'id' => $tps->id,
                'name' => $tps->name,
                'address' => $tps->address,
                'latitude' => $tps->latitude,
                'longitude' => $tps->longitude,
                'capacity_volume' => $tps->capacity_volume,
                'capacity_weight' => $tps->capacity_weight,
                'status' => $tps->status,
                'is_assigned' => empty($assignedIds) || in_array($tps->id, $assignedIds),
                'kecamatan' => $tps->kecamatan ? [
                    'id' => $tps->kecamatan->id,
                    'name' => $tps->kecamatan->name,
                ] : null,
                'kelurahan' => $tps->kelurahan ? [
                    'id' => $tps->kelurahan->id,
                    'name' => $tps->kelurahan->name,
                ] : null,
                'rw' => $tps->rw ? [
                    'id' => $tps->rw->id,
                    'name' => $tps->rw->name,
                ] : null,
            ];
        });

        return $this->ok([
            'tps_list' => $tpsList,
        ], 'Daftar TPS berhasil diambil');
    }

    /**
     * Store a new TPS deposit
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'garbage_dump_id' => 'required|exists:garbage_dumps,id',
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'notes' => 'nullable|string|max:500',
        ], [
            'garbage_dump_id.required' => 'TPS tujuan harus dipilih',
            'garbage_dump_id.exists' => 'TPS tidak ditemukan',
            'latitude.required' => 'Latitude harus diisi',
            'latitude.numeric' => 'Latitude harus berupa angka',
            'longitude.required' => 'Longitude harus diisi',
            'longitude.numeric' => 'Longitude harus berupa angka',
        ]);

        if ($validator->fails()) {
            return $this->error('Validasi gagal', 422, $validator->errors()->toArray());
        }

        $collector = $request->user();
        $tps = GarbageDump::find($request->garbage_dump_id);

        // Check if TPS is active
        if ($tps->status !== 'active') {
            return $this->error('TPS tidak aktif', 422, [
                'garbage_dump_id' => ['TPS tidak aktif atau tidak tersedia']
            ]);
        }

        // Check if collector is assigned to this TPS (for logging / audit)
        $isAssigned = $collector->assignedTps()->where('garbage_dumps.id', $tps->id)->exists();
        if (!$isAssigned) {
            \Illuminate\Support\Facades\Log::info("Collector {$collector->id} deposited to non-assigned active TPS {$tps->id} ({$tps->name})");
        }

        $deposit = TpsDeposit::create([
            'collector_id' => $request->user()->id,
            'garbage_dump_id' => $request->garbage_dump_id,
            'deposited_at' => now(),
            'latitude' => $request->latitude,
            'longitude' => $request->longitude,
            'notes' => $request->notes,
        ]);

        $deposit->load('garbageDump');

        return $this->created([
            'id' => $deposit->id,
            'collector_id' => $deposit->collector_id,
            'garbage_dump_id' => $deposit->garbage_dump_id,
            'deposited_at' => $deposit->deposited_at->toIso8601String(),
            'latitude' => $deposit->latitude,
            'longitude' => $deposit->longitude,
            'notes' => $deposit->notes,
            'garbage_dump' => [
                'id' => $deposit->garbageDump->id,
                'name' => $deposit->garbageDump->name,
                'address' => $deposit->garbageDump->address,
            ],
        ], 'Setor ke TPS berhasil dicatat');
    }

    /**
     * Get deposit history for current collector
     */
    public function index(Request $request)
    {
        $query = TpsDeposit::where('collector_id', $request->user()->id)
            ->with('garbageDump');

        if ($request->has('garbage_dump_id') && $request->garbage_dump_id) {
            $query->where('garbage_dump_id', $request->garbage_dump_id);
        }

        if ($request->has('start_date') && $request->start_date) {
            $query->whereDate('deposited_at', '>=', $request->start_date);
        }

        if ($request->has('end_date') && $request->end_date) {
            $query->whereDate('deposited_at', '<=', $request->end_date);
        }

        $perPage = $request->input('per_page', 15);
        $deposits = $query->latest('deposited_at')->paginate($perPage);

        return $this->ok([
            'deposits' => $deposits->map(function ($deposit) {
                return [
                    'id' => $deposit->id,
                    'deposited_at' => $deposit->deposited_at?->toIso8601String(),
                    'latitude' => $deposit->latitude,
                    'longitude' => $deposit->longitude,
                    'notes' => $deposit->notes,
                    'garbage_dump' => $deposit->garbageDump ? [
                        'id' => $deposit->garbageDump->id,
                        'name' => $deposit->garbageDump->name,
                        'address' => $deposit->garbageDump->address,
                    ] : null,
                ];
            }),
            'meta' => [
                'current_page' => $deposits->currentPage(),
                'last_page' => $deposits->lastPage(),
                'per_page' => $deposits->perPage(),
                'total' => $deposits->total(),
            ],
        ], 'Riwayat setor berhasil diambil');
    }

    /**
     * Get deposit detail
     */
    public function show(Request $request, $id)
    {
        $deposit = TpsDeposit::where('collector_id', $request->user()->id)
            ->where('id', $id)
            ->with(['garbageDump.kecamatan', 'garbageDump.kelurahan', 'garbageDump.rw'])
            ->first();

        if (!$deposit) {
            return $this->error('Data setor tidak ditemukan', 404);
        }

        return $this->ok([
            'id' => $deposit->id,
            'collector_id' => $deposit->collector_id,
            'deposited_at' => $deposit->deposited_at?->toIso8601String(),
            'latitude' => $deposit->latitude,
            'longitude' => $deposit->longitude,
            'notes' => $deposit->notes,
            'garbage_dump' => $deposit->garbageDump ? [
                'id' => $deposit->garbageDump->id,
                'name' => $deposit->garbageDump->name,
                'address' => $deposit->garbageDump->address,
                'latitude' => $deposit->garbageDump->latitude,
                'longitude' => $deposit->garbageDump->longitude,
                'kecamatan' => $deposit->garbageDump->kecamatan ? [
                    'id' => $deposit->garbageDump->kecamatan->id,
                    'name' => $deposit->garbageDump->kecamatan->name,
                ] : null,
                'kelurahan' => $deposit->garbageDump->kelurahan ? [
                    'id' => $deposit->garbageDump->kelurahan->id,
                    'name' => $deposit->garbageDump->kelurahan->name,
                ] : null,
                'rw' => $deposit->garbageDump->rw ? [
                    'id' => $deposit->garbageDump->rw->id,
                    'name' => $deposit->garbageDump->rw->name,
                ] : null,
            ] : null,
            'created_at' => $deposit->created_at?->toIso8601String(),
        ], 'Detail setor berhasil diambil');
    }
}
