<?php

namespace Database\Seeders;

use App\Models\Article;
use Carbon\Carbon;
use Illuminate\Database\Seeder;

class ArticleSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $articles = [
            [
                'title' => 'Panduan Praktis Memilah Sampah Rumah Tangga: Organik, Anorganik & B3',
                'slug' => 'panduan-praktis-memilah-sampah-rumah-tangga',
                'summary' => 'Pelajari cara mudah memisahkan sampah rumah tangga dari dapur hingga pekarangan untuk menjaga kebersihan lingkungan dan memudahkan proses daur ulang.',
                'content' => '<p>Memilah sampah adalah langkah pertama yang paling krusial dalam rantai tata kelola lingkungan modern. Sampah yang tercampur akan menimbulkan bau menyengat, menarik vektor penyakit, dan sangat sulit untuk didaur ulang.</p>
<h3>1. Sampah Organik (Mudah Terurai)</h3>
<p>Sampah organik meliputi sisa makanan, kulit buah, potongan sayur, ampas kopi/teh, daun kering, dan sisa bahan masakan dapur. Sampah jenis ini sangat baik diolah menjadi kompos alami.</p>
<ul>
    <li>Gunakan wadah khusus tertutup di dapur.</li>
    <li>Hindari mencampurkan kantong plastik atau tusuk gigi ke dalam wadah organik.</li>
    <li>Keringkan sedikit kadar air sebelum diikat ke kantong sampah.</li>
</ul>
<h3>2. Sampah Anorganik (Dapat Didaur Ulang)</h3>
<p>Sampah anorganik terdiri dari botol plastik, kaleng minuman, kardus, botol kaca, serta kemasan kertas. Bersihkan sisa cairan terlebih dahulu agar tidak membusuk atau menimbulkan belatung.</p>
<h3>3. Sampah B3 (Bahan Berbahaya dan Beracun)</h3>
<p>Kategori ini meliputi baterai bekas, lampu neon, obat kedaluwarsa, dan botol aerosol. Pisahkan secara tersendiri dan tandai dengan jelas demi keselamatan petugas penjemput.</p>
<p>Dengan menerapkan pemilahan rutin sejak dari rumah, Anda secara langsung membantu menjaga bumi dan meringankan beban para petugas kebersihan kita!</p>',
                'author' => 'Tim Edukasi Beresin',
                'featured_image' => 'articles/memilah-sampah.jpg',
                'published_at' => Carbon::now()->subDays(5),
                'status' => 'published',
            ],
            [
                'title' => 'Mengubah Sisa Dapur Menjadi Pupuk Kompos Berkualitas Tinggi',
                'slug' => 'mengubah-sisa-dapur-menjadi-pupuk-kompos',
                'summary' => 'Sulap sisa sayuran dan buah-buahan menjadi nutrisi organik bagi tanaman hias dan kebun pekarangan Anda dengan metode komposting sederhana.',
                'content' => '<p>Tahukah Anda bahwa lebih dari 50% sampah yang berakhir di TPA adalah sampah organik? Padahal sisa bahan makanan tersebut dapat disulap menjadi "emas hitam" penyubur tanah pekarangan rumah Anda.</p>
<h3>Metode Pembuatan Kompos Skala Rumah Tangga:</h3>
<ol>
    <li><strong>Sediakan Komposter / Ember Berpori:</strong> Gunakan ember bekas yang diberi lubang-lubang kecil di bagian bawah dan samping untuk sirkulasi udara.</li>
    <li><strong>Keseimbangan Material Hijau dan Cokelat:</strong>
        <ul>
            <li><em>Material Hijau (Kaya Nitrogen):</em> Sisa sayur, kulit buah, ampas teh/kopi.</li>
            <li><em>Material Cokelat (Kaya Karbon):</em> Daun kering, sekam, serbuk gergaji, atau robekan kardus tanpa lem.</li>
        </ul>
    </li>
    <li><strong>Penyusunan Berlapis:</strong> Susun secara berselang-seling antara material hijau dan cokelat, lalu siram sedikit larutan bioaktivator (EM4) atau air cucian beras.</li>
    <li><strong>Pengadukan Berkala:</strong> Aduk tumpukan kompos seminggu sekali untuk menjaga aerasi. Dalam waktu 4-6 minggu, kompos matang dan siap digunakan!</li>
</ol>
<p>Hasil komposting akan menghasilkan tanah subur bebas kimia yang membuat pekarangan hijau dan asri.</p>',
                'author' => 'Dr. Ir. Hendra Wicaksono',
                'featured_image' => 'articles/kompos-organik.jpg',
                'published_at' => Carbon::now()->subDays(4),
                'status' => 'published',
            ],
            [
                'title' => 'Ancaman Nyata Mikroplastik dan Gaya Hidup Minim Sampah (Zero Waste)',
                'slug' => 'ancaman-nyata-mikroplastik-dan-gaya-hidup-zero-waste',
                'summary' => 'Mikroplastik kini telah terdeteksi dalam rantai makanan dan air minum. Temukan langkah nyata memulai gaya hidup minim sampah mulai hari ini.',
                'content' => '<p>Plastik konvensional membutuhkan waktu ratusan tahun untuk terurai. Alih-alih hilang, plastik tersebut hanya pecah menjadi partikel mikroskopis yang disebut <strong>mikroplastik</strong>.</p>
<p>Partikel ini terserap oleh tanah, mengontaminasi air tanah, termakan oleh biota laut, dan akhirnya kembali ke piring makan kita sendiri. Dampaknya bagi kesehatan meliputi gangguan hormon, peradangan, dan risiko penyakit jangka panjang.</p>
<h3>Langkah Sederhana Memulai Gaya Hidup Zero Waste:</h3>
<ul>
    <li><strong>Bawa Tas Belanja Kain (Tote Bag):</strong> Selalu simpan tas kain di dalam jok motor atau mobil Anda saat bepergian ke pasar atau supermarket.</li>
    <li><strong>Gunakan Botol Minum (Tumbler) & Wadah Makanan:</strong> Kurangi konsumsi air mineral kemasan sekali pakai.</li>
    <li><strong>Tolak Sedotan Plastik:</strong> Gunakan sedotan berbahan stainless steel atau nikmati minuman Anda secara langsung tanpa sedotan.</li>
    <li><strong>Pilih Produk Isi Ulang (Refill):</strong> Manfaatkan toko curah atau kemasan hemat isi ulang untuk sabun dan deterjen rumah tangga.</li>
</ul>
<p>Ingat, kita tidak butuh segelintir orang yang sempurna dalam zero waste; kita butuh jutaan orang yang memulainya meski belum sempurna.</p>',
                'author' => 'Siti Nurhaliza, M.Env',
                'featured_image' => 'articles/bahaya-plastik.jpg',
                'published_at' => Carbon::now()->subDays(3),
                'status' => 'published',
            ],
            [
                'title' => 'Cara Kerja Bank Sampah: Ubah Sampah Anorganik Menjadi Nilai Ekonomis',
                'slug' => 'cara-kerja-bank-sampah-ubah-sampah-menjadi-cuan',
                'summary' => 'Bagaimana mengumpulkan botol plastik, kardus, dan kaleng bekas agar memiliki nilai jual tinggi melalui jaringan Bank Sampah terdekat.',
                'content' => '<p>Bank Sampah merupakan konsep inovasi sosial ekonomi yang memadukan kepedulian lingkungan dengan sistem perbankan konvensional. Melalui Bank Sampah, warga tidak lagi membuang sampah anorganik ke selokan atau tempat sampah biasa, melainkan menyetorkannya untuk ditimbang dan dicatat sebagai saldo tabungan.</p>
<h3>Mekanisme Penyetoran di Bank Sampah:</h3>
<ol>
    <li><strong>Pemilahan Jenis Sampah:</strong> Pilah plastik (PET bening, HDPE, cup), kertas/kardus (dupleks, koran), dan logam (kaleng alumunium, besi).</li>
    <li><strong>Pembersihan & Pengeringan:</strong> Botol plastik dicuci bersih dan diinjak hingga pipih agar hemat ruang penyimpanan.</li>
    <li><strong>Penimbangan:</strong> Petugas Bank Sampah menimbang masing-masing jenis sampah dengan timbangan digital presisi.</li>
    <li><strong>Pencatatan Saldo:</strong> Nilai rupiah dihitung berdasarkan harga pasar daur ulang hari itu dan otomatis masuk ke rekening tabungan nasabah.</li>
</ol>
<p>Banyak warga lingkungan Beresin yang berhasil membayar iuran RT hingga tagihan listrik bulanan hanya dari hasil tabungan Bank Sampah!</p>',
                'author' => 'Pengelola Bank Sampah Mandiri',
                'featured_image' => 'articles/bank-sampah.jpg',
                'published_at' => Carbon::now()->subDays(2),
                'status' => 'published',
            ],
            [
                'title' => 'Mengenal Alur Penjemputan Cerdas Beresin: Efisien, Terjadwal & Transparan',
                'slug' => 'mengenal-alur-penjemputan-cerdas-beresin',
                'summary' => 'Ketahui hak dan kewajiban warga dalam jadwal penjemputan sampah rutin, panduan ukuran kantong, serta rute armada lingkungan Anda.',
                'content' => '<p>Aplikasi <strong>Beresin</strong> dirancang untuk mengintegrasikan kebutuhan warga dengan dedikasi para petugas kolektor sampah di lapangan secara real-time.</p>
<h3>Standar Penempatan Sampah di Titik Jemput:</h3>
<ul>
    <li><strong>Letakkan Kantong Sebelum Pukul 07.30 WIB:</strong> Petugas armada kami mulai berkeliling sesuai rute optimal sejak pagi hari.</li>
    <li><strong>Ikat Rapat Kantong Sampah:</strong> Pastikan kantong terikat rapi agar tidak tercecer atau diacak hewan liar.</li>
    <li><strong>Gunakan Fitur Permintaan Khusus:</strong> Apabila Anda memiliki sampah dalam volume besar di luar jadwal rutin (seperti pasca renovasi atau hajatan), gunakan menu <em>Permintaan Penjemputan</em> di aplikasi Beresin.</li>
</ul>
<p>Kolektor kami akan mengambil foto konfirmasi dan mencatat rincian kantong sampah secara transparan ke akun Anda. Mari bersama kita wujudkan lingkungan yang asri, bersih, dan nyaman!</p>',
                'author' => 'Tim Operasional Beresin',
                'featured_image' => 'articles/jadwal-penjemputan.jpg',
                'published_at' => Carbon::now()->subDay(),
                'status' => 'published',
            ],
            [
                'title' => 'Menuju Kota Cerdas Bebas Sampah: Integrasi TPS3R dan Sistem Digital Beresin',
                'slug' => 'menuju-kota-cerdas-bebas-sampah-integrasi-tps3r',
                'summary' => 'Bagaimana integrasi teknologi pelacakan tonase sampah dari rumah tangga menuju TPS dan TPA mampu menekan angka polusi hingga 60%.',
                'content' => '<p>Transformasi pengelolaan sampah di era modern tidak lagi cukup mengandalkan pola tradisional <em>kumpul-angkut-buang</em>. Pendekatan sirkular ekonomi menuntut pencatatan data yang presisi di setiap titik simpul.</p>
<h3>Peran Fasilitas TPS3R (Reduce, Reuse, Recycle):</h3>
<p>TPS3R berfungsi sebagai benteng utama pemrosesan sampah sebelum residunya dikirim ke Tempat Pemrosesan Akhir (TPA). Di fasilitas ini:</p>
<ul>
    <li>Sampah organik dicacah dan masuk ke bak fermentasi untuk pupuk organik atau pakan maggot BSF (Black Soldier Fly).</li>
    <li>Sampah anorganik bernilai tinggi dipilah menggunakan mesin pres hidrolik dan dikirim ke pabrik daur ulang plastik.</li>
    <li>Hanya sisa residu tak termanfaatkan (kurang dari 20%) yang diberangkatkan menuju TPA akhir.</li>
</ul>
<p>Dengan dukungan dashboard analitik Beresin, pemerintah daerah dan pengelola wilayah dapat memonitor timbulan sampah harian secara akurat dan mengambil kebijakan pro-lingkungan berbasis data konkret.</p>',
                'author' => 'Dinas Lingkungan Hidup & Beresin',
                'featured_image' => 'articles/zero-waste-city.jpg',
                'published_at' => Carbon::now(),
                'status' => 'published',
            ],
        ];

        foreach ($articles as $data) {
            Article::updateOrCreate(
                ['slug' => $data['slug']],
                $data
            );
        }

        $this->command->info('Seeded ' . count($articles) . ' articles successfully.');
    }
}
