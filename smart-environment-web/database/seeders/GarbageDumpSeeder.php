<?php

namespace Database\Seeders;

use App\Models\Area;
use App\Models\GarbageDump;
use App\Models\Rw;
use Illuminate\Database\Seeder;

class GarbageDumpSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $tpsList = [
            [
                'name' => 'TPS Cikokol',
                'kecamatan_name' => 'Tangerang',
                'kelurahan_name' => 'Cikokol',
                'address' => 'Jl. Perintis Kemerdekaan, Cikokol, Kec. Tangerang, Kota Tangerang',
                'latitude' => -6.1925,
                'longitude' => 106.6341,
                'capacity_volume' => 150.0,
                'capacity_weight' => 5000.0,
                'status' => 'active',
            ],
            [
                'name' => 'TPS Poris Plawad',
                'kecamatan_name' => 'Cipondoh',
                'kelurahan_name' => 'Poris Plawad',
                'address' => 'Jl. Benteng Betawi, Poris Plawad, Kec. Cipondoh, Kota Tangerang',
                'latitude' => -6.1772,
                'longitude' => 106.6614,
                'capacity_volume' => 120.0,
                'capacity_weight' => 4000.0,
                'status' => 'active',
            ],
            [
                'name' => 'TPA Rawa Kucing',
                'kecamatan_name' => 'Neglasari',
                'kelurahan_name' => 'Neglasari',
                'address' => 'Jl. Iskandar Muda, Kedaung Wetan, Kec. Neglasari, Kota Tangerang',
                'latitude' => -6.1481,
                'longitude' => 106.6394,
                'capacity_volume' => 1000.0,
                'capacity_weight' => 50000.0,
                'status' => 'active',
            ],
            [
                'name' => 'TPS Cimone',
                'kecamatan_name' => 'Karawaci',
                'kelurahan_name' => 'Cimone',
                'address' => 'Jl. Merdeka, Cimone, Kec. Karawaci, Kota Tangerang',
                'latitude' => -6.1956,
                'longitude' => 106.6025,
                'capacity_volume' => 100.0,
                'capacity_weight' => 3500.0,
                'status' => 'active',
            ],
            [
                'name' => 'TPS Ciledug Indah',
                'kecamatan_name' => 'Ciledug',
                'kelurahan_name' => 'Sudimara Barat',
                'address' => 'Jl. Raden Fatah, Sudimara Barat, Kec. Ciledug, Kota Tangerang',
                'latitude' => -6.2281,
                'longitude' => 106.7089,
                'capacity_volume' => 90.0,
                'capacity_weight' => 3000.0,
                'status' => 'active',
            ],
            [
                'name' => 'TPS BSD Sektor 1',
                'kecamatan_name' => 'Serpong',
                'kelurahan_name' => 'Rawa Buntu',
                'address' => 'Jl. Rawa Buntu Raya, Rawa Buntu, Kec. Serpong, Kota Tangerang Selatan',
                'latitude' => -6.3025,
                'longitude' => 106.6853,
                'capacity_volume' => 110.0,
                'capacity_weight' => 3800.0,
                'status' => 'active',
            ],
            [
                'name' => 'TPS Muncul Setu',
                'kecamatan_name' => 'Setu',
                'kelurahan_name' => 'Setu',
                'address' => 'Jl. Raya Puspiptek, Setu, Kec. Setu, Kota Tangerang Selatan',
                'latitude' => -6.3456,
                'longitude' => 106.6712,
                'capacity_volume' => 80.0,
                'capacity_weight' => 2500.0,
                'status' => 'active',
            ],
        ];

        foreach ($tpsList as $item) {
            $kecamatan = Area::where('name', $item['kecamatan_name'])->where('level', 'Kecamatan')->first();
            $kelurahan = Area::where('name', $item['kelurahan_name'])->where('level', 'Kelurahan')->first();
            $rw = $kelurahan ? Rw::where('kelurahan_id', $kelurahan->id)->first() : null;

            GarbageDump::firstOrCreate(
                ['name' => $item['name']],
                [
                    'kecamatan_id' => $kecamatan?->id,
                    'kelurahan_id' => $kelurahan?->id,
                    'rw_id' => $rw?->id,
                    'address' => $item['address'],
                    'latitude' => $item['latitude'],
                    'longitude' => $item['longitude'],
                    'capacity_volume' => $item['capacity_volume'],
                    'capacity_weight' => $item['capacity_weight'],
                    'status' => $item['status'],
                ]
            );
        }

        $this->command->info('✓ Seeded ' . GarbageDump::count() . ' TPS di wilayah Tangerang');
    }
}
