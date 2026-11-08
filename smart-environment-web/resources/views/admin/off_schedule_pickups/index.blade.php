@extends('layouts.master')

@section('title', 'Pickup Luar Jadwal')

@section('content')
@php
    $statusLabels = [
        'sent' => 'Terkirim',
        'processing' => 'Diproses',
        'pending' => 'Pending',
        'completed' => 'Selesai',
        'paid' => 'Paid',
        'rejected' => 'Ditolak',
    ];

    $statusBadges = [
        'sent' => 'bg-sky-100 text-sky-700 dark:bg-sky-900/30 dark:text-sky-300',
        'processing' => 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300',
        'pending' => 'bg-indigo-100 text-indigo-700 dark:bg-indigo-900/30 dark:text-indigo-300',
        'completed' => 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300',
        'paid' => 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300',
        'rejected' => 'bg-rose-100 text-rose-700 dark:bg-rose-900/30 dark:text-rose-300',
    ];
@endphp
<div class="grid grid-cols-12 gap-4 md:gap-6">
  <div class="col-span-12">
    <div class="rounded-2xl border border-gray-200 bg-white p-6 shadow-theme-sm dark:border-gray-800 dark:bg-white/[0.03]">
      <div class="mb-6 flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 class="text-2xl font-bold text-black dark:text-white">Pickup Luar Jadwal</h2>
          <p class="text-sm text-gray-500 mt-1">Pantau permintaan warga di luar jadwal rutin</p>
        </div>
      </div>

      <form method="GET" class="mb-6 flex flex-wrap items-end gap-3">
        <div class="w-full md:w-[260px]">
          <x-form.input name="search" label="Cari warga/alamat" value="{{ request('search') }}" placeholder="Nama warga atau alamat" />
        </div>
        <div class="w-full md:w-[220px]">
          <x-form.select name="status" label="Status" :options="$statusLabels" placeholder="Semua Status" :value="request('status')" />
        </div>
        <div>
          <x-button type="submit" variant="primary">Filter</x-button>
        </div>
      </form>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-800">
          <thead>
            <tr class="text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
              <th class="px-4 py-3">Warga</th>
              <th class="px-4 py-3">Tanggal Diminta</th>
              <th class="px-4 py-3">Kolektor</th>
              <th class="px-4 py-3">Kantong</th>
              <th class="px-4 py-3">Total</th>
              <th class="px-4 py-3">Status</th>
              <th class="px-4 py-3">Aksi</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 text-sm">
          @forelse($deliveries as $delivery)
            <tr class="text-gray-700 dark:text-gray-200">
              <td class="px-4 py-4">
                <div class="font-semibold text-black dark:text-white">{{ $delivery->serviceAccount->name ?? '-' }}</div>
                <div class="text-xs text-gray-500">{{ $delivery->serviceAccount->address ?? '-' }}</div>
              </td>
              <td class="px-4 py-4">
                <div>{{ optional($delivery->requested_pickup_date)->format('d M Y') ?? '-' }}</div>
                <div class="text-xs text-gray-500">
                  {{ $delivery->requested_pickup_time ? substr($delivery->requested_pickup_time, 0, 5) : '-' }}
                </div>
              </td>
              <td class="px-4 py-4">
                {{ $delivery->assignedCollector->name ?? 'Belum ditugaskan' }}
              </td>
              <td class="px-4 py-4">
                {{ $delivery->bag_count ?: ($delivery->wasteDeliveryItems->sum('quantity') ?: 0) }} kantong
              </td>
              <td class="px-4 py-4 font-semibold">
                Rp {{ number_format($delivery->total_amount, 0, ',', '.') }}
              </td>
              <td class="px-4 py-4">
                <span class="rounded-full px-3 py-1 text-xs font-semibold {{ $statusBadges[$delivery->request_status] ?? 'bg-gray-100 text-gray-700' }}">
                  {{ $statusLabels[$delivery->request_status] ?? ucfirst($delivery->request_status ?? 'unknown') }}
                </span>
              </td>
              <td class="px-4 py-4">
                <x-button as="a" href="{{ route('admin.off-schedule-pickups.show', $delivery->id) }}" size="sm" variant="secondary">Detail</x-button>
              </td>
            </tr>
          @empty
            <tr>
              <td colspan="7" class="px-4 py-6 text-center text-gray-500">Belum ada request</td>
            </tr>
          @endforelse
          </tbody>
        </table>
      </div>

      <div class="mt-6">
        {{ $deliveries->links() }}
      </div>
    </div>
  </div>
</div>
@endsection
