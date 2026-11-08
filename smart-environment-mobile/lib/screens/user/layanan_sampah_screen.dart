import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'tambah_akun_layanan_screen.dart'; // Pastikan file ini ada di project Anda

import '../../models/service_account.dart';
import '../../services/service_account_service.dart';
import '../../services/resident_pickup_service.dart';
import '../../services/invoice_service.dart';

/// 🔹 Halaman utama daftar akun layanan
class LayananSampahScreen extends StatefulWidget {
  const LayananSampahScreen({super.key});

  @override
  State<LayananSampahScreen> createState() => _LayananSampahScreenState();
}

class _LayananSampahScreenState extends State<LayananSampahScreen> {
  final ServiceAccountService _serviceAccountService = ServiceAccountService();
  bool _isLoading = true;
  List<ServiceAccount> _accounts = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  /// 🔹 Simulasi shimmer loading sebelum load data
  Future<void> _startLoading() async {
    await Future.delayed(const Duration(seconds: 2)); // tampil shimmer 2 detik
    await _loadAkunLayanan();
  }

  /// 🔹 Muat data akun dari API
  Future<void> _loadAkunLayanan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _serviceAccountService.fetchAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat akun layanan';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is Exception ? error.toString() : '$error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showTambahAkunOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _optionCard(
                iconPath: "assets/images/terdaftar.svg",
                title: "Akun terdaftar",
                onTap: () {
                  Navigator.pop(context);

                  if (_accounts.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Harap membuat akun terlebih dahulu"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Akun sudah ada terdaftar"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              _optionCard(
                iconPath: "assets/images/news.svg",
                title: "Buat akun baru",
                onTap: () async {
                  Navigator.pop(context);

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TambahAkunLayananScreen(),
                    ),
                  );

                  if (!mounted) return;
                  if (result != null && result is ServiceAccount) {
                    setState(() {
                      _accounts.insert(0, result);
                    });
                  } else {
                    await _loadAkunLayanan();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _optionCard({
    required String iconPath,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(iconPath, height: 50),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          "Akun Layanan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading ? _buildFullPageShimmer() : _buildContent(),
      floatingActionButton: !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _showTambahAkunOptions,
              icon: const Icon(Icons.add),
              label: const Text("Tambah Akun"),
              backgroundColor: const Color(0xFF4CAF50),
            )
          : null,
    );
  }

  /// 🔹 Shimmer fullscreen
  Widget _buildFullPageShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  /// 🔹 Konten utama
  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final bool adaAkun = _accounts.isNotEmpty;

    if (!adaAkun) {
      return Center(
        child: Text(
          "Belum ada akun layanan.\nSilakan tambahkan akun baru.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAkunLayanan,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _accounts.length,
        itemBuilder: (context, index) {
          final akun = _accounts[index];
          return GestureDetector(
            onTap: () async {
              final deleted = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailAkunLayananScreen(akun: akun),
                ),
              );

              if (!context.mounted) return;

              if (deleted == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Akun berhasil dihapus'),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );
                await _loadAkunLayanan();
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF4CAF50).withAlpha(38),
                    child: const Icon(Icons.home, color: Color(0xFF4CAF50)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          akun.id,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          akun.name,
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          akun.address,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// DETAIL AKUN LAYANAN SCREEN (Diperbaiki di bagian _showStatusDialog)
// -----------------------------------------------------------------------------

/// 🔹 Halaman detail akun layanan
class DetailAkunLayananScreen extends StatelessWidget {
  final ServiceAccount akun;
  static final ServiceAccountService _serviceAccountService =
      ServiceAccountService();
  static final ResidentPickupService _pickupService = ResidentPickupService();
  static final InvoiceService _invoiceService = InvoiceService();

  const DetailAkunLayananScreen({super.key, required this.akun});

  /// 🔹 Popup Status - Menampilkan status pickup hari ini
  Future<void> _showStatusDialog(BuildContext context) async {
    // Tampilkan loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Memeriksa status...',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    // Fetch data pickup hari ini dari API
    final (success, message, pickups) = await _pickupService.getUpcomingPickups(
      serviceAccountId: akun.id,
    );

    // Tutup loading dialog
    if (context.mounted) Navigator.pop(context);

    // Filter hanya pickup hari ini
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final todayPickup = pickups?.where((pickup) {
      final pickupDate = pickup['pickup_date'] as String?;
      return pickupDate == todayStr;
    }).toList();

    if (!success || todayPickup == null || todayPickup.isEmpty) {
      // Tidak ada jadwal hari ini
      if (context.mounted) {
        _showPickupStatusDialog(
          context: context,
          status: 'no_schedule',
          message: 'Tidak ada jadwal pengambilan sampah hari ini',
        );
      }
      return;
    }

    // Ada jadwal hari ini, ambil yang pertama
    final pickup = todayPickup.first;
    final status = pickup['status'] as String? ?? 'scheduled';
    final confirmationStatus =
        pickup['confirmation_status'] as String? ?? 'pending';
    final pickupDate = pickup['pickup_date'] as String? ?? '-';
    final dayName = pickup['day_name'] as String? ?? '-';

    final collectorInfo = pickup['collector_info'] as Map<String, dynamic>?;
    final collectorName =
        collectorInfo?['name'] as String? ?? 'Belum ditentukan';
    final collectorPhone = collectorInfo?['phone_number'] as String? ?? '-';

    if (context.mounted) {
      _showPickupStatusDialog(
        context: context,
        status: status,
        confirmationStatus: confirmationStatus,
        pickupDate: pickupDate,
        dayName: dayName,
        collectorName: collectorName,
        collectorPhone: collectorPhone,
      );
    }
  }

  /// Dialog untuk menampilkan status pickup
  void _showPickupStatusDialog({
    required BuildContext context,
    required String status,
    String? confirmationStatus,
    String? pickupDate,
    String? dayName,
    String? collectorName,
    String? collectorPhone,
    String? message,
  }) {
    // Tentukan warna, ikon, dan teks berdasarkan status
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (status == 'no_schedule') {
      statusColor = Colors.grey;
      statusIcon = Icons.event_busy;
      statusText = message ?? 'Tidak ada jadwal pengambilan hari ini';
    } else if (status == 'collected' || status == 'completed') {
      statusColor = const Color(0xFF4CAF50);
      statusIcon = Icons.check_circle;
      statusText = 'Sampah sudah diambil Kolektor';
    } else if (status == 'in_progress') {
      statusColor = Colors.orange;
      statusIcon = Icons.local_shipping;
      statusText = 'Kolektor sedang dalam perjalanan';
    } else {
      // scheduled / pending
      statusColor = Colors.blue;
      statusIcon = Icons.hourglass_empty;
      statusText = 'Sampah belum diambil Kolektor';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon & Status Text
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withAlpha(26),
                    ),
                    child: Icon(statusIcon, size: 48, color: statusColor),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),

                // Detail informasi pickup (hanya jika ada jadwal hari ini)
                if (status != 'no_schedule') ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Tanggal Pickup
                  if (pickupDate != null && dayName != null) ...[
                    _buildInfoRow(
                      icon: Icons.calendar_today,
                      label: 'Jadwal Pickup Hari Ini',
                      value: '$dayName\n$pickupDate',
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Kolektor
                  if (collectorName != null) ...[
                    _buildInfoRow(
                      icon: Icons.person,
                      label: 'Kolektor',
                      value: collectorName,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Nomor Telepon Kolektor
                  if (collectorPhone != null &&
                      collectorPhone != '-' &&
                      collectorPhone.isNotEmpty) ...[
                    _buildInfoRow(
                      icon: Icons.phone,
                      label: 'Kontak',
                      value: collectorPhone,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("OK"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Widget helper untuk menampilkan info row
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF4CAF50)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleStatusAkun(BuildContext context) async {
    final isActive = akun.status.toLowerCase() == 'active';

    // Tampilkan loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                isActive ? 'Memeriksa tagihan...' : 'Mengaktifkan akun...',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Jika akun active, cek tagihan dulu sebelum nonaktifkan
      if (isActive) {
        // Check tagihan yang belum dibayar
        final invoiceData = await _invoiceService.getUnpaidInvoices();

        // Tutup loading dialog
        if (!context.mounted) return;
        Navigator.pop(context);

        final allInvoices = invoiceData['unpaid_invoices'] as List<dynamic>?;

        // 🔍 FILTER: Ambil hanya invoice untuk akun INI saja
        final accountInvoices =
            allInvoices?.where((invoice) {
              final serviceAccount = invoice['service_account'];
              if (serviceAccount == null) return false;

              // Match berdasarkan ID akun
              return serviceAccount['id']?.toString() == akun.id.toString();
            }).toList() ??
            [];

        // Hitung total amount untuk akun ini
        final totalAmount = accountInvoices.fold<num>(
          0,
          (sum, invoice) => sum + (invoice['total_amount'] as num? ?? 0),
        );

        appLog(
          '📊 [DetailAkunScreen] Checking invoices for account ID: ${akun.id}',
        );
        appLog(
          '📊 [DetailAkunScreen] Found ${accountInvoices.length} unpaid invoices for this account',
        );
        appLog('📊 [DetailAkunScreen] Total amount: $totalAmount');

        // Jika akun INI ada tagihan yang belum dibayar
        if (accountInvoices.isNotEmpty) {
          _showTagihanBelumLunasDialog(context, accountInvoices, totalAmount);
          return;
        }

        appLog(
          '✅ [DetailAkunScreen] No unpaid invoices, can proceed with deactivation',
        );
      }

      // Toggle status akun (active <-> inactive)
      final newStatus = isActive ? 'inactive' : 'active';
      await _serviceAccountService.updateAccountStatus(akun.id, newStatus);

      // Tutup loading dialog jika masih ada
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (!context.mounted) return;

      // Tampilkan success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isActive ? Colors.orange : const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.cancel : Icons.check_circle,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isActive
                    ? 'Akun Berhasil Dinonaktifkan'
                    : 'Akun Berhasil Diaktifkan',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isActive
                    ? 'Akun layanan telah dinonaktifkan. Anda dapat mengaktifkan kembali akun ini kapan saja.'
                    : 'Akun layanan telah diaktifkan kembali dan siap digunakan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // tutup dialog
                    Navigator.pop(context, true); // kembali ke list
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      // Tutup loading jika masih ada
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menonaktifkan akun: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showTagihanBelumLunasDialog(
    BuildContext context,
    List<dynamic> invoices,
    num totalAmount,
  ) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon warning
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Tidak Dapat Dinonaktifkan',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'Akun ini masih memiliki tagihan yang belum dibayar. Silakan lunasi tagihan terlebih dahulu sebelum menonaktifkan akun.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              // Info tagihan
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Jumlah Tagihan:',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${invoices.length} tagihan',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Belum Dibayar:',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          currencyFormat.format(totalAmount),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Tutup',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx); // tutup dialog
                        // Navigate ke halaman pembayaran atau riwayat pembayaran
                        // Anda bisa implement navigasi ke payment screen di sini
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Silakan bayar tagihan di menu Home',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: const Color(0xFF4CAF50),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Bayar',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _konfirmasiNonaktifkan(BuildContext context) {
    final isActive = akun.status.toLowerCase() == 'active';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                isActive ? Icons.block : Icons.check_circle,
                color: isActive ? Colors.orange : const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? "Nonaktifkan Akun" : "Aktifkan Akun",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Text(
            isActive
                ? "Apakah Anda yakin ingin menonaktifkan akun layanan ini? Akun yang dinonaktifkan dapat diaktifkan kembali kapan saja."
                : "Apakah Anda yakin ingin mengaktifkan kembali akun layanan ini?",
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Batal",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _toggleStatusAkun(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive
                    ? Colors.orange
                    : const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isActive ? "Nonaktifkan" : "Aktifkan",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Print account details
    appLog('📋 [DetailAkunScreen] Displaying account:');
    appLog('   - ID: ${akun.id}');
    appLog('   - Nama: ${akun.name}');
    appLog('   - Contact Phone: ${akun.contactPhone}');
    appLog('   - Status: ${akun.status}');

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          "Detail Akun Layanan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: akun.status.toLowerCase() == 'active'
                    ? Colors.white
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: akun.status.toLowerCase() == 'active'
                        ? const Color(0xFF4CAF50).withAlpha(38)
                        : Colors.grey.shade400,
                    child: Icon(
                      Icons.home,
                      size: 32,
                      color: akun.status.toLowerCase() == 'active'
                          ? const Color(0xFF4CAF50)
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                akun.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: akun.status.toLowerCase() == 'active'
                                      ? Colors.black
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            if (akun.status.toLowerCase() != 'active')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'NONAKTIF',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          akun.address,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: akun.status.toLowerCase() == 'active'
                                ? Colors.grey[700]
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            /// Info List
            _infoCard(Icons.badge, "ID Akun", akun.id),
            _infoCard(Icons.person, "Nama", akun.name),
            _infoCard(Icons.phone, "Kontak", akun.contactPhone ?? '-'),
            _infoCard(Icons.location_on, "Alamat Lengkap", akun.address),
            _infoCard(Icons.map, "Kecamatan", akun.kecamatanName ?? '-'),
            _infoCard(Icons.home_work, "Kelurahan", akun.kelurahanName ?? '-'),
            _infoCard(Icons.home, "RW", akun.rwName ?? '-'),

            const SizedBox(height: 24),

            /// Jadwal Angkut
            Text(
              "Hari Pengangkutan Sampah",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF4CAF50),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    akun.hariPengangkutan ?? "Senin & Kamis",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            /// Tombol Aksi
            Column(
              children: [
                // Tombol Status
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showStatusDialog(context),
                    icon: const Icon(Icons.info_outline),
                    label: const Text("Status"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Tombol Toggle Status Akun (Nonaktifkan/Aktifkan)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _konfirmasiNonaktifkan(context),
                    icon: Icon(
                      akun.status.toLowerCase() == 'active'
                          ? Icons.cancel
                          : Icons.check_circle,
                    ),
                    label: Text(
                      akun.status.toLowerCase() == 'active'
                          ? "Nonaktifkan Akun"
                          : "Aktifkan Akun",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: akun.status.toLowerCase() == 'active'
                          ? Colors.orange
                          : const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Widget info card dengan icon
  Widget _infoCard(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4CAF50)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
