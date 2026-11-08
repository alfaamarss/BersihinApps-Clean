<?php

namespace Database\Seeders;

use App\Models\Area;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class AreaSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Data Kecamatan dan Kelurahan wilayah Tangerang (Kota Tangerang & Tangerang Selatan)
        $tangerangData = [
            // ================= KOTA TANGERANG =================
            'Tangerang' => [
                'Babakan', 'Buaran Indah', 'Cikokol', 'Kelapa Indah',
                'Suka Asih', 'Sukarasa', 'Sukasari', 'Tanah Tinggi'
            ],
            'Cipondoh' => [
                'Cipondoh', 'Cipondoh Indah', 'Cipondoh Makmur', 'Gondrong',
                'Kenanga', 'Ketapang', 'Petir', 'Poris Plawad',
                'Poris Plawad Indah', 'Poris Plawad Utara'
            ],
            'Ciledug' => [
                'Paninggilan', 'Paninggilan Utara', 'Parung Serab',
                'Sudimara Barat', 'Sudimara Jaya', 'Sudimara Selatan',
                'Sudimara Timur', 'Tajur'
            ],
            'Karawaci' => [
                'Bojong Jaya', 'Bugel', 'Cimone', 'Cimone Jaya',
                'Gerendeng', 'Karawaci', 'Karawaci Baru', 'Koang Jaya',
                'Margasari', 'Nambo Jaya', 'Nusa Jaya', 'Pabuaran',
                'Pabuaran Tumpeng', 'Pasar Baru', 'Sukajadi', 'Sumur Pacing'
            ],
            'Pinang' => [
                'Cipete', 'Kunciran', 'Kunciran Indah', 'Kunciran Jaya',
                'Nerogtog', 'Pakujan', 'Panunggangan', 'Panunggangan Timur',
                'Panunggangan Utara', 'Pinang'
            ],
            'Batuceper' => [
                'Batuceper', 'Batujaya', 'Batusari', 'Kebon Besar',
                'Poris Gaga', 'Poris Gaga Baru', 'Poris Jaya'
            ],
            'Benda' => [
                'Belendung', 'Benda', 'Jurumudi', 'Jurumudi Baru', 'Pajang'
            ],
            'Cibodas' => [
                'Cibodas', 'Cibodasari', 'Cibodas Baru', 'Jatiuwung', 'Uwung Jaya'
            ],
            'Jatiuwung' => [
                'Alam Jaya', 'Gandasari', 'Jatake', 'Keroncong', 'Manis Jaya', 'Pasir Jaya'
            ],
            'Karang Tengah' => [
                'Karang Mulya', 'Karang Tengah', 'Karang Timur',
                'Parung Jaya', 'Pedurenan', 'Pondok Bahar', 'Pondok Pucung'
            ],
            'Larangan' => [
                'Cipadu', 'Cipadu Jaya', 'Gaga', 'Kreo', 'Kreo Selatan',
                'Larangan Indah', 'Larangan Selatan', 'Larangan Utara'
            ],
            'Neglasari' => [
                'Karang Anyar', 'Karangsari', 'Kedaung Baru', 'Kedaung Wetan',
                'Mekarsari', 'Neglasari', 'Selapajang Jaya'
            ],
            'Periuk' => [
                'Gebang Raya', 'Gembor', 'Periuk', 'Periuk Jaya', 'Sangiang Jaya'
            ],

            // ================= TANGERANG SELATAN =================
            'Setu' => [
                'Babakan', 'Bakti Jaya', 'Kademangan', 'Keranggan', 'Muncul', 'Setu'
            ],
            'Serpong' => [
                'Buaran', 'Ciater', 'Cilenggang', 'Lengkong Gudang',
                'Lengkong Gudang Timur', 'Lengkong Wetan', 'Rawa Buntu',
                'Rawa Mekar Jaya', 'Serpong'
            ],
            'Serpong Utara' => [
                'Jelupang', 'Lengkong Karya', 'Pakualam', 'Pakulonan',
                'Paku Jaya', 'Pondok Jagung', 'Pondok Jagung Timur'
            ],
            'Pamulang' => [
                'Bambu Apus', 'Benda Baru', 'Kedaung', 'Pamulang Barat',
                'Pamulang Timur', 'Pondok Benda', 'Pondok Cabe Ilir', 'Pondok Cabe Udik'
            ],
            'Ciputat' => [
                'Cipayung', 'Ciputat', 'Jombang', 'Sawah Baru',
                'Sawah Lama', 'Serua', 'Serua Indah'
            ],
            'Ciputat Timur' => [
                'Cempaka Putih', 'Cireundeu', 'Pisangan', 'Pondok Ranji',
                'Rempoa', 'Rengas'
            ],
            'Pondok Aren' => [
                'Jurang Mangu Barat', 'Jurang Mangu Timur', 'Pondok Kacang Barat',
                'Pondok Kacang Timur', 'Perigi', 'Perigi Baru', 'Pondok Aren',
                'Pondok Betung', 'Pondok Jaya', 'Pondok Karya'
            ],
        ];

        foreach ($tangerangData as $kecamatanName => $kelurahans) {
            $kecamatan = Area::firstOrCreate(
                ['name' => $kecamatanName, 'level' => 'Kecamatan'],
                ['parent_id' => null]
            );

            foreach ($kelurahans as $kelurahanName) {
                Area::firstOrCreate(
                    [
                        'name' => $kelurahanName,
                        'level' => 'Kelurahan',
                        'parent_id' => $kecamatan->id,
                    ]
                );
            }
        }

        $this->command->info('✓ Seeded ' . Area::where('level', 'Kecamatan')->count() . ' kecamatan(s) Tangerang');
        $this->command->info('✓ Seeded ' . Area::where('level', 'Kelurahan')->count() . ' kelurahan(s) Tangerang');
    }
}
