@extends('layouts.master')

@section('title', 'Detail Pickup Luar Jadwal')

@php
  use Illuminate\Support\Facades\Storage;

    $statusLabels = [
        'sent' => 'Terkirim',
        'processing' => 'Diproses',
        'pending' => 'Pending',
        'completed' => 'Selesai',
        'paid' => 'Paid',
        'rejected' => 'Ditolak',
    ];
@endphp

@section('content')
<div class="mb-6 flex items-center justify-between">
  <h2 class="text-2xl font-bold text-gray-900 dark:text-white">Detail Pickup Luar Jadwal</h2>
  <x-button as="a" href="{{ route('admin.off-schedule-pickups.index') }}" variant="secondary">
    ← Kembali
  </x-button>
</div>

<div class="grid grid-cols-12 gap-4 md:gap-6">
  <div class="col-span-12 lg:col-span-8">
    <div class="rounded-2xl border border-gray-200 bg-white p-6 shadow-theme-sm dark:border-gray-800 dark:bg-white/[0.03]">
      <div class="mb-6 flex items-center justify-between">
        <div>
          <h2 class="text-2xl font-bold text-black dark:text-white">{{ $delivery->serviceAccount->name ?? 'Akun Layanan' }}</h2>
          <p class="text-sm text-gray-500 mt-1">{{ $delivery->serviceAccount->address }}</p>
        </div>
        <span class="rounded-full px-4 py-1 text-sm font-semibold bg-gray-100 text-gray-700">
          {{ $statusLabels[$delivery->request_status] ?? ucfirst($delivery->request_status ?? 'unknown') }}
        </span>
      </div>

      <dl class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div>
          <dt class="text-sm text-gray-500">Tanggal diminta</dt>
          <dd class="text-base font-semibold text-black dark:text-white">{{ optional($delivery->requested_pickup_date)->format('d M Y') ?? '-' }}</dd>
        </div>
        <div>
          <dt class="text-sm text-gray-500">Jam</dt>
          <dd class="text-base font-semibold text-black dark:text-white">{{ $delivery->requested_pickup_time ? substr($delivery->requested_pickup_time, 0, 5) : '-' }}</dd>
        </div>
        <div>
          <dt class="text-sm text-gray-500">Jumlah kantong</dt>
          <dd class="text-base font-semibold text-black dark:text-white">{{ $delivery->bag_count ?: ($delivery->wasteDeliveryItems?->sum('quantity') ?: 0) }} kantong</dd>
        </div>
        <div>
          <dt class="text-sm text-gray-500">Perkiraan biaya</dt>
          <dd class="text-base font-semibold text-black dark:text-white">Rp {{ number_format($delivery->base_amount ?: ($delivery->wasteDeliveryItems?->sum('total_price') ?: 0), 0, ',', '.') }}</dd>
        </div>
        <div>
          <dt class="text-sm text-gray-500">Biaya tambahan</dt>
          <dd class="text-base font-semibold text-black dark:text-white">Rp {{ number_format($delivery->extra_fee, 0, ',', '.') }}</dd>
        </div>
        <div>
          <dt class="text-sm text-gray-500">Total</dt>
          <dd class="text-2xl font-bold text-black dark:text-white">Rp {{ number_format($delivery->total_amount, 0, ',', '.') }}</dd>
        </div>
      </dl>

      @if($delivery->wasteDeliveryItems && $delivery->wasteDeliveryItems->count() > 0)
      <div class="mt-6">
        <h3 class="text-sm font-semibold text-gray-500 uppercase mb-3">Detail Sampah</h3>
        <div class="overflow-x-auto">
          <table class="min-w-full text-sm">
            <thead>
              <tr class="border-b border-gray-200 dark:border-gray-700">
                <th class="text-left py-2 font-medium text-gray-500">Jenis</th>
                <th class="text-left py-2 font-medium text-gray-500">Ukuran</th>
                <th class="text-center py-2 font-medium text-gray-500">Qty</th>
                <th class="text-right py-2 font-medium text-gray-500">Harga</th>
                <th class="text-right py-2 font-medium text-gray-500">Subtotal</th>
              </tr>
            </thead>
            <tbody>
              @foreach($delivery->wasteDeliveryItems as $item)
              <tr class="border-b border-gray-100 dark:border-gray-800">
                <td class="py-2 text-black dark:text-white">{{ $item->waste?->name ?? '-' }}</td>
                <td class="py-2 text-black dark:text-white">{{ $item->pocketSize?->name ?? '-' }}</td>
                <td class="py-2 text-center text-black dark:text-white">{{ $item->quantity }}</td>
                <td class="py-2 text-right text-black dark:text-white">Rp {{ number_format($item->unit_price, 0, ',', '.') }}</td>
                <td class="py-2 text-right text-black dark:text-white">Rp {{ number_format($item->total_price, 0, ',', '.') }}</td>
              </tr>
              @endforeach
              <tr class="border-t-2 border-gray-300 dark:border-gray-600">
                <td colspan="4" class="py-2 text-right font-medium text-gray-500">Subtotal:</td>
                <td class="py-2 text-right font-semibold text-black dark:text-white">Rp {{ number_format($delivery->base_amount ?: ($delivery->wasteDeliveryItems?->sum('total_price') ?: 0), 0, ',', '.') }}</td>
              </tr>
              <tr>
                <td colspan="4" class="py-2 text-right font-medium text-gray-500">Biaya Tambahan:</td>
                <td class="py-2 text-right font-semibold text-black dark:text-white">Rp {{ number_format($delivery->extra_fee, 0, ',', '.') }}</td>
              </tr>
              <tr class="bg-gray-50 dark:bg-gray-800">
                <td colspan="4" class="py-2 text-right font-bold text-black dark:text-white">Total:</td>
                <td class="py-2 text-right font-bold text-black dark:text-white">Rp {{ number_format($delivery->total_amount, 0, ',', '.') }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      @endif

      <div class="mt-6 space-y-4">
        <div>
          <h3 class="text-sm font-semibold text-gray-500 uppercase">Catatan Warga</h3>
          <p class="text-base text-black dark:text-white mt-1">{{ $delivery->resident_note ?? '-' }}</p>
        </div>
        <div>
          <h3 class="text-sm font-semibold text-gray-500 uppercase">Catatan Kolektor</h3>
          <p class="text-base text-black dark:text-white mt-1">{{ $delivery->collector_notes ?? '-' }}</p>
        </div>
        <div>
          <h3 class="text-sm font-semibold text-gray-500 uppercase mb-2">Bukti Pickup</h3>
          @php
            $photoSrc = $delivery->photo_display_url ?? ($delivery->photo_url ? Storage::url($delivery->photo_url) : null);
          @endphp
          @if($photoSrc)
            <div class="mt-2">
              <a href="{{ $photoSrc }}" target="_blank" class="group inline-block relative overflow-hidden rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm bg-gray-50 dark:bg-gray-800 p-1">
                <img src="{{ $photoSrc }}" 
                     alt="Bukti pickup" 
                     class="rounded-lg max-h-96 w-auto max-w-md object-contain hover:scale-[1.01] transition-transform duration-200"
                     onerror="this.onerror=null; this.parentElement.innerHTML='<div class=\'p-4 text-sm text-red-500 bg-red-50 rounded-lg flex items-center gap-2\'><i class=\'fas fa-exclamation-triangle\'></i> Gagal memuat file foto bukti.</div>';">
                <div class="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center opacity-0 group-hover:opacity-100 rounded-xl">
                  <span class="bg-white/90 dark:bg-gray-900/90 text-gray-800 dark:text-white text-xs font-semibold px-3 py-1.5 rounded-full shadow">
                    <i class="fas fa-search-plus mr-1"></i> Buka Gambar Penuh
                  </span>
                </div>
              </a>
              <p class="text-xs text-gray-500 dark:text-gray-400 mt-1.5 flex items-center gap-1">
                <i class="fas fa-info-circle text-primary-500"></i> Klik foto untuk melihat resolusi penuh
              </p>
            </div>
          @else
            <p class="text-sm text-gray-400 italic mt-1">Belum ada foto bukti</p>
          @endif
        </div>
      </div>
    </div>
  </div>

  <div class="col-span-12 lg:col-span-4">
    <div class="rounded-2xl border border-gray-200 bg-white p-6 shadow-theme-sm dark:border-gray-800 dark:bg-white/[0.03] space-y-6">
      @if(!in_array($delivery->request_status, ['completed', 'paid', 'rejected']))
      
      @if(in_array($delivery->request_status, ['processing', 'pending']))
        {{-- Status sedang Diproses atau Pending - tampilkan info dan link ke Monitor --}}
        <div class="bg-amber-50 dark:bg-amber-900/20 rounded-lg p-4 border border-amber-200 dark:border-amber-700">
          <div class="flex items-start gap-3">
            <div class="w-10 h-10 rounded-full bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center flex-shrink-0">
              <svg class="w-5 h-5 text-amber-600 dark:text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
            </div>
            <div>
              <h4 class="font-semibold text-amber-900 dark:text-amber-200">
                @if($delivery->request_status === 'processing')
                  Request Sedang Diproses
                @else
                  Menunggu Konfirmasi Warga
                @endif
              </h4>
              <p class="text-sm text-amber-700 dark:text-amber-300 mt-1">
                @if($delivery->request_status === 'processing')
                  Kolektor telah ditugaskan. Pantau progress pengambilan di menu Monitor Pengambilan.
                @else
                  Collector telah mengambil sampah. Menunggu konfirmasi dari warga.
                @endif
              </p>
            </div>
          </div>
        </div>
        
        <x-button as="a" href="{{ route('admin.pickups.monitor') }}" variant="primary" class="w-full">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
          </svg>
          Lihat di Monitor Pengambilan
        </x-button>
        
        {{-- Info kolektor yang ditugaskan --}}
        @if($delivery->assignedCollector)
        <div class="border-t border-gray-200 dark:border-gray-700 pt-4">
          <h3 class="text-sm font-semibold text-gray-500 uppercase mb-2">Kolektor Ditugaskan</h3>
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center">
              <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
              </svg>
            </div>
            <div>
              <p class="font-semibold text-black dark:text-white">{{ $delivery->assignedCollector->name }}</p>
              <p class="text-sm text-gray-500">{{ $delivery->assignedCollector->phone ?? '-' }}</p>
            </div>
          </div>
        </div>
        @endif
        
        {{-- Info biaya yang sudah ditetapkan (read-only) --}}
        <div class="border-t border-gray-200 dark:border-gray-700 pt-4">
          <h3 class="text-sm font-semibold text-gray-500 uppercase mb-2">Biaya Tambahan</h3>
          <p class="text-xl font-bold text-black dark:text-white">Rp {{ number_format($delivery->extra_fee, 0, ',', '.') }}</p>
          <p class="text-xs text-gray-500 mt-1">
            <svg class="w-4 h-4 inline-block mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
            </svg>
            Biaya tidak dapat diubah setelah kolektor ditugaskan
          </p>
        </div>
        
      @else
        {{-- Status sent - tampilkan form penugasan --}}
      <div>
        <h3 class="text-lg font-semibold text-black dark:text-white">Tugas Kolektor</h3>
        <form action="{{ route('admin.off-schedule-pickups.assign', $delivery->id) }}" method="POST" class="space-y-3">
          @csrf
          <div class="space-y-1">
            <label for="collector_id" class="mb-1.5 block text-sm font-medium text-black dark:text-white">Pilih Kolektor <span class="text-red-500">*</span></label>
            <select id="collector_id" name="collector_id" required class="w-full rounded-lg border border-gray-200 bg-white px-4 py-2.5 pr-10 text-sm text-gray-800 focus:border-primary focus:outline-none dark:border-gray-700 dark:bg-gray-800 dark:text-gray-300">
              <option value="">Pilih kolektor...</option>
              @foreach($collectors as $collector)
                <option value="{{ $collector->id }}" {{ old('collector_id', $delivery->assigned_collector_id) == $collector->id ? 'selected' : '' }}>
                  {{ $collector->name }}
                </option>
              @endforeach
            </select>
            @error('collector_id')
              <p class="text-xs text-red-600 dark:text-red-400">{{ $message }}</p>
            @enderror
          </div>
          <!-- <x-form.input name="bag_count" label="Perkiraan kantong" type="number" min="0" value="{{ old('bag_count', $delivery->bag_count) }}" /> -->
          <div class="space-y-1">
            <x-form.input name="extra_fee" label="Biaya tambahan (surcharge)" type="number" step="1000" value="{{ old('extra_fee', $delivery->extra_fee ?: $defaultSurcharge) }}" />
            <p class="text-xs text-gray-500">Default dari pengaturan: Rp {{ number_format($defaultSurcharge, 0, ',', '.') }}</p>
          </div>
          <x-button type="submit" variant="primary" class="w-full">Simpan penugasan</x-button>
        </form>
      </div>

      <div class="border-t border-gray-200 dark:border-gray-700 pt-4">
        <h3 class="text-lg font-semibold text-black dark:text-white mb-2">Perbarui Estimasi Biaya</h3>
        <form action="{{ route('admin.off-schedule-pickups.update-cost', $delivery->id) }}" method="POST" class="space-y-3">
          @csrf
          <x-form.input name="bag_count" label="Perkiraan jumlah kantong" type="number" min="0" value="{{ old('bag_count', $delivery->bag_count) }}" />
          <x-form.input name="extra_fee" label="Biaya tambahan (surcharge)" type="number" step="1000" value="{{ old('extra_fee', $delivery->extra_fee ?: $defaultSurcharge) }}" />
          <x-button type="submit" variant="secondary" class="w-full">Simpan Perubahan Biaya</x-button>
        </form>
      </div>

      <div>
        <h3 class="text-lg font-semibold text-black dark:text-white">Aksi</h3>
        <form action="{{ route('admin.off-schedule-pickups.reject', $delivery->id) }}" method="POST" class="space-y-3" onsubmit="return confirm('Tolak request ini?');">
          @csrf
          <x-form.textarea name="reason" label="Alasan penolakan" rows="3" required></x-form.textarea>
          <x-button type="submit" variant="danger" class="w-full">Tolak Request</x-button>
        </form>
      </div>
      @endif
      @endif

      @if($delivery->invoice)
        <div class="border-t border-gray-200 pt-4">
          <p class="text-sm text-gray-500">Invoice</p>
          <p class="text-base font-semibold text-black dark:text-white">#{{ $delivery->invoice->invoice_number }} ({{ strtoupper($delivery->invoice->status) }})</p>
          <x-button as="a" href="{{ route('admin.invoices.show', $delivery->invoice->id) }}" variant="secondary" size="sm" class="mt-2 w-full">Lihat Invoice</x-button>
        </div>
      @endif

      @if(in_array($delivery->request_status, ['completed', 'paid', 'rejected']))
        <div class="p-4 rounded-lg bg-gray-50 dark:bg-gray-800">
          <p class="text-sm text-gray-600 dark:text-gray-400">
            @if($delivery->request_status === 'rejected')
              Request ini telah ditolak.
            @elseif($delivery->request_status === 'paid')
              Request ini telah selesai dan dibayar.
            @else
              Request ini telah dikonfirmasi warga.
            @endif
          </p>
        </div>
      @endif
    </div>
  </div>
</div>
@endsection
