@extends('layouts.master')

@section('title', 'Detail Pengambilan Sampah #' . $pickup->id)

@section('content')
<div class="grid grid-cols-12 gap-4 md:gap-6">
    <div class="col-span-12">
        <!-- Header -->
        <div class="mb-6 flex flex-wrap items-center justify-between gap-4">
            <div class="flex items-center gap-4">
                <a href="{{ route('admin.pickups.monitor') }}" 
                   class="inline-flex items-center justify-center w-10 h-10 rounded-lg border border-gray-200 bg-white text-gray-600 hover:bg-gray-50 hover:text-primary transition-colors dark:border-gray-700 dark:bg-gray-800 dark:text-gray-400 dark:hover:bg-gray-700">
                    <i class="fas fa-arrow-left"></i>
                </a>
                <div>
                    <h2 class="text-2xl font-bold text-black dark:text-white">
                        Detail Pengambilan Sampah <span class="text-primary">#{{ $pickup->id }}</span>
                    </h2>
                    <p class="text-sm text-gray-500 mt-1">
                        <i class="far fa-calendar-alt mr-1"></i>
                        {{ $pickup->pickup_date->format('d F Y') }}
                        @if($pickup->scheduled_at)
                            <span class="ml-2"><i class="far fa-clock mr-1"></i>{{ $pickup->scheduled_at->format('H:i') }}</span>
                        @endif
                    </p>
                </div>
            </div>
            
        </div>

        <!-- Status Badges -->
        <div class="flex flex-wrap gap-3 mb-6">
            <!-- Pickup Status -->
            <div class="flex items-center gap-2">
                <span class="text-sm text-gray-500">Status:</span>
                @php
                    $statusConfig = [
                        'pending' => ['bg' => 'bg-yellow-100 dark:bg-yellow-900/30', 'text' => 'text-yellow-800 dark:text-yellow-400', 'label' => 'Pending'],
                        'confirmed' => ['bg' => 'bg-blue-100 dark:bg-blue-900/30', 'text' => 'text-blue-800 dark:text-blue-400', 'label' => 'Confirmed'],
                        'in_progress' => ['bg' => 'bg-indigo-100 dark:bg-indigo-900/30', 'text' => 'text-indigo-800 dark:text-indigo-400', 'label' => 'In Progress'],
                        'collected' => ['bg' => 'bg-green-100 dark:bg-green-900/30', 'text' => 'text-green-800 dark:text-green-400', 'label' => 'Collected'],
                        'skipped' => ['bg' => 'bg-gray-100 dark:bg-gray-900/30', 'text' => 'text-gray-800 dark:text-gray-400', 'label' => 'Skipped'],
                        'completed' => ['bg' => 'bg-emerald-100 dark:bg-emerald-900/30', 'text' => 'text-emerald-800 dark:text-emerald-400', 'label' => 'Completed'],
                        'cancelled' => ['bg' => 'bg-red-100 dark:bg-red-900/30', 'text' => 'text-red-800 dark:text-red-400', 'label' => 'Cancelled'],
                    ];
                    $status = $statusConfig[$pickup->status] ?? $statusConfig['pending'];
                @endphp
                <span class="px-3 py-1 text-sm font-semibold rounded-full {{ $status['bg'] }} {{ $status['text'] }}">
                    {{ $status['label'] }}
                </span>
            </div>

            <!-- Confirmation Status -->
            <div class="flex items-center gap-2">
                <span class="text-sm text-gray-500">Konfirmasi:</span>
                @php
                    $confirmConfig = [
                        'pending' => ['bg' => 'bg-yellow-100 dark:bg-yellow-900/30', 'text' => 'text-yellow-800 dark:text-yellow-400', 'label' => 'Pending'],
                        'confirmed' => ['bg' => 'bg-green-100 dark:bg-green-900/30', 'text' => 'text-green-800 dark:text-green-400', 'label' => 'Confirmed'],
                        'rejected' => ['bg' => 'bg-red-100 dark:bg-red-900/30', 'text' => 'text-red-800 dark:text-red-400', 'label' => 'Rejected'],
                        'skipped' => ['bg' => 'bg-gray-100 dark:bg-gray-900/30', 'text' => 'text-gray-800 dark:text-gray-400', 'label' => 'Skipped'],
                        'no_waste' => ['bg' => 'bg-orange-100 dark:bg-orange-900/30', 'text' => 'text-orange-800 dark:text-orange-400', 'label' => 'Tidak Ada Sampah'],
                    ];
                    $confirm = $confirmConfig[$pickup->confirmation_status] ?? $confirmConfig['pending'];
                @endphp
                <span class="px-3 py-1 text-sm font-semibold rounded-full {{ $confirm['bg'] }} {{ $confirm['text'] }}">
                    {{ $confirm['label'] }}
                </span>
            </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <!-- Left Column: Main Info -->
            <div class="lg:col-span-2 space-y-6">
                <!-- Resident & Collector Info -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <!-- Resident Info Card -->
                    <div class="rounded-2xl border border-gray-200 bg-gradient-to-br from-blue-50 to-blue-100 p-5 shadow-sm dark:border-gray-700 dark:from-blue-900/20 dark:to-blue-800/10">
                        <div class="flex items-center gap-3 mb-4">
                            <div class="w-10 h-10 rounded-full bg-blue-500 flex items-center justify-center">
                                <i class="fas fa-user text-white"></i>
                            </div>
                            <h3 class="text-lg font-semibold text-gray-800 dark:text-white">Informasi Warga</h3>
                        </div>
                        @php
                            $serviceAccount = $pickup->serviceAccount;
                            $user = $serviceAccount ? $serviceAccount->user : null;
                        @endphp
                        @if($serviceAccount)
                        <div class="space-y-3">
                            <div class="flex justify-between">
                                <span class="text-sm text-gray-600 dark:text-gray-400">Nama:</span>
                                <span class="text-sm font-medium text-gray-900 dark:text-white text-right">
                                    {{ $serviceAccount->name ?? ($user->name ?? '-') }}
                                </span>
                            </div>
                            <div class="flex justify-between">
                                <span class="text-sm text-gray-600 dark:text-gray-400">No. Akun:</span>
                                <span class="text-sm font-medium text-gray-900 dark:text-white text-right">
                                    {{ $serviceAccount->account_number ?? '-' }}
                                </span>
                            </div>
                            <div class="flex justify-between">
                                <span class="text-sm text-gray-600 dark:text-gray-400">Telepon:</span>
                                <span class="text-sm font-medium text-gray-900 dark:text-white text-right">
                                    {{ $serviceAccount->contact_phone ?? ($user->phone ?? '-') }}
                                </span>
                            </div>
                            <div>
                                <span class="text-sm text-gray-600 dark:text-gray-400">Alamat:</span>
                                <p class="text-sm font-medium text-gray-900 dark:text-white mt-1">
                                    {{ $serviceAccount->address ?? ($user->address ?? '-') }}
                                </p>
                            </div>
                            @if($serviceAccount->area)
                            <div class="pt-2 border-t border-blue-200 dark:border-blue-700">
                                <span class="inline-flex items-center gap-1 text-xs text-blue-600 dark:text-blue-400">
                                    <i class="fas fa-map-marker-alt"></i>
                                    {{ $serviceAccount->area->name }}
                                </span>
                            </div>
                            @endif
                        </div>
                        @else
                        <div class="text-center py-4 text-gray-500 dark:text-gray-400">
                            <i class="fas fa-info-circle mb-2"></i>
                            <p class="text-sm">Data warga tidak tersedia</p>
                        </div>
                        @endif
                    </div>

                    <!-- Collector Info Card -->
                    <div class="rounded-2xl border border-gray-200 bg-gradient-to-br from-green-50 to-green-100 p-5 shadow-sm dark:border-gray-700 dark:from-green-900/20 dark:to-green-800/10">
                        <div class="flex items-center gap-3 mb-4">
                            <div class="w-10 h-10 rounded-full bg-green-500 flex items-center justify-center">
                                <i class="fas fa-truck text-white"></i>
                            </div>
                            <h3 class="text-lg font-semibold text-gray-800 dark:text-white">Informasi Collector</h3>
                        </div>
                        @php
                            $collector = null;
                            if ($pickup->assigned_collector_id) {
                                $collector = \App\Models\User::find($pickup->assigned_collector_id);
                            } elseif ($pickup->schedule) {
                                $assignment = $pickup->schedule->collectorAssignments()
                                    ->with('user')
                                    ->where('start_date', '<=', $pickup->pickup_date)
                                    ->where(function($q) use ($pickup) {
                                        $q->whereNull('end_date')
                                          ->orWhere('end_date', '>=', $pickup->pickup_date);
                                    })
                                    ->first();
                                $collector = optional($assignment)->user;
                            }
                        @endphp
                        <div class="space-y-3">
                            <div class="flex justify-between">
                                <span class="text-sm text-gray-600 dark:text-gray-400">Nama:</span>
                                <span class="text-sm font-medium text-gray-900 dark:text-white text-right">
                                    {{ $collector->name ?? '-' }}
                                </span>
                            </div>
                            <div class="flex justify-between">
                                <span class="text-sm text-gray-600 dark:text-gray-400">Email:</span>
                                <span class="text-sm font-medium text-gray-900 dark:text-white text-right">
                                    {{ $collector->email ?? '-' }}
                                </span>
                            </div>
                            <div class="flex justify-between">
                                <span class="text-sm text-gray-600 dark:text-gray-400">Telepon:</span>
                                <span class="text-sm font-medium text-gray-900 dark:text-white text-right">
                                    {{ $collector->phone ?? '-' }}
                                </span>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Waste Items Card -->
                @if($pickup->wasteDeliveryItems && $pickup->wasteDeliveryItems->count() > 0)
                <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                    <div class="flex items-center gap-3 mb-4">
                        <div class="w-10 h-10 rounded-full bg-amber-500 flex items-center justify-center">
                            <i class="fas fa-recycle text-white"></i>
                        </div>
                        <h3 class="text-lg font-semibold text-gray-800 dark:text-white">Detail Sampah</h3>
                    </div>
                    
                    <!-- Desktop Table -->
                    <div class="hidden md:block overflow-x-auto">
                        <table class="w-full text-sm">
                            <thead>
                                <tr class="bg-gray-50 dark:bg-gray-700/50">
                                    <th class="px-4 py-3 text-left font-semibold text-gray-600 dark:text-gray-300 rounded-l-lg">No</th>
                                    <th class="px-4 py-3 text-left font-semibold text-gray-600 dark:text-gray-300">Jenis Sampah</th>
                                    <th class="px-4 py-3 text-left font-semibold text-gray-600 dark:text-gray-300">Ukuran Kantong</th>
                                    <th class="px-4 py-3 text-right font-semibold text-gray-600 dark:text-gray-300">Qty</th>
                                    <th class="px-4 py-3 text-right font-semibold text-gray-600 dark:text-gray-300">Harga Satuan</th>
                                    <th class="px-4 py-3 text-right font-semibold text-gray-600 dark:text-gray-300 rounded-r-lg">Subtotal</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                                @foreach($pickup->wasteDeliveryItems as $index => $item)
                                <tr class="hover:bg-gray-50 dark:hover:bg-gray-700/30 transition-colors">
                                    <td class="px-4 py-3 text-gray-600 dark:text-gray-400">{{ $index + 1 }}</td>
                                    <td class="px-4 py-3 font-medium text-gray-900 dark:text-white">
                                        {{ optional($item->waste)->category ?? '-' }}
                                    </td>
                                    <td class="px-4 py-3 text-gray-600 dark:text-gray-400">
                                        {{ optional($item->pocketSize)->name ?? '-' }}
                                    </td>
                                    <td class="px-4 py-3 text-right text-gray-600 dark:text-gray-400">
                                        {{ $item->quantity }}
                                    </td>
                                    <td class="px-4 py-3 text-right text-gray-600 dark:text-gray-400">
                                        Rp {{ number_format($item->unit_price ?? 0, 0, ',', '.') }}
                                    </td>
                                    <td class="px-4 py-3 text-right font-medium text-gray-900 dark:text-white">
                                        Rp {{ number_format($item->total_price ?? 0, 0, ',', '.') }}
                                    </td>
                                </tr>
                                @endforeach
                            </tbody>
                            <tfoot>
                                <tr class="bg-primary/5 dark:bg-primary/10">
                                    <td colspan="5" class="px-4 py-3 text-right font-bold text-gray-800 dark:text-white rounded-bl-lg">
                                        Total
                                    </td>
                                    <td class="px-4 py-3 text-right font-bold text-primary text-lg rounded-br-lg">
                                        Rp {{ number_format($pickup->total_amount ?? 0, 0, ',', '.') }}
                                    </td>
                                </tr>
                            </tfoot>
                        </table>
                    </div>

                    <!-- Mobile Cards -->
                    <div class="md:hidden space-y-3">
                        @foreach($pickup->wasteDeliveryItems as $index => $item)
                        <div class="rounded-lg bg-gray-50 dark:bg-gray-700/30 p-4">
                            <div class="flex justify-between items-start mb-2">
                                <span class="font-medium text-gray-900 dark:text-white">
                                    {{ optional($item->waste)->category ?? '-' }}
                                </span>
                                <span class="text-xs bg-gray-200 dark:bg-gray-600 text-gray-600 dark:text-gray-300 px-2 py-0.5 rounded">
                                    {{ optional($item->pocketSize)->name ?? '-' }}
                                </span>
                            </div>
                            <div class="flex justify-between text-sm text-gray-600 dark:text-gray-400">
                                <span>{{ $item->quantity }} x Rp {{ number_format($item->unit_price ?? 0, 0, ',', '.') }}</span>
                                <span class="font-medium text-gray-900 dark:text-white">
                                    Rp {{ number_format($item->total_price ?? 0, 0, ',', '.') }}
                                </span>
                            </div>
                        </div>
                        @endforeach
                        
                        <!-- Total Mobile -->
                        <div class="rounded-lg bg-primary/10 p-4 flex justify-between items-center">
                            <span class="font-bold text-gray-800 dark:text-white">Total</span>
                            <span class="font-bold text-primary text-lg">
                                Rp {{ number_format($pickup->total_amount ?? 0, 0, ',', '.') }}
                            </span>
                        </div>
                    </div>
                </div>
                @endif

                <!-- Photo Evidence -->
                @if($pickup->photo_url)
                <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                    <div class="flex items-center gap-3 mb-4">
                        <div class="w-10 h-10 rounded-full bg-purple-500 flex items-center justify-center">
                            <i class="fas fa-camera text-white"></i>
                        </div>
                        <h3 class="text-lg font-semibold text-gray-800 dark:text-white">Foto Bukti Pengambilan</h3>
                    </div>
                    <div class="relative group">
                        <img src="{{ $pickup->photo_display_url ?? Storage::url($pickup->photo_url) }}" 
                             alt="Bukti Pengambilan Sampah"
                             class="w-full max-h-96 object-contain rounded-xl border border-gray-200 dark:border-gray-600 cursor-pointer"
                             onclick="openImageModal(this.src)">
                        <div class="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors rounded-xl flex items-center justify-center opacity-0 group-hover:opacity-100">
                            <span class="bg-white/90 dark:bg-gray-800/90 px-3 py-1.5 rounded-full text-sm font-medium text-gray-700 dark:text-gray-300">
                                <i class="fas fa-search-plus mr-1"></i>Klik untuk memperbesar
                            </span>
                        </div>
                    </div>
                </div>
                @else
                <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                    <div class="flex items-center gap-3 mb-4">
                        <div class="w-10 h-10 rounded-full bg-gray-400 flex items-center justify-center">
                            <i class="fas fa-camera text-white"></i>
                        </div>
                        <h3 class="text-lg font-semibold text-gray-800 dark:text-white">Foto Bukti Pengambilan</h3>
                    </div>
                    <div class="flex flex-col items-center justify-center py-12 text-gray-400 dark:text-gray-500">
                        <i class="fas fa-image text-5xl mb-3"></i>
                        <p class="text-sm">Foto tidak tersedia</p>
                    </div>
                </div>
                @endif

                <!-- Notes -->
                @if($pickup->resident_note || $pickup->collector_notes)
                <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                    <div class="flex items-center gap-3 mb-4">
                        <div class="w-10 h-10 rounded-full bg-indigo-500 flex items-center justify-center">
                            <i class="fas fa-sticky-note text-white"></i>
                        </div>
                        <h3 class="text-lg font-semibold text-gray-800 dark:text-white">Catatan</h3>
                    </div>
                    <div class="space-y-4">
                        @if($pickup->resident_note)
                        <div class="rounded-lg bg-blue-50 dark:bg-blue-900/20 p-4">
                            <div class="flex items-center gap-2 mb-2">
                                <i class="fas fa-user text-blue-500"></i>
                                <span class="text-sm font-medium text-blue-800 dark:text-blue-400">Catatan Warga</span>
                            </div>
                            <p class="text-sm text-gray-700 dark:text-gray-300">{{ $pickup->resident_note }}</p>
                        </div>
                        @endif
                        @if($pickup->collector_notes)
                        <div class="rounded-lg bg-green-50 dark:bg-green-900/20 p-4">
                            <div class="flex items-center gap-2 mb-2">
                                <i class="fas fa-truck text-green-500"></i>
                                <span class="text-sm font-medium text-green-800 dark:text-green-400">Catatan Collector</span>
                            </div>
                            <p class="text-sm text-gray-700 dark:text-gray-300">{{ $pickup->collector_notes }}</p>
                        </div>
                        @endif
                    </div>
                </div>
                @endif
            </div>

            <!-- Right Column: Timeline & Invoice -->
            <div class="space-y-6">
                <!-- Timeline Card -->
                <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                    <div class="flex items-center gap-3 mb-4">
                        <div class="w-10 h-10 rounded-full bg-cyan-500 flex items-center justify-center">
                            <i class="fas fa-history text-white"></i>
                        </div>
                        <h3 class="text-lg font-semibold text-gray-800 dark:text-white">Timeline</h3>
                    </div>
                    <div class="relative pl-6 border-l-2 border-gray-200 dark:border-gray-600 space-y-6">
                        <!-- Created -->
                        <div class="relative">
                            <div class="absolute -left-[25px] w-4 h-4 rounded-full bg-gray-400 border-4 border-white dark:border-gray-800"></div>
                            <p class="text-sm font-medium text-gray-900 dark:text-white">Dibuat</p>
                            <p class="text-xs text-gray-500 dark:text-gray-400">
                                {{ $pickup->created_at->format('d M Y, H:i') }}
                            </p>
                        </div>
                        
                        <!-- Confirmed -->
                        @if($pickup->confirmed_at)
                        <div class="relative">
                            <div class="absolute -left-[25px] w-4 h-4 rounded-full bg-blue-500 border-4 border-white dark:border-gray-800"></div>
                            <p class="text-sm font-medium text-gray-900 dark:text-white">Dikonfirmasi Warga</p>
                            <p class="text-xs text-gray-500 dark:text-gray-400">
                                {{ $pickup->confirmed_at->format('d M Y, H:i') }}
                            </p>
                        </div>
                        @endif

                        <!-- Collected -->
                        @if($pickup->collected_at)
                        <div class="relative">
                            <div class="absolute -left-[25px] w-4 h-4 rounded-full bg-green-500 border-4 border-white dark:border-gray-800"></div>
                            <p class="text-sm font-medium text-gray-900 dark:text-white">Sampah Diambil</p>
                            <p class="text-xs text-gray-500 dark:text-gray-400">
                                {{ $pickup->collected_at->format('d M Y, H:i') }}
                            </p>
                        </div>
                        @endif

                        <!-- Completed -->
                        @if($pickup->completed_at)
                        <div class="relative">
                            <div class="absolute -left-[25px] w-4 h-4 rounded-full bg-emerald-500 border-4 border-white dark:border-gray-800"></div>
                            <p class="text-sm font-medium text-gray-900 dark:text-white">Selesai</p>
                            <p class="text-xs text-gray-500 dark:text-gray-400">
                                {{ $pickup->completed_at->format('d M Y, H:i') }}
                            </p>
                        </div>
                        @endif

                        <!-- Current Status (if not completed) -->
                        @if(!$pickup->completed_at)
                        <div class="relative">
                            <div class="absolute -left-[25px] w-4 h-4 rounded-full bg-yellow-500 border-4 border-white dark:border-gray-800 animate-pulse"></div>
                            <p class="text-sm font-medium text-yellow-600 dark:text-yellow-400">
                                @if($pickup->status === 'pending')
                                    Menunggu Konfirmasi
                                @elseif($pickup->status === 'confirmed')
                                    Menunggu Pengambilan
                                @elseif($pickup->status === 'in_progress')
                                    Sedang Dalam Proses
                                @elseif($pickup->status === 'collected')
                                    Menunggu Verifikasi
                                @else
                                    {{ ucfirst($pickup->status) }}
                                @endif
                            </p>
                        </div>
                        @endif
                    </div>
                </div>

                <!-- Invoice Card -->
                @if($pickup->invoice)
                <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                    <div class="flex items-center gap-3 mb-4">
                        <div class="w-10 h-10 rounded-full bg-emerald-500 flex items-center justify-center">
                            <i class="fas fa-file-invoice text-white"></i>
                        </div>
                        <h3 class="text-lg font-semibold text-gray-800 dark:text-white">Invoice</h3>
                    </div>
                    <div class="space-y-3">
                        <div class="flex justify-between items-center">
                            <span class="text-sm text-gray-600 dark:text-gray-400">Nomor Invoice:</span>
                            <span class="text-sm font-mono font-medium text-gray-900 dark:text-white">
                                {{ $pickup->invoice->invoice_number }}
                            </span>
                        </div>
                        <div class="flex justify-between items-center">
                            <span class="text-sm text-gray-600 dark:text-gray-400">Status:</span>
                            @php
                                $invStatusConfig = [
                                    'pending' => ['bg' => 'bg-yellow-100', 'text' => 'text-yellow-800', 'label' => 'Pending'],
                                    'paid' => ['bg' => 'bg-green-100', 'text' => 'text-green-800', 'label' => 'Lunas'],
                                    'unpaid' => ['bg' => 'bg-red-100', 'text' => 'text-red-800', 'label' => 'Belum Lunas'],
                                ];
                                $invStatus = $invStatusConfig[$pickup->invoice->status] ?? $invStatusConfig['pending'];
                            @endphp
                            <span class="px-2 py-0.5 text-xs font-semibold rounded-full {{ $invStatus['bg'] }} {{ $invStatus['text'] }}">
                                {{ $invStatus['label'] }}
                            </span>
                        </div>
                        <div class="flex justify-between items-center">
                            <span class="text-sm text-gray-600 dark:text-gray-400">Total:</span>
                            <span class="text-base font-bold text-primary">
                                Rp {{ number_format($pickup->invoice->total_amount, 0, ',', '.') }}
                            </span>
                        </div>
                        <div class="flex justify-between items-center">
                            <span class="text-sm text-gray-600 dark:text-gray-400">Dibuat:</span>
                            <span class="text-sm text-gray-900 dark:text-white">
                                {{ $pickup->invoice->issued_at ? $pickup->invoice->issued_at->format('d M Y') : '-' }}
                            </span>
                        </div>
                        @if($pickup->invoice->paid_at)
                        <div class="flex justify-between items-center">
                            <span class="text-sm text-gray-600 dark:text-gray-400">Dibayar:</span>
                            <span class="text-sm text-gray-900 dark:text-white">
                                {{ $pickup->invoice->paid_at->format('d M Y, H:i') }}
                            </span>
                        </div>
                        @endif
                    </div>
                </div>
                @endif

                <!-- Quick Info Card -->
                <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                    <div class="flex items-center gap-3 mb-4">
                        <div class="w-10 h-10 rounded-full bg-gray-500 flex items-center justify-center">
                            <i class="fas fa-info text-white"></i>
                        </div>
                        <h3 class="text-lg font-semibold text-gray-800 dark:text-white">Info Lainnya</h3>
                    </div>
                    <div class="space-y-3 text-sm">
                        <div class="flex justify-between">
                            <span class="text-gray-600 dark:text-gray-400">ID:</span>
                            <span class="font-mono text-gray-900 dark:text-white">#{{ $pickup->id }}</span>
                        </div>
                        @if($pickup->schedule)
                        <div class="flex justify-between">
                            <span class="text-gray-600 dark:text-gray-400">Jadwal:</span>
                            <span class="text-gray-900 dark:text-white">
                                {{ ucfirst($pickup->schedule->day_of_week ?? '-') }}
                            </span>
                        </div>
                        @endif
                        <div class="flex justify-between">
                            <span class="text-gray-600 dark:text-gray-400">Tipe:</span>
                            <span class="text-gray-900 dark:text-white">
                                {{ $pickup->is_off_schedule ? 'Off Schedule' : 'Terjadwal' }}
                            </span>
                        </div>
                        <div class="flex justify-between">
                            <span class="text-gray-600 dark:text-gray-400">Terakhir Update:</span>
                            <span class="text-gray-900 dark:text-white">
                                {{ $pickup->updated_at->format('d M Y, H:i') }}
                            </span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Image Modal -->
<div id="imageModal" class="fixed inset-0 z-50 hidden items-center justify-center p-4 bg-black/80">
    <button onclick="closeImageModal()" class="absolute top-4 right-4 text-white hover:text-gray-300 text-3xl">
        <i class="fas fa-times"></i>
    </button>
    <img id="modalImage" src="" alt="Full Image" class="max-w-full max-h-[90vh] object-contain rounded-lg">
</div>

@push('body:end')
<script>
function openImageModal(src) {
    document.getElementById('modalImage').src = src;
    const modal = document.getElementById('imageModal');
    modal.classList.remove('hidden');
    modal.classList.add('flex');
}

function closeImageModal() {
    const modal = document.getElementById('imageModal');
    modal.classList.add('hidden');
    modal.classList.remove('flex');
}

document.getElementById('imageModal').addEventListener('click', function(e) {
    if (e.target === this) {
        closeImageModal();
    }
});

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeImageModal();
    }
});
</script>
@endpush
@endsection
