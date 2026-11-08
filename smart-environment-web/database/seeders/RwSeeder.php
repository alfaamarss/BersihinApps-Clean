<?php

namespace Database\Seeders;

use App\Models\Area;
use App\Models\Rw;
use Illuminate\Database\Seeder;

class RwSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $kelurahans = Area::where('level', 'Kelurahan')->get();

        foreach ($kelurahans as $kelurahan) {
            // Buatkan 3 sample RW per kelurahan
            for ($i = 1; $i <= 3; $i++) {
                Rw::firstOrCreate([
                    'kelurahan_id' => $kelurahan->id,
                    'name' => sprintf('RW %02d', $i),
                ]);
            }
        }

        $this->command->info('✓ Seeded ' . Rw::count() . ' RW(s) di wilayah Tangerang');
    }
}
