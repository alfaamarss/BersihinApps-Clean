import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/service_account_service.dart';
import '../../services/off_schedule_pickup_service.dart';
import '../../models/service_account.dart';
import '../../models/off_schedule_pickup.dart' hide ServiceAccount;
import 'off_schedule_pickup_detail_screen.dart';

class ExpressRequestScreen extends StatefulWidget {
  const ExpressRequestScreen({super.key});

  @override
  State<ExpressRequestScreen> createState() => _ExpressRequestScreenState();
}

class _ExpressRequestScreenState extends State<ExpressRequestScreen> {
  static const Color primaryColor = Color.fromARGB(255, 21, 145, 137);

  // State untuk waktu dan tanggal
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // State untuk lokasi dari service account
  List<ServiceAccount> _serviceAccounts = [];
  ServiceAccount? _selectedAccount;
  bool _isLoadingAccounts = true;

  // State untuk catatan
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;
  // Pricing info from API
  Map<String, dynamic>? _pricingInfo;
  bool _isLoadingPricing = false;

  // Skip scheduled pickup feature
  bool _skipNextScheduled = false;

  // Active request for selected service account
  OffSchedulePickup? _activeRequest;
  bool _isLoadingActiveRequest = false;

  // Arguments dari home screen
  String? _initialServiceAccountId;
  String? _initialServiceAccountName;

  @override
  void initState() {
    super.initState();
    // Arguments akan diambil di didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ambil arguments dari route hanya sekali
    if (_initialServiceAccountId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _initialServiceAccountId = args['serviceAccountId']?.toString();
        _initialServiceAccountName = args['serviceAccountName']?.toString();
        appLog(
          '[EXPRESS] Received initial account: $_initialServiceAccountName (ID: $_initialServiceAccountId)',
        );
      }
      _loadServiceAccounts();
    }
  }

  // Load active request for selected service account
  Future<void> _loadActiveRequest() async {
    if (_selectedAccount == null) {
      appLog(
        '🔍 [_loadActiveRequest] No selected account, clearing active request',
      );
      setState(() => _activeRequest = null);
      return;
    }

    appLog(
      '🔍 [_loadActiveRequest] Loading for account: ${_selectedAccount!.name} (id: ${_selectedAccount!.id})',
    );

    setState(() => _isLoadingActiveRequest = true);

    try {
      final service = OffSchedulePickupService();
      final serviceAccountId = int.parse(_selectedAccount!.id);
      appLog(
        '🔍 [_loadActiveRequest] Parsed serviceAccountId: $serviceAccountId',
      );

      final activeRequest = await service.getActiveRequestByServiceAccount(
        serviceAccountId,
      );

      if (!mounted) return;

      appLog(
        '🔍 [_loadActiveRequest] Result: ${activeRequest != null ? "Found request ${activeRequest.id} with status ${activeRequest.requestStatus}" : "No active request"}',
      );

      setState(() {
        _activeRequest = activeRequest;
        _isLoadingActiveRequest = false;
      });
    } catch (e) {
      appLog('❌ [_loadActiveRequest] Error: $e');
      if (!mounted) return;
      setState(() {
        _activeRequest = null;
        _isLoadingActiveRequest = false;
      });
    }
  }

  // Load pricing info from API
  Future<void> _loadPricingInfo() async {
    setState(() => _isLoadingPricing = true);
    try {
      final service = OffSchedulePickupService();
      final data = await service.getPricingInfo();
      if (!mounted) return;
      setState(() {
        _pricingInfo = data;
        _isLoadingPricing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPricing = false);
    }
  }

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => '${m[1]}.')}';
  }

  // Preview skip scheduled pickups
  Future<void> _previewSkipScheduled() async {
    if (_selectedDate == null || _selectedAccount == null) return;

    try {
      final service = OffSchedulePickupService();
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      final data = await service.previewSkipScheduled(
        serviceAccountId: int.parse(_selectedAccount!.id),
        requestedPickupDate: formattedDate,
      );

      if (!mounted) return;

      // Show dialog if there are pickups to skip
      final pickupsToSkip = data['scheduled_pickups_to_skip'] as List?;
      if (pickupsToSkip != null && pickupsToSkip.isNotEmpty) {
        _showSkipConfirmationDialog(data);
      }
    } catch (e) {
      if (!mounted) return;
      appLog('Error previewing skip: $e');
    }
  }

  // Show skip confirmation dialog
  void _showSkipConfirmationDialog(Map<String, dynamic> previewData) {
    final pickupsToSkip = previewData['scheduled_pickups_to_skip'] as List;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.event_busy, color: Colors.orange[700], size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Jadwal yang Akan Di-skip',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
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
              'Jika Anda mengaktifkan opsi "Skip jadwal berikutnya", jadwal pickup di bawah ini akan di-skip:',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: pickupsToSkip.map((pickup) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${DateFormat('dd MMM yyyy').format(DateTime.parse(pickup['pickup_date']))} - ${pickup['day_name']}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              previewData['note'] ?? '',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
  }

  String _formatSurcharge(Map<String, dynamic>? info) {
    if (info == null) return '-';
    final formatted = info['formatted_surcharge'];
    if (formatted != null && formatted.toString().isNotEmpty) {
      return formatted.toString();
    }

    final raw = info['off_schedule_surcharge'];
    if (raw == null) return '-';
    if (raw is num) return _formatCurrency(raw.toInt());
    final parsed = int.tryParse(raw.toString());
    if (parsed != null) return _formatCurrency(parsed);
    return raw.toString();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // Load service accounts dari API
  Future<void> _loadServiceAccounts() async {
    setState(() => _isLoadingAccounts = true);
    try {
      final serviceAccountService = ServiceAccountService();
      final accounts = await serviceAccountService.fetchAccounts();

      if (!mounted) return;
      setState(() {
        _serviceAccounts = accounts;
        // Pilih akun berdasarkan initial ID dari home, atau default ke pertama
        if (accounts.isNotEmpty) {
          if (_initialServiceAccountId != null) {
            // Cari akun yang sesuai dengan ID dari home
            _selectedAccount = accounts.firstWhere(
              (acc) => acc.id == _initialServiceAccountId,
              orElse: () => accounts.first,
            );
            appLog(
              '[EXPRESS] Auto-selected account: ${_selectedAccount?.name} (ID: ${_selectedAccount?.id})',
            );
          } else {
            _selectedAccount = accounts.first;
          }
        }
        _isLoadingAccounts = false;
      });
      // Load pricing info after accounts are loaded
      _loadPricingInfo();
      // Load active request for selected account
      _loadActiveRequest();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAccounts = false;
      });
    }
  }

  // Fungsi untuk memilih tanggal
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Fungsi untuk memilih waktu
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Fungsi untuk mengirim request
  Future<void> _submitRequest() async {
    // Validasi
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pilih tanggal penjemputan',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Akun layanan tidak tersedia',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Format tanggal ke YYYY-MM-DD
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      // Format waktu ke HH:mm (jika ada)
      String? formattedTime;
      if (_selectedTime != null) {
        final hour = _selectedTime!.hour.toString().padLeft(2, '0');
        final minute = _selectedTime!.minute.toString().padLeft(2, '0');
        formattedTime = '$hour:$minute';
      }

      // Kirim request ke API
      final service = OffSchedulePickupService();
      final result = await service.createRequest(
        serviceAccountId: int.parse(_selectedAccount!.id),
        requestedPickupDate: formattedDate,
        requestedPickupTime: formattedTime,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        skipNextScheduled: _skipNextScheduled,
      );

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      // Extract data from result
      final pickup = result['data'];
      final message = result['message'] as String? ?? 'Request berhasil dibuat';
      final skippedPickups = result['skipped_pickups'] as List? ?? [];

      // Tampilkan dialog sukses dengan data dari API
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
                  'Request Terkirim',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      'Tanggal',
                      pickup['requested_pickup_date'] ?? '-',
                      primaryColor,
                    ),
                    if (pickup['requested_pickup_time'] != null) ...[
                      const Divider(height: 16),
                      _buildDetailRow(
                        'Waktu',
                        pickup['requested_pickup_time'],
                        primaryColor,
                      ),
                    ],
                    if (pickup['extra_fee'] != null &&
                        pickup['extra_fee'] > 0) ...[
                      const Divider(height: 16),
                      _buildDetailRow(
                        'Biaya Tambahan',
                        _formatCurrency(pickup['extra_fee']),
                        Colors.orange,
                      ),
                    ],
                  ],
                ),
              ),
              if (skippedPickups.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 16,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Jadwal di-skip:',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...skippedPickups.map(
                        (sp) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '• ${DateFormat('dd MMM yyyy').format(DateTime.parse(sp['pickup_date']))}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Petugas akan segera menghubungi Anda.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
                Navigator.pop(context); // Kembali ke home
              },
              child: Text(
                'Tutup',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
                // Navigasi ke detail screen dengan status tracker
                final pickupId = pickup['id'];
                if (pickupId != null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          OffSchedulePickupDetailScreen(pickupId: pickupId),
                    ),
                  );
                } else {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Lihat Status',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Helper untuk menampilkan detail row di dialog
  Widget _buildDetailRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // Build simplified calendar grid
  Widget _buildCalendarGrid() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday

    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            // Weekday labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            // Calendar days grid (real dates)
            ...List.generate(6, (rowIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (colIndex) {
                    final cellIndex = rowIndex * 7 + colIndex;
                    final dayNumber = cellIndex - startWeekday + 1;

                    // Empty cell or out of range
                    if (dayNumber < 1 || dayNumber > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 28));
                    }

                    final cellDate = DateTime(now.year, now.month, dayNumber);
                    final isToday = dayNumber == now.day;
                    final isSelected =
                        _selectedDate != null &&
                        _selectedDate!.year == cellDate.year &&
                        _selectedDate!.month == cellDate.month &&
                        _selectedDate!.day == cellDate.day;

                    return Expanded(
                      child: Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor
                                : isToday
                                ? Colors.orange.shade100
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: isToday && !isSelected
                                ? Border.all(color: Colors.orange, width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '$dayNumber',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: isSelected || isToday
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                    ? Colors.orange.shade800
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
            const SizedBox(height: 6),
            // Tap to select hint
            Text(
              'Tap untuk memilih tanggal',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget untuk menampilkan info card dengan icon
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
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
          'Request Pengambilan',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Waktu & Tanggal Penjemputan
              Text(
                'Waktu & Tanggal Penjemputan',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Calendar Visual dengan Waktu
              Container(
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
                  children: [
                    // Tanggal dan Waktu selector dalam border abu-abu
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Tanggal selector
                          Expanded(
                            child: GestureDetector(
                              onTap: _selectDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedDate != null
                                        ? primaryColor.withValues(alpha: 0.3)
                                        : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      color: _selectedDate != null
                                          ? primaryColor
                                          : Colors.grey.shade500,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _selectedDate != null
                                            ? DateFormat(
                                                'dd MMM yyyy',
                                              ).format(_selectedDate!)
                                            : 'Pilih Tanggal',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _selectedDate != null
                                              ? Colors.black87
                                              : Colors.grey.shade500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Waktu selector
                          Expanded(
                            child: GestureDetector(
                              onTap: _selectTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedTime != null
                                        ? primaryColor.withValues(alpha: 0.3)
                                        : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      color: _selectedTime != null
                                          ? primaryColor
                                          : Colors.grey.shade500,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _selectedTime != null
                                            ? _selectedTime!.format(context)
                                            : 'Pilih Jam',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _selectedTime != null
                                              ? Colors.black87
                                              : Colors.grey.shade500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
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
                    // Calendar Grid (Simplified)
                    _buildCalendarGrid(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Pricing info - show surcharge information
              if (_isLoadingPricing)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(
                        color: primaryColor,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              else if (_pricingInfo != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade50,
                        Colors.orange.shade100.withValues(alpha: 0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.shade200,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.shade600.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Informasi Biaya',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _pricingInfo!['message'] ??
                                  'Biaya tambahan untuk pickup di luar jadwal',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.payments_outlined,
                                    size: 18,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatSurcharge(_pricingInfo),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Skip Next Scheduled Checkbox
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: CheckboxListTile(
                  value: _skipNextScheduled,
                  onChanged: _selectedDate != null && _selectedAccount != null
                      ? (value) {
                          setState(() {
                            _skipNextScheduled = value ?? false;
                          });
                          // Preview jika dicentang
                          if (value == true) {
                            _previewSkipScheduled();
                          }
                        }
                      : null,
                  title: Row(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 20,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Skip jadwal berikutnya',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(left: 28, top: 4),
                    child: Text(
                      'Jadwal pickup reguler dalam minggu ini akan di-skip',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  activeColor: Colors.orange[700],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Status Request Aktif (jika ada)
              if (_activeRequest != null) ...[
                _buildActiveRequestStatus(),
                const SizedBox(height: 24),
              ] else if (_isLoadingActiveRequest) ...[
                _buildActiveRequestShimmer(),
                const SizedBox(height: 24),
              ],

              // Lokasi Penjemputan
              Text(
                'Lokasi Penjemputan',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Loading atau tampilkan service account
              _isLoadingAccounts
                  ? Container(
                      padding: const EdgeInsets.all(20),
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
                      child: const Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      ),
                    )
                  : _serviceAccounts.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Anda belum memiliki akun layanan. Silakan buat akun terlebih dahulu.',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
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
                          // Dropdown untuk pilih akun (jika ada lebih dari 1)
                          if (_serviceAccounts.length > 1)
                            Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: DropdownButtonFormField<ServiceAccount>(
                                initialValue: _selectedAccount,
                                decoration: InputDecoration(
                                  labelText: 'Pilih Akun Layanan',
                                  labelStyle: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.home_outlined,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                                ),
                                dropdownColor: Colors.white,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: primaryColor,
                                ),
                                items: _serviceAccounts.map((account) {
                                  return DropdownMenuItem(
                                    value: account,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          // Icon akun dengan background
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(alpha:
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.home_rounded,
                                              color: primaryColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Info akun
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  account.name,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.location_on,
                                                      size: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        account.address,
                                                        style:
                                                            GoogleFonts.poppins(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (account.rwName != null) ...[
                                                  const SizedBox(height: 2),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.orange.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .orange
                                                            .shade200,
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      account.rwName!,
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .orange
                                                                .shade800,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                selectedItemBuilder: (BuildContext context) {
                                  return _serviceAccounts.map((account) {
                                    return Text(
                                      account.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    );
                                  }).toList();
                                },
                                onChanged: (ServiceAccount? newValue) {
                                  setState(() {
                                    _selectedAccount = newValue;
                                  });
                                  // Load active request for the new selected service account
                                  _loadActiveRequest();
                                },
                              ),
                            ),

                          // Tampilkan detail lokasi dengan design yang lebih menarik
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header alamat dengan icon
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryColor.withValues(alpha: 0.1),
                                        primaryColor.withValues(alpha: 0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryColor.withValues(alpha:
                                                0.3,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Alamat Penjemputan',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _selectedAccount?.address ?? '-',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Detail informasi dengan card terpisah
                                Text(
                                  'Detail Informasi',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Info cards
                                _buildInfoCard(
                                  icon: Icons.person_outline,
                                  label: 'Nama Akun',
                                  value: _selectedAccount?.name ?? '-',
                                  color: Colors.blue,
                                ),
                                const SizedBox(height: 10),
                                _buildInfoCard(
                                  icon: Icons.apartment_outlined,
                                  label: 'Kelurahan',
                                  value: _selectedAccount?.kelurahanName ?? '-',
                                  color: Colors.purple,
                                ),
                                const SizedBox(height: 10),
                                _buildInfoCard(
                                  icon: Icons.location_city_outlined,
                                  label: 'RW',
                                  value: _selectedAccount?.rwName ?? '-',
                                  color: Colors.orange,
                                ),
                                if (_selectedAccount?.contactPhone != null) ...[
                                  const SizedBox(height: 10),
                                  _buildInfoCard(
                                    icon: Icons.phone_outlined,
                                    label: 'No. Telepon',
                                    value: _selectedAccount!.contactPhone!,
                                    color: Colors.green,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

              const SizedBox(height: 24),

              // Catatan Tambahan
              Text(
                'Catatan Tambahan (Opsional)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
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
                child: TextField(
                  controller: _noteController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Mohon diambil pagi hari sebelum jam 9',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ),

              const SizedBox(height: 40),

              // Tombol Kirim Request - Hanya tampilkan jika tidak ada request aktif yang belum selesai
              if (_activeRequest == null ||
                  _activeRequest!.requestStatus == 'completed' ||
                  _activeRequest!.requestStatus == 'paid' ||
                  _activeRequest!.requestStatus == 'rejected')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
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
                            'Kirim Request',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Build active request status card with stepper
  Widget _buildActiveRequestStatus() {
    if (_activeRequest == null) return const SizedBox.shrink();

    final status = _activeRequest!.requestStatus;

    // Flow status: sent → processing → pending → completed/paid
    // sent = Menunggu penugasan kolektor
    // processing = Kolektor sedang proses pengambilan
    // pending = Sampah sudah diambil, menunggu konfirmasi user
    // completed/paid = Selesai

    // Determine step states based on correct flow
    bool isWaitingActive = status == 'sent';
    bool isWaitingCompleted =
        status == 'processing' ||
        status == 'pending' ||
        status == 'completed' ||
        status == 'paid';

    bool isProcessingActive = status == 'processing';
    bool isProcessingCompleted =
        status == 'pending' || status == 'completed' || status == 'paid';

    bool isCompletedActive =
        status == 'pending' || status == 'completed' || status == 'paid';

    // Get timestamps
    final createdAt = _activeRequest!.createdAt;
    final processedAt =
        _activeRequest!.processedAt ?? _activeRequest!.assignedAt;
    final completedAt =
        _activeRequest!.completedAt ?? _activeRequest!.collectedAt;

    return GestureDetector(
      onTap: () {
        // Navigate to detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                OffSchedulePickupDetailScreen(pickupId: _activeRequest!.id),
          ),
        ).then((_) => _loadActiveRequest());
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request Pengambilan Aktif',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Tap untuk lihat detail',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: primaryColor),
              ],
            ),

            const SizedBox(height: 16),

            // Timestamps row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimestampLabel(createdAt),
                _buildTimestampLabel(processedAt),
                _buildTimestampLabel(completedAt),
              ],
            ),

            const SizedBox(height: 12),

            // Progress stepper
            Row(
              children: [
                // Step 1: Menunggu
                _buildStatusStepItem(
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
                _buildStatusStepItem(
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
                _buildStatusStepItem(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Selesai',
                  sublabel: status == 'pending'
                      ? 'Menunggu\nkonfirmasi Anda'
                      : 'Request berhasil\ndiselesaikan',
                  isActive: isCompletedActive,
                  isCompleted: status == 'completed' || status == 'paid',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build timestamp label
  Widget _buildTimestampLabel(DateTime? dateTime) {
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

  // Build status step item
  Widget _buildStatusStepItem({
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
            width: 40,
            height: 40,
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
              size: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: isActive || isCompleted
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: isActive || isCompleted
                  ? primaryColor
                  : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: GoogleFonts.poppins(
              fontSize: 7,
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

  // Build shimmer loading for active request
  Widget _buildActiveRequestShimmer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 100,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              3,
              (index) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
