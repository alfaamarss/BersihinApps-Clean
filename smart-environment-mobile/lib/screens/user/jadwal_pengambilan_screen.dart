import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/resident_pickup_service.dart';
import '../../services/service_account_service.dart';

class JadwalPengambilanScreen extends StatefulWidget {
  final int? serviceAccountId;
  final String? hariPengangkutan; // Fallback dari service account

  const JadwalPengambilanScreen({
    super.key,
    this.serviceAccountId,
    this.hariPengangkutan,
  });

  @override
  State<JadwalPengambilanScreen> createState() =>
      _JadwalPengambilanScreenState();
}

class _JadwalPengambilanScreenState extends State<JadwalPengambilanScreen> {
  final ResidentPickupService _pickupService = ResidentPickupService();
  final ServiceAccountService _serviceAccountService = ServiceAccountService();

  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Highlighted dates (dates with schedules)
  Set<int> _scheduleDates = {};

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Panggil API untuk mendapatkan jadwal pickup yang akan datang
      final (success, message, pickups) = await _pickupService
          .getUpcomingPickups(
            serviceAccountId: widget.serviceAccountId?.toString(),
          );

      if (!mounted) return;

      if (success && pickups != null && pickups.isNotEmpty) {
        final Set<int> dates = {};
        final List<Map<String, dynamic>> allSchedules = [];

        for (var pickup in pickups) {
          // Parse pickup_date dari API (format: Y-m-d)
          final pickupDateStr = pickup['pickup_date']?.toString();
          if (pickupDateStr == null) continue;

          final date = DateTime.tryParse(pickupDateStr);
          if (date == null) continue;

          // Hanya tampilkan jadwal untuk bulan yang dipilih
          if (date.month == _selectedMonth.month &&
              date.year == _selectedMonth.year) {
            dates.add(date.day);

            // Ambil informasi waktu dari schedule_info
            final scheduleInfo =
                pickup['schedule_info'] as Map<String, dynamic>?;
            String time = '08:00'; // default
            if (scheduleInfo != null) {
              final timeStart = scheduleInfo['time_start']?.toString();
              if (timeStart != null && timeStart.isNotEmpty) {
                // Format time dari HH:MM:SS ke HH:MM
                time = timeStart.length >= 5
                    ? timeStart.substring(0, 5)
                    : timeStart;
              }
            }

            // Ambil nama hari dari API atau generate
            final dayName =
                pickup['day_name']?.toString() ?? _getDayName(date.weekday);

            allSchedules.add({
              'id': pickup['id'],
              'date': date,
              'day': dayName,
              'time': time,
              'status': pickup['status'] ?? 'scheduled',
              'confirmation_status': pickup['confirmation_status'],
              'collector_info': pickup['collector_info'],
              'can_confirm': pickup['can_confirm'] ?? false,
              'resident_note': pickup['resident_note'],
              'raw': pickup, // simpan data mentah untuk keperluan lain
            });
          }
        }

        // Sort schedules by date
        allSchedules.sort((a, b) {
          final dateA = a['date'] as DateTime;
          final dateB = b['date'] as DateTime;
          return dateA.compareTo(dateB);
        });

        setState(() {
          _scheduleDates = dates;
          _schedules = allSchedules;
          _isLoading = false;
        });

        appLog(
          '[JADWAL] Loaded ${allSchedules.length} schedules for ${_selectedMonth.month}/${_selectedMonth.year}',
        );
      } else {
        // ⭐ API gagal atau kosong - gunakan FALLBACK dari hariPengangkutan
        appLog(
          '[JADWAL] API failed or empty, trying fallback with hariPengangkutan...',
        );
        await _loadSchedulesFromHariPengangkutan();
      }
    } catch (e) {
      if (!mounted) return;
      appLog('[JADWAL] Exception: $e, trying fallback...');

      // ⭐ Exception - gunakan FALLBACK dari hariPengangkutan
      await _loadSchedulesFromHariPengangkutan();
    }
  }

  /// ⭐ FALLBACK: Generate jadwal dari hariPengangkutan service account
  Future<void> _loadSchedulesFromHariPengangkutan() async {
    try {
      // Prioritas 1: Gunakan hariPengangkutan dari widget parameter
      String? hariPengangkutan = widget.hariPengangkutan;

      // Prioritas 2: Fetch dari service account API jika tidak ada
      if ((hariPengangkutan == null || hariPengangkutan.isEmpty) &&
          widget.serviceAccountId != null) {
        appLog('[JADWAL] Fetching hariPengangkutan from service account API...');
        final account = await _serviceAccountService.getAccountById(
          widget.serviceAccountId.toString(),
        );
        if (account != null) {
          hariPengangkutan = account.hariPengangkutan;
          appLog('[JADWAL] Got hariPengangkutan from API: $hariPengangkutan');
        }
      }

      if (hariPengangkutan == null || hariPengangkutan.isEmpty) {
        // Tidak ada data jadwal sama sekali
        if (!mounted) return;
        setState(() {
          _schedules = [];
          _scheduleDates = {};
          _isLoading = false;
          _errorMessage = 'Jadwal pengangkutan belum diatur';
        });
        return;
      }

      // Parse hariPengangkutan untuk generate jadwal
      // Format yang mungkin: "Senin • 07:00" atau "Senin" atau "Senin, Kamis"
      final schedulesGenerated = _generateSchedulesFromHariPengangkutan(
        hariPengangkutan,
      );

      if (!mounted) return;
      setState(() {
        _schedules = schedulesGenerated;
        _scheduleDates = schedulesGenerated
            .map((s) => (s['date'] as DateTime).day)
            .toSet();
        _isLoading = false;
        _errorMessage = null;
      });

      appLog(
        '[JADWAL] Generated ${schedulesGenerated.length} schedules from hariPengangkutan',
      );
    } catch (e) {
      appLog('[JADWAL] Fallback also failed: $e');
      if (!mounted) return;
      setState(() {
        _schedules = [];
        _scheduleDates = {};
        _isLoading = false;
        _errorMessage = 'Gagal memuat jadwal';
      });
    }
  }

  /// Generate jadwal untuk bulan yang dipilih berdasarkan hariPengangkutan
  List<Map<String, dynamic>> _generateSchedulesFromHariPengangkutan(
    String hariPengangkutan,
  ) {
    final List<Map<String, dynamic>> schedules = [];

    // Parse format: "Senin • 07:00" atau "Senin" atau "Senin, Kamis"
    String time = '07:00'; // default
    String daysString = hariPengangkutan;

    // Cek apakah ada waktu (format: "Senin • 07:00")
    if (hariPengangkutan.contains('•')) {
      final parts = hariPengangkutan.split('•');
      daysString = parts[0].trim();
      if (parts.length > 1) {
        time = parts[1].trim();
      }
    } else if (hariPengangkutan.contains(':')) {
      // Format mungkin "Senin 07:00"
      final regex = RegExp(r'(\d{1,2}:\d{2})');
      final match = regex.firstMatch(hariPengangkutan);
      if (match != null) {
        time = match.group(1)!;
        daysString = hariPengangkutan.replaceAll(match.group(0)!, '').trim();
      }
    }

    // Parse hari-hari
    final dayMap = {
      'senin': 1,
      'selasa': 2,
      'rabu': 3,
      'kamis': 4,
      'jumat': 5,
      'jum\'at': 5,
      'sabtu': 6,
      'minggu': 7,
    };

    // Split by comma atau ampersand
    final dayParts = daysString
        .split(RegExp(r'[,&]'))
        .map((s) => s.trim().toLowerCase())
        .toList();

    // Dapatkan weekday dari nama hari
    final List<int> weekdays = [];
    for (final dayPart in dayParts) {
      for (final entry in dayMap.entries) {
        if (dayPart.contains(entry.key)) {
          weekdays.add(entry.value);
          break;
        }
      }
    }

    if (weekdays.isEmpty) {
      appLog(
        '[JADWAL] No weekdays found in hariPengangkutan: $hariPengangkutan',
      );
      return [];
    }

    // Generate tanggal untuk bulan yang dipilih
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      if (weekdays.contains(date.weekday)) {
        schedules.add({
          'id': 'generated_${date.toIso8601String()}',
          'date': date,
          'day': _getDayName(date.weekday),
          'time': time,
          'status': 'scheduled',
          'confirmation_status': null,
          'collector_info': null,
          'can_confirm': false,
          'resident_note': null,
          'raw': null,
        });
      }
    }

    // Sort by date
    schedules.sort((a, b) {
      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return dateA.compareTo(dateB);
    });

    return schedules;
  }

  String _getDayName(int weekday) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return days[weekday - 1];
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _selectedDate = null;
    });
    _loadSchedules();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _selectedDate = null;
    });
    _loadSchedules();
  }

  void _selectDate(int day) {
    setState(() {
      _selectedDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    });
  }

  List<Map<String, dynamic>> _getFilteredSchedules() {
    if (_selectedDate == null) {
      return _schedules;
    }

    return _schedules.where((schedule) {
      final scheduleDate = schedule['date'] as DateTime;
      return scheduleDate.day == _selectedDate!.day &&
          scheduleDate.month == _selectedDate!.month &&
          scheduleDate.year == _selectedDate!.year;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF009688);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Jadwal Pengambilan',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: _isLoading ? _buildShimmer() : _buildContent(primaryColor),
    );
  }

  Widget _buildContent(Color primaryColor) {
    // Format month name manually untuk menghindari issue dengan locale
    final monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final monthName = monthNames[_selectedMonth.month - 1];
    final yearName = _selectedMonth.year.toString();

    return Column(
      children: [
        // Calendar Section
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Navigator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$monthName $yearName',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: primaryColor),
                        onPressed: _previousMonth,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: primaryColor),
                        onPressed: _nextMonth,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Day Headers
              Row(
                children: ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),

              // Calendar Grid
              _buildCalendarGrid(primaryColor),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Schedule List Section
        Expanded(
          child: Container(
            color: Colors.white,
            child: _buildScheduleList(primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(Color primaryColor) {
    final firstDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    );
    final daysInMonth = lastDayOfMonth.day;

    // KALENDER INDONESIA: Minggu sebagai hari pertama
    // Header: ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']
    // Index:    0      1      2      3      4      5      6
    //
    // DateTime.weekday (ISO 8601):
    // Monday=1, Tuesday=2, Wednesday=3, Thursday=4, Friday=5, Saturday=6, Sunday=7
    //
    // Konversi ke index kalender Indonesia (Minggu=0):
    final int startWeekday = firstDayOfMonth.weekday % 7;

    // Build grid dengan 6 baris x 7 kolom (42 cells total)
    List<Widget> calendarCells = [];

    // Tambah empty cells sebelum tanggal 1
    for (int i = 0; i < startWeekday; i++) {
      calendarCells.add(_buildEmptyCell());
    }

    // Tambah cells untuk setiap tanggal
    for (int day = 1; day <= daysInMonth; day++) {
      calendarCells.add(_buildDayCell(day, primaryColor));
    }

    // Hitung jumlah baris yang benar-benar dibutuhkan (5 atau 6)
    final totalDaysAndPadding = startWeekday + daysInMonth;
    final int rowCount = (totalDaysAndPadding / 7).ceil();
    final int totalRequiredCells = rowCount * 7;
    final remainingCells = totalRequiredCells - calendarCells.length;
    for (int i = 0; i < remainingCells; i++) {
      calendarCells.add(_buildEmptyCell());
    }

    // Buat baris sesuai rowCount, masing-masing 7 kolom
    List<Widget> rows = [];
    for (int row = 0; row < rowCount; row++) {
      final startIndex = row * 7;
      final endIndex = startIndex + 7;

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: calendarCells.sublist(startIndex, endIndex),
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildEmptyCell() {
    return const Expanded(
      child: SizedBox(height: 44),
    );
  }

  Widget _buildDayCell(int day, Color primaryColor) {
    final hasSchedule = _scheduleDates.contains(day);
    final isSelected =
        _selectedDate?.day == day &&
        _selectedDate?.month == _selectedMonth.month &&
        _selectedDate?.year == _selectedMonth.year;
    final isToday =
        DateTime.now().day == day &&
        DateTime.now().month == _selectedMonth.month &&
        DateTime.now().year == _selectedMonth.year;

    return Expanded(
      child: GestureDetector(
        onTap: hasSchedule ? () => _selectDate(day) : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor
                  : hasSchedule
                  ? primaryColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(color: primaryColor, width: 2)
                  : null,
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: hasSchedule || isToday
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleList(Color primaryColor) {
    // Tampilkan error jika ada
    if (_errorMessage != null && _schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.orange[300]),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat jadwal',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSchedules,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('Coba Lagi', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final filteredSchedules = _getFilteredSchedules();

    if (filteredSchedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada jadwal',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDate != null
                  ? 'Pilih tanggal lain yang ditandai'
                  : 'Belum ada jadwal pengambilan untuk bulan ini',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadSchedules,
              icon: Icon(Icons.refresh, size: 18, color: primaryColor),
              label: Text(
                'Muat Ulang',
                style: GoogleFonts.poppins(color: primaryColor),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredSchedules.length,
      itemBuilder: (context, index) {
        final schedule = filteredSchedules[index];
        final date = schedule['date'] as DateTime;
        final day = schedule['day'] as String;
        final time = schedule['time'] as String;
        final status = schedule['status'] as String? ?? 'scheduled';
        final confirmationStatus = schedule['confirmation_status'] as String?;
        final collectorInfo =
            schedule['collector_info'] as Map<String, dynamic>?;

        // Determine color based on status
        Color statusColor = primaryColor;
        if (status == 'in_progress') {
          statusColor = Colors.blue;
        } else if (status == 'completed') {
          statusColor = Colors.green;
        } else if (status == 'cancelled') {
          statusColor = Colors.red;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.03),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Date Box
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      date.day.toString().padLeft(2, '0'),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (collectorInfo != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                collectorInfo['name']?.toString() ?? '-',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (confirmationStatus != null &&
                          confirmationStatus != 'pending') ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getConfirmationColor(
                              confirmationStatus,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getConfirmationText(confirmationStatus),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _getConfirmationColor(confirmationStatus),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Status indicator
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getConfirmationColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'no_waste':
        return Colors.orange;
      case 'skipped':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getConfirmationText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'no_waste':
        return 'Tidak Ada Sampah';
      case 'skipped':
        return 'Dilewati';
      case 'pending':
        return 'Menunggu';
      default:
        return status;
    }
  }

  Widget _buildShimmer() {
    return Column(
      children: [
        // Calendar Shimmer
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Month header shimmer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _shimmerBox(width: 120, height: 20),
                  Row(
                    children: [
                      _shimmerBox(width: 24, height: 24, radius: 12),
                      const SizedBox(width: 16),
                      _shimmerBox(width: 24, height: 24, radius: 12),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Day headers shimmer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  7,
                  (index) => _shimmerBox(width: 30, height: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Calendar grid shimmer
              Column(
                children: List.generate(
                  5,
                  (rowIndex) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        7,
                        (colIndex) =>
                            _shimmerBox(width: 36, height: 36, radius: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Schedule list shimmer
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      _shimmerBox(width: 48, height: 48, radius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _shimmerBox(width: 80, height: 16),
                            const SizedBox(height: 6),
                            _shimmerBox(width: 60, height: 14),
                          ],
                        ),
                      ),
                      _shimmerBox(width: 4, height: 40, radius: 2),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    double radius = 8,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
