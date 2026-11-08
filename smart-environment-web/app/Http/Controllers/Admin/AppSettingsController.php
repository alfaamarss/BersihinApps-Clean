<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use App\Models\Area;
use App\Models\ServiceAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;

class AppSettingsController extends Controller
{
    public function index()
    {
        $settings = AppSetting::first() ?? new AppSetting;
        $provinces = cache()->remember('emsifa_provinces', 86400, function () {
            try {
                $response = Http::timeout(6)->get('https://www.emsifa.com/api-wilayah-indonesia/api/provinces.json');
                return $response->successful() ? ($response->json() ?? []) : [];
            } catch (\Throwable $e) {
                Log::warning('Failed fetching provinces: ' . $e->getMessage());
                return [];
            }
        });
        if (!is_array($provinces)) {
            $provinces = [];
        }

        // Auto-heal: if province_id was stored as name (e.g. 'Banten'), resolve to numeric ID
        if ($settings->province_id && !is_numeric($settings->province_id) && !empty($provinces)) {
            foreach ($provinces as $p) {
                if (isset($p['name']) && strcasecmp(trim($p['name']), trim($settings->province_id)) === 0) {
                    $settings->province_id = (string) $p['id'];
                    $settings->saveQuietly();
                    break;
                }
            }
        }

        $cities = [];
        $provinceId = old('province_id', $settings->province_id);
        if ($provinceId && is_numeric($provinceId)) {
            $cities = cache()->remember("emsifa_regencies_{$provinceId}", 86400, function () use ($provinceId) {
                try {
                    $response = Http::timeout(6)->get("https://www.emsifa.com/api-wilayah-indonesia/api/regencies/{$provinceId}.json");
                    return $response->successful() ? ($response->json() ?? []) : [];
                } catch (\Throwable $e) {
                    Log::warning("Failed fetching regencies for province {$provinceId}: " . $e->getMessage());
                    return [];
                }
            });
            if (!is_array($cities)) {
                $cities = [];
            }
        }

        // Get areas statistics
        $areasStats = [
            'total' => Area::count(),
            'kecamatan' => Area::where('level', 'Kecamatan')->count(),
            'kelurahan' => Area::where('level', 'Kelurahan')->count(),
        ];

        return view('admin.settings.index', compact('settings', 'provinces', 'cities', 'areasStats'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'app_name' => 'required|string|max:255',
            'app_logo_url' => 'nullable|url',
            'app_logo_file' => 'nullable|image|mimes:jpeg,jpg,png|max:2048', // Max 2MB
            'app_banner_url' => 'nullable|url',
            'app_banner_file' => 'nullable|image|mimes:jpeg,jpg,png|max:5120', // Max 5MB
            'province_id' => 'nullable|string',
            'configured_city_id' => 'nullable|string',
            'off_schedule_surcharge' => 'nullable|numeric|min:0',
        ]);

        $settings = AppSetting::firstOrNew();
        $settings->fill($request->only(['app_name', 'off_schedule_surcharge']));

        $provinceId = $request->input('province_id');
        if ($provinceId && !is_numeric($provinceId)) {
            $provinces = cache()->get('emsifa_provinces', []);
            foreach ($provinces as $p) {
                if (isset($p['name']) && strcasecmp(trim($p['name']), trim($provinceId)) === 0) {
                    $provinceId = (string) $p['id'];
                    break;
                }
            }
        }
        $settings->province_id = $provinceId;

        if (!$request->filled('off_schedule_surcharge')) {
            $settings->off_schedule_surcharge = 0;
        }

        // Handle logo upload/URL
        if ($request->hasFile('app_logo_file')) {
            // Delete old logo if exists
            if ($settings->app_logo_url && str_starts_with($settings->app_logo_url, 'storage/')) {
                Storage::disk('public')->delete(str_replace('storage/', '', $settings->app_logo_url));
            }

            // Store new logo
            $logoPath = $request->file('app_logo_file')->store('logos', 'public');
            $settings->app_logo_url = 'storage/' . $logoPath;
        } elseif ($request->filled('app_logo_url')) {
            // Delete old uploaded logo if switching to URL
            if ($settings->app_logo_url && str_starts_with($settings->app_logo_url, 'storage/')) {
                Storage::disk('public')->delete(str_replace('storage/', '', $settings->app_logo_url));
            }
            $settings->app_logo_url = $request->app_logo_url;
        }

        // Handle banner upload/URL
        if ($request->hasFile('app_banner_file')) {
            // Delete old banner if exists
            if ($settings->app_banner_url && str_starts_with($settings->app_banner_url, 'storage/')) {
                Storage::disk('public')->delete(str_replace('storage/', '', $settings->app_banner_url));
            }

            // Store new banner
            $bannerPath = $request->file('app_banner_file')->store('banners', 'public');
            $settings->app_banner_url = 'storage/' . $bannerPath;
        } elseif ($request->filled('app_banner_url')) {
            // Delete old uploaded banner if switching to URL
            if ($settings->app_banner_url && str_starts_with($settings->app_banner_url, 'storage/')) {
                Storage::disk('public')->delete(str_replace('storage/', '', $settings->app_banner_url));
            }
            $settings->app_banner_url = $request->app_banner_url;
        }

        $oldCityId = $settings->configured_city_id;
        $newCityId = $request->configured_city_id;

        if ($newCityId && $newCityId !== $oldCityId) {
            $syncResult = $this->syncAreas($newCityId);
            $cityData = Http::get("https://www.emsifa.com/api-wilayah-indonesia/api/regency/{$newCityId}.json")->json();
            $settings->configured_city_name = $cityData['name'] ?? null;
            $settings->configured_city_id = $newCityId;

            $successMessage = 'Pengaturan aplikasi berhasil disimpan.';
            if ($syncResult['success']) {
                $successMessage .= " Data kecamatan dan kelurahan telah diperbarui: {$syncResult['districts']} kecamatan dan {$syncResult['villages']} kelurahan.";
            }
        } else {
            $successMessage = 'Pengaturan aplikasi berhasil disimpan.';
        }

        $settings->save();

        return redirect()->route('admin.settings.index')->with('success', $successMessage ?? 'Pengaturan aplikasi berhasil disimpan.');
    }

    private function syncAreas($cityId)
    {
        try {
            // Disable foreign key checks temporarily
            DB::statement('SET FOREIGN_KEY_CHECKS=0');

            // Hapus semua data terkait (order doesn't matter with FK checks disabled)
            $tablesToTruncate = [
                'waste_delivery_items',
                'waste_deliveries',
                'invoices',
                'complaints',
                'schedules',
                'service_accounts',
                'areas'
            ];

            foreach ($tablesToTruncate as $table) {
                if (Schema::hasTable($table)) {
                    DB::table($table)->truncate();
                }
            }

            // Re-enable foreign key checks
            DB::statement('SET FOREIGN_KEY_CHECKS=1');

            $districts = Http::get("https://www.emsifa.com/api-wilayah-indonesia/api/districts/{$cityId}.json")->json();
            $villageCount = 0;

            foreach ($districts as $district) {
                // Buat data kecamatan terlebih dahulu
                $districtArea = Area::create([
                    'name' => $district['name'],
                    'level' => 'Kecamatan',
                    'parent_id' => null, // Kecamatan tidak memiliki parent
                ]);

                // Ambil data kelurahan untuk setiap kecamatan
                $villages = Http::get("https://www.emsifa.com/api-wilayah-indonesia/api/villages/{$district['id']}.json")->json();

                foreach ($villages as $village) {
                    // Buat data kelurahan dengan parent_id menuju kecamatan
                    Area::create([
                        'name' => $village['name'],
                        'level' => 'Kelurahan',
                        'parent_id' => $districtArea->id, // Kelurahan memiliki parent kecamatan
                    ]);
                    $villageCount++;
                }
            }

            Log::info("Successfully synced areas for city ID: {$cityId}. Added " . count($districts) . " districts and {$villageCount} villages.");

            return [
                'success' => true,
                'districts' => count($districts),
                'villages' => $villageCount
            ];

        } catch (\Exception $e) {
            // Jika terjadi error, log dan tidak crash aplikasi
            Log::warning('Failed to sync areas: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }
}
