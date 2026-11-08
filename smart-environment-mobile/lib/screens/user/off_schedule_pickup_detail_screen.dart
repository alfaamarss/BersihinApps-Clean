import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../services/off_schedule_pickup_service.dart';
import '../../models/off_schedule_pickup.dart';

class OffSchedulePickupDetailScreen extends StatefulWidget {
  final int pickupId;

  const OffSchedulePickupDetailScreen({super.key, required this.pickupId});

  @override
  State<OffSchedulePickupDetailScreen> createState() =>
      _OffSchedulePickupDetailScreenState();
}

class _OffSchedulePickupDetailScreenState
    extends State<OffSchedulePickupDetailScreen> {
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  OffSchedulePickup? _pickup;
  bool _isLoading = true;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final service = OffSchedulePickupService();
      final pickup = await service.getRequestDetail(widget.pickupId);

      if (!mounted) return;
      setState(() {
        _pickup = pickup;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat detail: ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmPickup() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: primaryColor,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Konfirmasi Pengambilan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin sampah sudah diambil oleh kolektor? Setelah dikonfirmasi, invoice akan dibuat.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Ya, Konfirmasi',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isConfirming = true);

    try {
      final service = OffSchedulePickupService();
      final result = await service.confirmPickup(widget.pickupId);

      if (!mounted) return;

      setState(() => _isConfirming = false);

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Berhasil Dikonfirmasi',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pickup berhasil dikonfirmasi!',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              if (result.invoice != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 18,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Invoice Dibuat',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.invoice!.invoiceNumber,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: Rp ${result.invoice!.totalAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Back to list
              },
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isConfirming = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal konfirmasi: ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sent':
        return Colors.blue;
      case 'processing':
        return Colors.orange;
      case 'pending':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'paid':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to get full photo URL
  String _getFullPhotoUrl(String photoUrl) {
    return ApiConfig.formatImageUrl(photoUrl) ?? photoUrl;
  }

  // Build status stepper widget with timestamps like complaint detail
  Widget _buildStatusStepper(String requestStatus) {
    // Map status to stepper stages - CORRECT FLOW:
    // sent -> Menunggu (request baru dikirim, menunggu penugasan)
    // processing -> Di-proses (kolektor sedang proses pengambilan)
    // pending -> Selesai/Menunggu Konfirmasi (sampah sudah diambil, menunggu konfirmasi user)
    // completed/paid -> Selesai (sudah dikonfirmasi)

    bool isWaitingActive = requestStatus == 'sent';
    bool isWaitingCompleted =
        requestStatus == 'processing' ||
        requestStatus == 'pending' ||
        requestStatus == 'completed' ||
        requestStatus == 'paid';

    bool isProcessingActive = requestStatus == 'processing';
    bool isProcessingCompleted =
        requestStatus == 'pending' ||
        requestStatus == 'completed' ||
        requestStatus == 'paid';

    bool isCompletedActive =
        requestStatus == 'pending' ||
        requestStatus == 'completed' ||
        requestStatus == 'paid';

    // Get timestamps
    final createdAt = _pickup?.createdAt;
    final processedAt = _pickup?.processedAt ?? _pickup?.assignedAt;
    final completedAt = _pickup?.completedAt ?? _pickup?.collectedAt;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Timestamps row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimestamp(createdAt),
              _buildTimestamp(processedAt),
              _buildTimestamp(completedAt),
            ],
          ),
          const SizedBox(height: 12),

          // Progress indicators row
          Row(
            children: [
              // Step 1: Menunggu
              _buildStatusStep(
                icon: Icons.hourglass_empty_rounded,
                label: 'Menunggu',
                sublabel: 'Request sedang\nmenunggu untuk\ndiproses',
                isActive: isWaitingActive,
                isCompleted: isWaitingCompleted,
              ),

              // Connector line 1
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 50),
                  decoration: BoxDecoration(
                    color: isWaitingCompleted
                        ? primaryColor
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Step 2: Di-proses
              _buildStatusStep(
                icon: Icons.local_shipping_outlined,
                label: 'Di-proses',
                sublabel: 'Kolektor sedang\nmenuju lokasi\nAnda',
                isActive: isProcessingActive,
                isCompleted: isProcessingCompleted,
              ),

              // Connector line 2
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 50),
                  decoration: BoxDecoration(
                    color: isProcessingCompleted
                        ? primaryColor
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Step 3: Selesai
              _buildStatusStep(
                icon: Icons.check_circle_outline_rounded,
                label: 'Selesai',
                sublabel: requestStatus == 'pending'
                    ? 'Menunggu\nkonfirmasi Anda'
                    : 'Request berhasil\ndiselesaikan',
                isActive: isCompletedActive,
                isCompleted:
                    requestStatus == 'completed' || requestStatus == 'paid',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build timestamp widget
  Widget _buildTimestamp(DateTime? dateTime) {
    if (dateTime == null) {
      return SizedBox(
        width: 70,
        child: Text(
          '-',
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Text(
            DateFormat('d MMM yyyy').format(dateTime),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            DateFormat('HH:mm').format(dateTime),
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Build individual status step with description
  Widget _buildStatusStep({
    required IconData icon,
    required String label,
    required String sublabel,
    required bool isActive,
    required bool isCompleted,
  }) {
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive || isCompleted
                  ? primaryColor
                  : Colors.grey.shade200,
              shape: BoxShape.circle,
              boxShadow: isActive || isCompleted
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : icon,
              color: isActive || isCompleted
                  ? Colors.white
                  : Colors.grey.shade500,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: isActive || isCompleted
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: isActive || isCompleted
                  ? primaryColor
                  : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            sublabel,
            style: GoogleFonts.poppins(
              fontSize: 8,
              color: isActive || isCompleted
                  ? primaryColor.withValues(alpha: 0.7)
                  : Colors.grey.shade500,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Detail Request',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _pickup == null
          ? Center(
              child: Text(
                'Data tidak ditemukan',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        _pickup!.requestStatus,
                      ).withValues(alpha: 0.1),
                      border: Border(
                        bottom: BorderSide(
                          color: _getStatusColor(
                            _pickup!.requestStatus,
                          ).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: _getStatusColor(_pickup!.requestStatus),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _pickup!.getStatusLabel(),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _getStatusColor(_pickup!.requestStatus),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Request ID: #${_pickup!.id}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Status Stepper
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildStatusStepper(_pickup!.requestStatus),
                  ),

                  const SizedBox(height: 16),

                  // Pickup Info
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Pengambilan',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          'Tanggal',
                          DateFormat('EEEE, dd MMMM yyyy').format(
                            DateTime.parse(_pickup!.requestedPickupDate),
                          ),
                          icon: Icons.calendar_today_outlined,
                        ),
                        if (_pickup!.requestedPickupTime != null)
                          _buildInfoRow(
                            'Waktu',
                            _pickup!.requestedPickupTime!,
                            icon: Icons.access_time_outlined,
                          ),
                        if (_pickup!.note != null && _pickup!.note!.isNotEmpty)
                          _buildInfoRow(
                            'Catatan',
                            _pickup!.note!,
                            icon: Icons.note_outlined,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Collector Info (if assigned)
                  if (_pickup!.assignedCollector != null) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kolektor',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            'Nama',
                            _pickup!.assignedCollector!.name,
                            icon: Icons.person_outline,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Photo (if collected or pending)
                  if (_pickup!.photoUrl != null ||
                      _pickup!.requestStatus == 'pending' ||
                      _pickup!.requestStatus == 'completed' ||
                      _pickup!.requestStatus == 'paid') ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Foto Pengambilan',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _pickup!.photoUrl != null
                                ? Image.network(
                                    _getFullPhotoUrl(_pickup!.photoUrl!),
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 200,
                                        color: Colors.grey.shade100,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                            color: primaryColor,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      appLog('❌ [Photo] Error loading: $error');
                                      return Container(
                                        height: 200,
                                        color: Colors.grey.shade200,
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.broken_image_outlined,
                                                size: 48,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Gagal memuat foto',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    height: 200,
                                    color: Colors.grey.shade200,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image_outlined,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Foto belum tersedia',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Pricing Info (if collected)
                  if (_pickup!.bagCount > 0) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rincian Biaya',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Jumlah Kantong',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '${_pickup!.bagCount} kantong',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Biaya Dasar',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                'Rp ${_pickup!.baseAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Biaya Tambahan',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                'Rp ${_pickup!.extraFee.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Rp ${_pickup!.totalAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 80), // Space for button
                ],
              ),
            ),
      bottomNavigationBar:
          _pickup != null &&
              _pickup!.status == 'collected' &&
              _pickup!.requestStatus == 'pending'
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: _isConfirming ? null : _confirmPickup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isConfirming
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Konfirmasi Pengambilan',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            )
          : null,
    );
  }
}
