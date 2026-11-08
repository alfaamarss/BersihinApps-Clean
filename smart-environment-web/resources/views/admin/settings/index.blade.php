@extends('layouts.master')

@section('title','Pengaturan Aplikasi')

@section('content')
<div class="grid grid-cols-12 gap-4 md:gap-6">
  <div class="col-span-12">
    <div class="rounded-2xl border border-gray-200 bg-white p-6 shadow-theme-sm dark:border-gray-800 dark:bg-white/[0.03]">
      <div class="mb-8">
        <div class="flex items-center gap-3 mb-2">
          <div class="p-2 bg-blue-100 dark:bg-blue-900/30 rounded-lg">
            <svg class="w-6 h-6 text-blue-600 dark:text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
            </svg>
          </div>
          <div>
            <h2 class="text-3xl font-bold text-gray-900 dark:text-white">Pengaturan Aplikasi</h2>
            <p class="text-gray-500 dark:text-gray-400 mt-1">Kelola konfigurasi aplikasi dan wilayah operasional</p>
          </div>
        </div>
      </div>

      <form action="{{ route('admin.settings.store') }}" method="POST" enctype="multipart/form-data" class="space-y-8"
            x-data="{
                selectedProvince: '{{ old('province_id', $settings->province_id ?? '') }}',
                selectedCity: '{{ old('configured_city_id', $settings->configured_city_id ?? '') }}',
                cities: {{ Js::from($cities ?? []) }},
                loadingCities: false,
                resolveProvinceId(val) {
                    if (!val) return '';
                    if (!isNaN(val)) return String(val);
                    // Match province name to option value if name was passed
                    const provSelect = document.getElementById('province_id');
                    if (provSelect) {
                        for (let i = 0; i < provSelect.options.length; i++) {
                            const opt = provSelect.options[i];
                            if (opt.text.trim().toLowerCase() === String(val).trim().toLowerCase()) {
                                return opt.value;
                            }
                        }
                    }
                    return val;
                },
                loadCities(force = false) {
                    this.selectedProvince = this.resolveProvinceId(this.selectedProvince);
                    if (!this.selectedProvince || isNaN(this.selectedProvince)) {
                        if (!this.selectedProvince) {
                            this.cities = [];
                            this.selectedCity = '';
                        }
                        return;
                    }

                    // If cities already pre-loaded and matches selected province, skip re-fetching
                    if (!force && this.cities.length > 0 && String(this.cities[0].province_id) === String(this.selectedProvince)) {
                        return;
                    }

                    this.loadingCities = true;

                    fetch(`https://www.emsifa.com/api-wilayah-indonesia/api/regencies/${this.selectedProvince}.json`)
                        .then(response => {
                            if (!response.ok) {
                                throw new Error(`HTTP error! status: ${response.status}`);
                            }
                            return response.json();
                        })
                        .then(data => {
                            this.cities = data || [];
                            this.loadingCities = false;

                            setTimeout(() => {
                                const savedCity = '{{ old('configured_city_id', $settings->configured_city_id ?? '') }}';
                                if (savedCity) {
                                    this.selectedCity = savedCity;
                                }
                            }, 50);
                        })
                        .catch(error => {
                            console.error('Error fetching cities:', error);
                            this.loadingCities = false;
                        });
                }
            }"
            x-init="selectedProvince = resolveProvinceId(selectedProvince); if (selectedProvince && (!cities || cities.length === 0)) loadCities()">
        @csrf

        <!-- App Configuration Section -->
        <div class="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-xl p-6 border border-blue-200 dark:border-blue-800">
          <div class="flex items-center gap-3 mb-4">
            <div class="p-2 bg-blue-500 rounded-lg">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-2M7 21h2m-2 0H3m0 0h2M9 7h6m-6 4h6m-6 4h6"></path>
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Konfigurasi Aplikasi</h3>
              <p class="text-sm text-gray-600 dark:text-gray-400">Atur identitas dan tampilan aplikasi</p>
            </div>
          </div>
          <div class="grid md:grid-cols-2 gap-6">
            <div class="md:col-span-2">
              <x-form.input name="app_name" label="Nama Aplikasi" :value="old('app_name', $settings->app_name)" required placeholder="Masukkan nama aplikasi" />
            </div>


            <!-- Logo Upload Section -->
            <div class="space-y-2">
              <label class="text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-2">
                <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                </svg>
                Logo Aplikasi
              </label>

              <!-- Current Logo Preview -->
              @if($settings->app_logo_url && $settings->app_logo_url !== 'storage/' && $settings->app_logo_url !== 'storage')
              <div class="mb-3">
                <p class="text-xs text-gray-500 dark:text-gray-400 mb-2">Logo saat ini:</p>
                <div class="w-24 h-24 border-2 border-gray-200 dark:border-gray-600 rounded-lg overflow-hidden bg-gray-50 dark:bg-gray-700 flex items-center justify-center">
                  <img src="{{ \Illuminate\Support\Str::startsWith($settings->app_logo_url, ['http://', 'https://']) ? $settings->app_logo_url : secure_asset($settings->app_logo_url) }}" alt="Current Logo" class="w-full h-full object-contain" onerror="this.style.display='none'; this.nextElementSibling.style.display='block'">
                  <div class="hidden text-gray-400 text-xs text-center">
                    <svg class="w-6 h-6 mx-auto mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    Logo tidak dapat dimuat
                  </div>
                </div>
              </div>
              @endif

              <!-- File Input -->
              <div class="relative">
                <input type="file" name="app_logo_file" id="app_logo_file" accept="image/*"
                       class="hidden" onchange="previewImage(this, 'logo-preview')">
                <label for="app_logo_file"
                       class="flex flex-col items-center justify-center w-full h-32 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:border-gray-600 dark:hover:border-gray-500 dark:hover:bg-gray-700 transition-colors">
                  <div class="flex flex-col items-center justify-center pt-5 pb-6" id="logo-upload-area">
                    <svg class="w-8 h-8 mb-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
                    </svg>
                    <p class="mb-2 text-sm text-gray-500 dark:text-gray-400">
                      <span class="font-semibold">Klik untuk upload</span> logo aplikasi
                    </p>
                    <p class="text-xs text-gray-500 dark:text-gray-400">PNG, JPG atau JPEG (Max. 2MB)</p>
                  </div>
                  <img id="logo-preview" class="hidden w-full h-full object-contain rounded-lg">
                </label>
              </div>

              <!-- URL Alternative -->
              <!-- <div class="mt-3">
                <label class="text-xs text-gray-500 dark:text-gray-400">Atau gunakan URL:</label>
                <x-form.input type="url" name="app_logo_url" :value="old('app_logo_url', $settings->app_logo_url)" placeholder="https://example.com/logo.png" class="mt-1" />
              </div> -->
            </div>

            <!-- Banner Upload Section -->
            <div class="space-y-2">
              <label class="text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-2">
                <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                </svg>
                Banner Aplikasi
              </label>

              <!-- Current Banner Preview -->
              @if($settings->app_banner_url && $settings->app_banner_url !== 'storage/' && $settings->app_banner_url !== 'storage')
              <div class="mb-3">
                <p class="text-xs text-gray-500 dark:text-gray-400 mb-2">Banner saat ini:</p>
                <div class="w-full h-20 border-2 border-gray-200 dark:border-gray-600 rounded-lg overflow-hidden bg-gray-50 dark:bg-gray-700 flex items-center justify-center">
                  <img src="{{ \Illuminate\Support\Str::startsWith($settings->app_banner_url, ['http://', 'https://']) ? $settings->app_banner_url : secure_asset($settings->app_banner_url) }}" alt="Current Banner" class="w-full h-full object-cover" onerror="this.style.display='none'; this.nextElementSibling.style.display='block'">
                  <div class="hidden text-gray-400 text-xs text-center">
                    <svg class="w-6 h-6 mx-auto mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    Banner tidak dapat dimuat
                  </div>
                </div>
              </div>
              @endif

              <!-- File Input -->
              <div class="relative">
                <input type="file" name="app_banner_file" id="app_banner_file" accept="image/*"
                       class="hidden" onchange="previewImage(this, 'banner-preview')">
                <label for="app_banner_file"
                       class="flex flex-col items-center justify-center w-full h-32 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:border-gray-600 dark:hover:border-gray-500 dark:hover:bg-gray-700 transition-colors">
                  <div class="flex flex-col items-center justify-center pt-5 pb-6" id="banner-upload-area">
                    <svg class="w-8 h-8 mb-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
                    </svg>
                    <p class="mb-2 text-sm text-gray-500 dark:text-gray-400">
                      <span class="font-semibold">Klik untuk upload</span> banner aplikasi
                    </p>
                    <p class="text-xs text-gray-500 dark:text-gray-400">PNG, JPG atau JPEG (Max. 5MB)</p>
                  </div>
                  <img id="banner-preview" class="hidden w-full h-full object-cover rounded-lg">
                </label>
              </div>

              <!-- URL Alternative -->
              <!-- <div class="mt-3">
                <label class="text-xs text-gray-500 dark:text-gray-400">Atau gunakan URL:</label>
                <x-form.input type="url" name="app_banner_url" :value="old('app_banner_url', $settings->app_banner_url)" placeholder="https://example.com/banner.png" class="mt-1" />
              </div> -->
            </div>
          </div>
        </div>

        <!-- Off-schedule surcharge section -->
        <div class="rounded-xl border border-amber-200 bg-amber-50 dark:border-amber-800 dark:bg-amber-900/20 p-6">
          <div class="flex items-center gap-3 mb-4">
            <div class="p-2 bg-amber-500 rounded-lg">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2a1 1 0 01-1 1H7a1 1 0 00-1 1v5a2 2 0 002 2h8a2 2 0 002-2v-5a1 1 0 00-1-1h-1a1 1 0 01-1-1c0-1.105-1.343-2-3-2z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 3h4" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Tarif Tambahan Pickup Luar Jadwal</h3>
              <p class="text-sm text-gray-600 dark:text-gray-400">Atur biaya default untuk setiap permintaan pickup di luar jadwal rutin.</p>
            </div>
          </div>

          <div class="max-w-lg">
            <x-form.input name="off_schedule_surcharge" label="Tarif tambahan pickup luar jadwal" type="number" step="1000" min="0" :value="old('off_schedule_surcharge', $settings->off_schedule_surcharge ?? 0)" placeholder="Contoh: 5000" />
            <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Nilai ini digunakan sebagai biaya tambahan standar saat warga mengajukan pickup di luar jadwal terjadwal.</p>
          </div>
        </div>

        <!-- Location Configuration Section -->
        <div class="bg-gradient-to-r from-emerald-50 to-green-50 dark:from-emerald-900/20 dark:to-green-900/20 rounded-xl p-6 border border-emerald-200 dark:border-emerald-800">
          <div class="flex items-center gap-3 mb-4">
            <div class="p-2 bg-emerald-500 rounded-lg">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Wilayah Operasional</h3>
              <p class="text-sm text-gray-600 dark:text-gray-400">Tentukan wilayah kerja aplikasi untuk data kecamatan dan kelurahan</p>
            </div>
          </div>

          <div class="grid md:grid-cols-2 gap-6">
            <div class="space-y-2">
              <label for="province_id" class="text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-2">
                <svg class="w-4 h-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-1.447-.894L15 4m0 13V4m-6 3l6-3"></path>
                </svg>
                Provinsi
              </label>
              <select name="province_id" id="province_id" x-model="selectedProvince" @change="loadCities(true)"
                      class="w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 px-4 py-3 text-gray-900 dark:text-white focus:border-emerald-500 focus:ring-2 focus:ring-emerald-200 dark:focus:ring-emerald-800 transition-colors">
                <option value="">🌏 Pilih Provinsi</option>
                @foreach($provinces as $province)
                    <option value="{{ $province['id'] }}">{{ $province['name'] }}</option>
                @endforeach
              </select>
            </div>

            <div class="space-y-2">
              <label for="configured_city_id" class="text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-2">
                <svg class="w-4 h-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-2M7 21h2m-2 0H3m0 0h2M9 7h6m-6 4h6m-6 4h6"></path>
                </svg>
                Kota/Kabupaten
              </label>
              <select name="configured_city_id" id="configured_city_id" x-model="selectedCity"
                      class="w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 px-4 py-3 text-gray-900 dark:text-white focus:border-emerald-500 focus:ring-2 focus:ring-emerald-200 dark:focus:ring-emerald-800 transition-colors disabled:bg-gray-100 dark:disabled:bg-gray-700 disabled:cursor-not-allowed"
                      :disabled="loadingCities || !selectedProvince">
                <option value="">🏢 Pilih Kota/Kabupaten</option>
                <template x-for="city in cities" :key="city.id">
                    <option :value="city.id" x-text="city.name"></option>
                </template>
              </select>

              <!-- Loading State -->
              <div x-show="loadingCities" class="flex items-center gap-2 text-sm text-blue-600 dark:text-blue-400 mt-2">
                <svg class="animate-spin w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
                </svg>
                Memuat data kota...
              </div>

              <!-- Error State -->
              <div x-show="cities.length === 0 && !loadingCities && selectedProvince" class="flex items-center gap-2 text-sm text-red-600 dark:text-red-400 mt-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                Tidak ada data kota ditemukan
              </div>
            </div>
          </div>
        </div>

        <!-- Area Statistics Section -->
        <div class="bg-gradient-to-r from-purple-50 to-pink-50 dark:from-purple-900/20 dark:to-pink-900/20 rounded-xl border border-purple-200 dark:border-purple-800">
          @if($areasStats['total'] > 0)
          <div class="p-6">
            <div class="flex items-center gap-3 mb-4">
              <div class="p-2 bg-purple-500 rounded-lg">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 00-2-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v6a2 2 0 00-2 2h-2a2 2 0 00-2-2z"></path>
                </svg>
              </div>
              <div>
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white">📍 Data Area Tersedia</h3>
                <p class="text-sm text-gray-600 dark:text-gray-400">Statistik wilayah yang sudah dikonfigurasi</p>
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div class="bg-white dark:bg-gray-800 rounded-lg p-4 border border-purple-200 dark:border-purple-700">
                <div class="flex items-center gap-3">
                  <div class="p-2 bg-blue-100 dark:bg-blue-900/30 rounded-lg">
                    <svg class="w-5 h-5 text-blue-600 dark:text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-2M7 21h2m-2 0H3m0 0h2M9 7h6m-6 4h6m-6 4h6"></path>
                    </svg>
                  </div>
                  <div>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">{{ number_format($areasStats['kecamatan']) }}</p>
                    <p class="text-sm text-gray-600 dark:text-gray-400">Kecamatan</p>
                  </div>
                </div>
              </div>

              <div class="bg-white dark:bg-gray-800 rounded-lg p-4 border border-purple-200 dark:border-purple-700">
                <div class="flex items-center gap-3">
                  <div class="p-2 bg-emerald-100 dark:bg-emerald-900/30 rounded-lg">
                    <svg class="w-5 h-5 text-emerald-600 dark:text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                    </svg>
                  </div>
                  <div>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">{{ number_format($areasStats['kelurahan']) }}</p>
                    <p class="text-sm text-gray-600 dark:text-gray-400">Kelurahan</p>
                  </div>
                </div>
              </div>

              <div class="bg-white dark:bg-gray-800 rounded-lg p-4 border border-purple-200 dark:border-purple-700">
                <div class="flex items-center gap-3">
                  <div class="p-2 bg-purple-100 dark:bg-purple-900/30 rounded-lg">
                    <svg class="w-5 h-5 text-purple-600 dark:text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 00-2-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v6a2 2 0 00-2 2h-2a2 2 0 00-2-2z"></path>
                    </svg>
                  </div>
                  <div>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">{{ number_format($areasStats['total']) }}</p>
                    <p class="text-sm text-gray-600 dark:text-gray-400">Total Area</p>
                  </div>
                </div>
              </div>
            </div>

            <div class="mt-4 pt-4 border-t border-purple-200 dark:border-purple-700">
              <a href="{{ route('admin.areas.index') }}"
                 class="inline-flex items-center gap-2 text-sm font-medium text-purple-600 dark:text-purple-400 hover:text-purple-800 dark:hover:text-purple-200 transition-colors">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path>
                </svg>
                Kelola Data Area →
              </a>
            </div>
          </div>
          @else
          <div class="p-6">
            <div class="flex items-center gap-3 mb-4">
              <div class="p-2 bg-blue-500 rounded-lg">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
              </div>
              <div>
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white">ℹ️ Belum Ada Data Area</h3>
                <p class="text-sm text-gray-600 dark:text-gray-400">Data kecamatan dan kelurahan akan dibuat otomatis</p>
              </div>
            </div>

            <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
              <p class="text-sm text-blue-700 dark:text-blue-300">
                <strong>Cara menggunakan:</strong><br>
                1. Pilih provinsi dari dropdown di atas<br>
                2. Pilih kota/kabupaten yang diinginkan<br>
                3. Klik "Simpan Pengaturan" untuk mengisi data kecamatan dan kelurahan secara otomatis<br>
                4. Sistem akan mendownload dan menyimpan data wilayah dari API resmi
              </p>
            </div>
          </div>
          @endif
        </div>

        <!-- Submit Button -->
        <div class="flex justify-end pt-6">
          <button type="submit"
                  class="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white font-semibold rounded-lg shadow-lg hover:shadow-xl transform hover:scale-105 transition-all duration-200 focus:ring-4 focus:ring-blue-200 dark:focus:ring-blue-800">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4"></path>
            </svg>
            Simpan Pengaturan
          </button>
        </div>
      </form>
    </div>
  </div>
</div>

<script>
function previewImage(input, previewId) {
  const file = input.files[0];
  const preview = document.getElementById(previewId);
  const uploadArea = document.getElementById(previewId === 'logo-preview' ? 'logo-upload-area' : 'banner-upload-area');

  if (file) {
    // Validate file size
    const maxSize = previewId === 'logo-preview' ? 2 * 1024 * 1024 : 5 * 1024 * 1024; // 2MB for logo, 5MB for banner
    if (file.size > maxSize) {
      alert(previewId === 'logo-preview' ?
        'Ukuran file logo tidak boleh lebih dari 2MB!' :
        'Ukuran file banner tidak boleh lebih dari 5MB!');
      input.value = '';
      return;
    }

    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png'];
    if (!allowedTypes.includes(file.type)) {
      alert('File harus berupa gambar (JPG, JPEG, atau PNG)!');
      input.value = '';
      return;
    }

    const reader = new FileReader();
    reader.onload = function(e) {
      preview.src = e.target.result;
      preview.classList.remove('hidden');
      uploadArea.classList.add('hidden');
    };
    reader.readAsDataURL(file);
  } else {
    preview.classList.add('hidden');
    uploadArea.classList.remove('hidden');
  }
}

// Reset preview when clicking outside or changing back to URL
document.querySelectorAll('input[type="url"]').forEach(input => {
  input.addEventListener('focus', function() {
    const isLogo = this.name.includes('logo');
    const preview = document.getElementById(isLogo ? 'logo-preview' : 'banner-preview');
    const uploadArea = document.getElementById(isLogo ? 'logo-upload-area' : 'banner-upload-area');
    const fileInput = document.getElementById(isLogo ? 'app_logo_file' : 'app_banner_file');

    if (fileInput.files.length > 0) {
      if (confirm('Anda sedang menggunakan file upload. Ingin beralih ke URL? File yang dipilih akan dihapus.')) {
        fileInput.value = '';
        preview.classList.add('hidden');
        uploadArea.classList.remove('hidden');
      } else {
        this.blur();
      }
    }
  });
});
</script>

@endsection
