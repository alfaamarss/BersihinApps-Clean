<?php

namespace Database\Seeders;

use App\Models\CollectorAssignment;
use App\Models\Complaint;
use App\Models\ComplaintPhoto;
use App\Models\GarbageDump;
use App\Models\ServiceAccount;
use App\Models\TpsDeposit;
use App\Models\User;
use App\Models\WasteDelivery;
use App\Models\WasteDeliveryItem;
use Carbon\Carbon;
use Illuminate\Database\Seeder;

class RealHistorySeeder extends Seeder
{
    public function run(): void
    {
        $collector = User::find(2); // Collector
        if (!$collector) {
            $this->command->error('Collector user ID 2 not found.');
            return;
        }

        // 1. Create Residents
        $budi = User::firstOrCreate(
            ['email' => 'budi@example.com'],
            [
                'name' => 'Budi Santoso',
                'password' => bcrypt('password'),
                'email_verified_at' => now(),
            ]
        );
        try { $budi->assignRole('warga'); } catch (\Throwable $e) {}

        $siti = User::firstOrCreate(
            ['email' => 'siti@example.com'],
            [
                'name' => 'Siti Rahmawati',
                'password' => bcrypt('password'),
                'email_verified_at' => now(),
            ]
        );
        try { $siti->assignRole('warga'); } catch (\Throwable $e) {}

        // 2. Create Service Accounts
        $saBudi = ServiceAccount::firstOrCreate(
            ['name' => 'SRD-05-014'],
            [
                'user_id' => $budi->id,
                'area_id' => 107,
                'rw_id' => 505,
                'contact_phone' => '081234567891',
                'address' => 'Perumahan Suradita Blok B2 No. 14, RW 05',
                'latitude' => '-6.3436000',
                'longitude' => '106.6363000',
                'status' => 'active',
            ]
        );

        $saSiti = ServiceAccount::firstOrCreate(
            ['name' => 'SRD-05-028'],
            [
                'user_id' => $siti->id,
                'area_id' => 107,
                'rw_id' => 505,
                'contact_phone' => '081298765432',
                'address' => 'Jl. Kenanga Asri No. 8, RW 05',
                'latitude' => '-6.3437000',
                'longitude' => '106.6364000',
                'status' => 'active',
            ]
        );

        // Ensure Collector is assigned to schedule 1
        CollectorAssignment::firstOrCreate(
            ['user_id' => $collector->id, 'schedule_id' => 1],
            ['start_date' => Carbon::now()->subMonths(1), 'end_date' => null]
        );

        // 3. Seed Completed Scheduled Pickups (PENGAMBILAN REGULER)
        $today = Carbon::today();

        // Delivery A: Budi Santoso - Today Scheduled
        $deliveryA = WasteDelivery::updateOrCreate(
            [
                'service_account_id' => $saBudi->id,
                'pickup_date' => $today->toDateString(),
                'pickup_type' => 'scheduled',
            ],
            [
                'schedule_id' => 1,
                'request_status' => null,
                'assigned_collector_id' => $collector->id,
                'bag_count' => 3,
                'base_amount' => 13500,
                'total_amount' => 13500,
                'status' => 'completed',
                'confirmation_status' => 'confirmed',
                'scheduled_at' => $today->copy()->setTime(8, 0),
                'collected_at' => $today->copy()->setTime(8, 35),
                'confirmed_at' => $today->copy()->setTime(8, 35),
                'completed_at' => $today->copy()->setTime(8, 36),
                'resident_note' => 'Sampah daun pekarangan dan botol minuman',
                'collector_notes' => 'Sampah telah diambil dan dipilah rapi',
                'photo_url' => 'pickups/off_schedule_2_1794112837.jpg',
            ]
        );

        // Items for Delivery A
        WasteDeliveryItem::where('waste_delivery_id', $deliveryA->id)->delete();
        WasteDeliveryItem::create([
            'waste_delivery_id' => $deliveryA->id,
            'waste_id' => 1, // Organik
            'pocket_size_id' => 1, // Besar
            'quantity' => 2,
            'unit_price' => 5000,
            'total_price' => 10000,
        ]);
        WasteDeliveryItem::create([
            'waste_delivery_id' => $deliveryA->id,
            'waste_id' => 2, // Anorganik
            'pocket_size_id' => 2, // Sedang
            'quantity' => 1,
            'unit_price' => 3500,
            'total_price' => 3500,
        ]);

        // Delivery B: Siti Rahmawati - Today Scheduled
        $deliveryB = WasteDelivery::updateOrCreate(
            [
                'service_account_id' => $saSiti->id,
                'pickup_date' => $today->toDateString(),
                'pickup_type' => 'scheduled',
            ],
            [
                'schedule_id' => 1,
                'request_status' => null,
                'assigned_collector_id' => $collector->id,
                'bag_count' => 2,
                'base_amount' => 10500,
                'total_amount' => 10500,
                'status' => 'completed',
                'confirmation_status' => 'confirmed',
                'scheduled_at' => $today->copy()->setTime(9, 0),
                'collected_at' => $today->copy()->setTime(9, 15),
                'confirmed_at' => $today->copy()->setTime(9, 15),
                'completed_at' => $today->copy()->setTime(9, 16),
                'resident_note' => 'Sampah dapur sudah dipilah rapi dalam kantong',
                'collector_notes' => 'Pengambilan selesai tanpa kendala',
                'photo_url' => 'pickups/off_schedule_1_1794059434.jpg',
            ]
        );

        // Items for Delivery B
        WasteDeliveryItem::where('waste_delivery_id', $deliveryB->id)->delete();
        WasteDeliveryItem::create([
            'waste_delivery_id' => $deliveryB->id,
            'waste_id' => 1, // Organik
            'pocket_size_id' => 2, // Sedang
            'quantity' => 1,
            'unit_price' => 3500,
            'total_price' => 3500,
        ]);
        WasteDeliveryItem::create([
            'waste_delivery_id' => $deliveryB->id,
            'waste_id' => 2, // Anorganik
            'pocket_size_id' => 1, // Besar
            'quantity' => 1,
            'unit_price' => 7000,
            'total_price' => 7000,
        ]);

        // 4. Seed Completed Off-Schedule Request (REQUEST PENGAMBILAN)
        $deliveryC = WasteDelivery::updateOrCreate(
            [
                'service_account_id' => $saBudi->id,
                'pickup_type' => 'request',
                'requested_at' => Carbon::yesterday()->setTime(13, 0),
            ],
            [
                'schedule_id' => null,
                'request_status' => 'paid',
                'requested_pickup_date' => Carbon::yesterday()->toDateString(),
                'pickup_date' => Carbon::yesterday()->toDateString(),
                'requested_pickup_time' => '14:00:00',
                'requested_by' => $budi->id,
                'assigned_collector_id' => $collector->id,
                'bag_count' => 4,
                'base_amount' => 20000,
                'total_amount' => 20000,
                'status' => 'completed',
                'confirmation_status' => 'confirmed',
                'collected_at' => Carbon::yesterday()->setTime(14, 15),
                'confirmed_at' => Carbon::yesterday()->setTime(14, 15),
                'completed_at' => Carbon::yesterday()->setTime(14, 20),
                'resident_note' => 'Penjemputan khusus limbah kardus dan sisa kebun',
                'collector_notes' => 'Sudah ditimbang dan diselesaikan pembayaran',
                'photo_url' => 'pickups/off_schedule_1_1794147372.jpg',
            ]
        );

        WasteDeliveryItem::where('waste_delivery_id', $deliveryC->id)->delete();
        WasteDeliveryItem::create([
            'waste_delivery_id' => $deliveryC->id,
            'waste_id' => 1, // Organik
            'pocket_size_id' => 1, // Besar
            'quantity' => 2,
            'unit_price' => 5000,
            'total_price' => 10000,
        ]);
        WasteDeliveryItem::create([
            'waste_delivery_id' => $deliveryC->id,
            'waste_id' => 2, // Anorganik
            'pocket_size_id' => 2, // Sedang
            'quantity' => 2,
            'unit_price' => 5000,
            'total_price' => 10000,
        ]);

        // 5. Seed Resolved Complaint (TUGAS PENGADUAN)
        $warga = User::find(3);
        $saWarga = ServiceAccount::where('user_id', 3)->first();

        $complaint = Complaint::updateOrCreate(
            [
                'user_id' => 3,
                'type' => 'sampah_menumpuk',
                'address' => 'Samping Pos Ronda RW 05 Suradita',
            ],
            [
                'service_account_id' => $saWarga?->id,
                'assignee_id' => $collector->id,
                'description' => 'Ada penumpukan sampah liar di samping Pos Ronda RW 05, mohon segera diangkut.',
                'latitude' => -6.3435140,
                'longitude' => 106.6362308,
                'status' => 'resolved',
                'resolution_photo' => 'pickups/off_schedule_1_1794147372.jpg',
                'resolution_description' => 'Lokasi sudah dibersihkan total dan sampah telah disetor ke TPS.',
                'created_at' => Carbon::now()->subHours(4),
                'updated_at' => Carbon::now()->subHours(2),
            ]
        );

        ComplaintPhoto::updateOrCreate(
            ['complaint_id' => $complaint->id, 'order' => 1],
            ['photo_url' => 'pickups/off_schedule_1_1794147372.jpg']
        );

        // 6. Seed TPS Deposit (PENGANGKUTAN)
        $tps = GarbageDump::where('status', 'active')->first();
        if ($tps) {
            TpsDeposit::updateOrCreate(
                [
                    'collector_id' => $collector->id,
                    'garbage_dump_id' => $tps->id,
                    'deposited_at' => Carbon::now()->subHours(1)->format('Y-m-d H:i:s'),
                ],
                [
                    'latitude' => $tps->latitude ?? -6.3431484,
                    'longitude' => $tps->longitude ?? 106.675595,
                    'notes' => 'Setoran sampah rute RW 05 Suradita - Muatan 1 Gerobak penuh (estimasi 185 kg)',
                ]
            );
        }

        $this->command->info('Real history data seeded successfully for collector ID ' . $collector->id);
    }
}
