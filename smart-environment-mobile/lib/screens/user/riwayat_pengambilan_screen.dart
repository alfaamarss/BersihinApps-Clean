import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/api_config.dart';
import '../../services/resident_pickup_service.dart';
import '../../services/off_schedule_pickup_service.dart';
import 'package:intl/intl.dart';
import 'pelaporan_screen.dart';

/// 🔹 Halaman Riwayat Pengambilan Sampah
class RiwayatPengambilanScreen extends StatefulWidget {
  final String serviceAccountId;
  final String accountName;
  final String? accountAddress;

  const RiwayatPengambilanScreen({
    super.key,
    required this.serviceAccountId,
    required this.accountName,
    this.accountAddress,
  });

  @override
  State<RiwayatPengambilanScreen> createState() =>
      _RiwayatPengambilanScreenState();
}

class _RiwayatPengambilanScreenState extends State<RiwayatPengambilanScreen> {
  final ResidentPickupService _pickupService = ResidentPickupService();
  final OffSchedulePickupService _offScheduleService =
      OffSchedulePickupService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _pickupHistory = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Muat riwayat pickup dari API
  Future<void> _loadHistory() async {
    if (!mounted) {
      appLog('[WARN] [RiwayatPengambilan] Widget not mounted, aborting load');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      appLog(
        '[SYNC] [RiwayatPengambilan] Loading history for account: ${widget.accountName} (ID: ${widget.serviceAccountId})',
      );

      // Validasi service account ID
      if (widget.serviceAccountId.isEmpty || widget.serviceAccountId == '0') {
        throw Exception('ID akun tidak valid');
      }

      // 1. Load regular scheduled pickups
      final (success, message, regularPickups) = await _pickupService
          .getPickupHistory(serviceAccountId: widget.serviceAccountId);

      if (!mounted) {
        appLog('[WARN] [RiwayatPengambilan] Widget unmounted during API call');
        return;
      }

      appLog(
        '[STATS] [RiwayatPengambilan] Regular pickups - Success: $success, Message: $message, Items: ${regularPickups?.length ?? 0}',
      );

      // 2. Load off-schedule pickups
      List<Map<String, dynamic>> offSchedulePickups = [];
      try {
        final offScheduleList = await _offScheduleService.listRequests(
          // Tidak filter by status - ambil semua
          perPage: 100,
        );

        appLog(
          '[STATS] [RiwayatPengambilan] Raw off-schedule list from API: ${offScheduleList.length} items',
        );
        for (var p in offScheduleList) {
          appLog(
            '   - ID: ${p.id}, Status: ${p.status}, ServiceAccountId: ${p.serviceAccountId}',
          );
        }

        // Filter berdasarkan service account ID
        final serviceAccountIdInt = int.tryParse(widget.serviceAccountId);
        appLog(
          '[SEARCH] [RiwayatPengambilan] Filtering for serviceAccountId: $serviceAccountIdInt',
        );

        if (serviceAccountIdInt != null) {
          // Status yang menandakan sampah sudah diangkut/selesai:
          // - 'pending': Kolektor sudah input sampah, menunggu konfirmasi user
          // - 'completed': Sudah dikonfirmasi selesai
          // - 'paid': Sudah lunas/dibayar
          //
          // Status yang TIDAK boleh muncul di riwayat (belum diangkut):
          // - 'sent': Menunggu penugasan kolektor
          // - 'processing': Kolektor ditugaskan tapi belum mengambil sampah
          // - 'rejected': Ditolak
          final completedStatuses = ['pending', 'completed', 'paid'];

          offSchedulePickups = offScheduleList
              .where((p) {
                // Filter by service account
                final matchesAccount =
                    p.serviceAccountId == serviceAccountIdInt;

                // Filter by status - hanya tampilkan yang sampahnya sudah diangkut
                final isCollected = completedStatuses.contains(p.requestStatus);

                appLog(
                  '   Pickup #${p.id}: serviceAccountId=${p.serviceAccountId}, matchesAccount=$matchesAccount, requestStatus=${p.requestStatus}, isCollected=$isCollected',
                );

                // Hanya tampilkan jika service account cocok DAN sampah sudah diangkut
                return matchesAccount && isCollected;
              })
              .map((p) {
                // Konversi OffSchedulePickup ke Map dengan flag is_off_schedule
                final json = p.toJson();
                json['is_off_schedule'] = true; // Tandai sebagai off-schedule
                json['pickup_type'] =
                    'request'; // Pastikan pickup_type adalah request
                appLog(
                  '[OK] [RiwayatPengambilan] Added off-schedule pickup #${p.id} to list (status: ${p.requestStatus})',
                );
                return json;
              })
              .toList();
        }

        appLog(
          '[STATS] [RiwayatPengambilan] Filtered off-schedule pickups: ${offSchedulePickups.length} items',
        );
      } catch (e, stackTrace) {
        appLog(
          '[WARN] [RiwayatPengambilan] Error loading off-schedule pickups: $e',
        );
        appLog('   Stack: $stackTrace');
        // Continue dengan regular pickups saja jika off-schedule gagal
      }

      // 3. Gabungkan kedua list
      List<Map<String, dynamic>> allPickups = [];

      // Set untuk tracking ID off-schedule yang sudah diambil
      Set<int> offScheduleIds = offSchedulePickups
          .map((p) => p['id'] as int?)
          .whereType<int>()
          .toSet();

      appLog('[SEARCH] [RiwayatPengambilan] Off-schedule IDs: $offScheduleIds');

      if (success && regularPickups != null) {
        // Proses regular pickups - cek apakah sebenarnya off-schedule
        for (var pickup in regularPickups) {
          final pickupId = pickup['id'];
          final pickupIdInt = pickupId is int
              ? pickupId
              : int.tryParse(pickupId?.toString() ?? '');

          // ⭐ PENTING: Cek apakah pickup ini ada di daftar off-schedule berdasarkan ID
          final bool isInOffScheduleList =
              pickupIdInt != null && offScheduleIds.contains(pickupIdInt);

          // Cek apakah pickup ini sebenarnya off-schedule berdasarkan berbagai indikator
          final pickupType =
              pickup['pickup_type']?.toString().toLowerCase() ?? '';
          final bool isActuallyOffSchedule =
              // ⭐ Prioritas 1: Cek apakah ada di daftar off-schedule
              isInOffScheduleList ||
              // Cek dari pickup_type
              pickupType == 'request' ||
              pickupType == 'off_schedule' ||
              pickupType == 'off-schedule' ||
              pickupType == 'express' ||
              // Cek dari field khusus off-schedule
              pickup['is_off_schedule'] == true ||
              pickup['is_request'] == true ||
              // Cek field yang hanya ada di off-schedule
              (pickup['bag_count'] != null &&
                  (pickup['bag_count'] as num) > 0) ||
              (pickup['extra_fee'] != null &&
                  (pickup['extra_fee'] as num) > 0) ||
              pickup['base_amount'] != null ||
              pickup['requested_pickup_date'] != null ||
              pickup['request_status'] != null ||
              // ⭐ Cek jika source/origin adalah request
              pickup['source']?.toString().toLowerCase() == 'request' ||
              pickup['origin']?.toString().toLowerCase() == 'request' ||
              // Cek jika off_schedule_pickup_id ada
              pickup['off_schedule_pickup_id'] != null;

          // Skip jika sudah ada di offSchedulePickups (menghindari duplikat)
          if (isInOffScheduleList) {
            appLog(
              '[SKIP] [RiwayatPengambilan] Skipping pickup #$pickupId - already in off-schedule list, will use that instead',
            );
            continue;
          }

          // Tandai berdasarkan deteksi
          pickup['is_off_schedule'] = isActuallyOffSchedule;
          pickup['pickup_type'] = isActuallyOffSchedule
              ? 'request'
              : (pickup['pickup_type'] ?? 'scheduled');

          appLog(
            '[TAG] [RiwayatPengambilan] Pickup #$pickupId - detected as ${isActuallyOffSchedule ? "OFF-SCHEDULE" : "REGULAR"}',
          );
          appLog(
            '   pickup_type: $pickupType, bag_count: ${pickup['bag_count']}, extra_fee: ${pickup['extra_fee']}',
          );
          appLog(
            '   base_amount: ${pickup['base_amount']}, requested_pickup_date: ${pickup['requested_pickup_date']}',
          );
          appLog(
            '   source: ${pickup['source']}, origin: ${pickup['origin']}, off_schedule_pickup_id: ${pickup['off_schedule_pickup_id']}',
          );

          allPickups.add(pickup);
        }

        // Debug: Print sample data structure
        if (regularPickups.isNotEmpty) {
          appLog('[SEARCH] [RiwayatPengambilan] Sample regular pickup data:');
          appLog('   Keys: ${regularPickups[0].keys}');
          appLog('   ALL DATA: ${regularPickups[0]}');

          // ⚠️ PENTING: Cek service_account structure
          final serviceAccount = regularPickups[0]['service_account'];
          appLog(
            '[BLDG] [RiwayatPengambilan] SERVICE ACCOUNT DATA: $serviceAccount',
          );
          if (serviceAccount is Map<String, dynamic>) {
            appLog(
              '[BLDG] [RiwayatPengambilan] SERVICE ACCOUNT KEYS: ${serviceAccount.keys.toList()}',
            );
            appLog(
              '[BLDG] [RiwayatPengambilan] ADDRESS FIELD: ${serviceAccount['address']}',
            );
            appLog(
              '[BLDG] [RiwayatPengambilan] ALAMAT FIELD: ${serviceAccount['alamat']}',
            );
            appLog(
              '[BLDG] [RiwayatPengambilan] ALAMAT_LENGKAP FIELD: ${serviceAccount['alamat_lengkap']}',
            );
          }

          // ⚠️ PENTING: Cek confirmation_status dari API
          final confirmationStatus = regularPickups[0]['confirmation_status'];
          appLog(
            '[WARN] [RiwayatPengambilan] CONFIRMATION STATUS dari API: $confirmationStatus',
          );
          appLog(
            '   [NO] Jika status = "confirmed", berarti BACKEND yang salah!',
          );
          appLog(
            '   [OK] Seharusnya status = "pending" agar user bisa konfirmasi manual',
          );

          // Check ALL possible photo fields
          final photoUrl = regularPickups[0]['photo_url'];
          final image = regularPickups[0]['image'];
          final photo = regularPickups[0]['photo'];
          final pickupPhoto = regularPickups[0]['pickup_photo'];
          final photoPath = regularPickups[0]['photo_path'];
          final imagePath = regularPickups[0]['image_path'];

          appLog('[IMG] [RiwayatPengambilan] Photo fields:');
          appLog('   photo_url: $photoUrl');
          appLog('   image: $image');
          appLog('   photo: $photo');
          appLog('   pickup_photo: $pickupPhoto');
          appLog('   photo_path: $photoPath');
          appLog('   image_path: $imagePath');

          // Check pickup type fields
          final pickupType = regularPickups[0]['pickup_type'];
          final type = regularPickups[0]['type'];
          final isOffSchedule = regularPickups[0]['is_off_schedule'];
          final isRequest = regularPickups[0]['is_request'];

          appLog('[TAG] [RiwayatPengambilan] Pickup type fields:');
          appLog('   pickup_type: $pickupType');
          appLog('   type: $type');
          appLog('   is_off_schedule: $isOffSchedule');
          appLog('   is_request: $isRequest');
        }
      }

      // Tambahkan off-schedule pickups
      allPickups.addAll(offSchedulePickups);

      // Sort by date (terbaru dulu)
      allPickups.sort((a, b) {
        final dateA =
            a['pickup_date'] ??
            a['requested_pickup_date'] ??
            a['created_at'] ??
            '';
        final dateB =
            b['pickup_date'] ??
            b['requested_pickup_date'] ??
            b['created_at'] ??
            '';
        return dateB.toString().compareTo(dateA.toString());
      });

      appLog(
        '[STATS] [RiwayatPengambilan] Total combined pickups: ${allPickups.length}',
      );

      setState(() {
        _pickupHistory = allPickups;
        _isLoading = false;
      });

      if (allPickups.isEmpty) {
        appLog('[WARN] [RiwayatPengambilan] No pickup history found');
      } else {
        appLog(
          '[OK] [RiwayatPengambilan] Loaded ${allPickups.length} pickup records (${regularPickups?.length ?? 0} regular + ${offSchedulePickups.length} off-schedule)',
        );
      }
    } catch (e, stackTrace) {
      appLog('[ERROR] [RiwayatPengambilan] Error loading history: $e');
      appLog('Stack trace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    appLog(
      '[BUILD] [RiwayatPengambilan] Building widget - Loading: $_isLoading, Error: $_errorMessage, Items: ${_pickupHistory.length}',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Riwayat Pengambilan Sampah",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            Text(
              widget.accountName,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            appLog('⬅️ [RiwayatPengambilan] Back button pressed');
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _isLoading ? _buildShimmer() : _buildContent(),
    );
  }

  /// Shimmer loading
  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  /// Content
  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 21, 145, 137),
              ),
            ),
          ],
        ),
      );
    }

    if (_pickupHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/Riwayat pengambilan sampah.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              "Belum ada riwayat pengambilan",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _pickupHistory.length,
        itemBuilder: (context, index) {
          final pickup = _pickupHistory[index];
          return _buildPickupCard(pickup);
        },
      ),
    );
  }

  /// Card untuk setiap pickup - Satu card per pickup (bukan per item)
  Widget _buildPickupCard(Map<String, dynamic> pickup) {
    try {
      final pickupDate =
          pickup['pickup_date'] ?? pickup['requested_pickup_date'] as String?;
      final wasteItems = pickup['waste_items'] as List<dynamic>?;
      final serviceAccount = pickup['service_account'] as Map<String, dynamic>?;
      final pickupId = pickup['id']?.toString();
      final confirmationStatus =
          pickup['confirmation_status']?.toString() ?? 'pending';

      // Deteksi tipe pickup: request (off-schedule) atau terjadwal (regular/scheduled)
      // Data sudah ditandai saat load, jadi cukup cek is_off_schedule
      final bool isOffSchedule = pickup['is_off_schedule'] == true;

      // Debug log untuk membantu identifikasi
      appLog('🏷️ [Card] Pickup #$pickupId - is_off_schedule: $isOffSchedule');

      // Label dan warna berdasarkan tipe
      final typeLabel = isOffSchedule ? 'Request' : 'Terjadwal';
      final typeColor = isOffSchedule ? Colors.orange : const Color(0xFF009688);
      final typeBgColor = isOffSchedule
          ? Colors.orange.shade50
          : const Color(0xFF009688).withValues(alpha: 0.1);

      // Off-schedule pickup mungkin tidak punya waste_items
      if (!isOffSchedule && (wasteItems == null || wasteItems.isEmpty)) {
        appLog('⚠️ [RiwayatPengambilan] Empty waste items for regular pickup');
        return const SizedBox.shrink();
      }

      // ✅ CEK AUTO-KONFIRMASI: Jika sudah lewat 3 hari dan masih pending, auto-konfirmasi
      // Skip auto-konfirmasi untuk off-schedule pickup
      if (!isOffSchedule &&
          confirmationStatus == 'pending' &&
          pickupDate != null) {
        try {
          final pickupDateTime = DateTime.parse(pickupDate);
          final now = DateTime.now();
          final daysDifference = now.difference(pickupDateTime).inDays;

          if (daysDifference >= 3) {
            appLog(
              '⏰ [RiwayatPengambilan] Pickup #$pickupId sudah $daysDifference hari - AUTO KONFIRMASI',
            );

            // Trigger auto-konfirmasi di background menggunakan API baru
            Future.microtask(() async {
              try {
                final (success, message, data) = await _pickupService
                    .confirmWasteDelivery(pickupId!);
                if (success) {
                  appLog(
                    '✅ [RiwayatPengambilan] Auto-konfirmasi berhasil untuk Pickup #$pickupId',
                  );

                  // Reload history setelah auto-konfirmasi
                  if (mounted) {
                    await _loadHistory();
                  }
                } else {
                  appLog(
                    '❌ [RiwayatPengambilan] Gagal auto-konfirmasi: $message',
                  );
                }
              } catch (e) {
                appLog('❌ [RiwayatPengambilan] Error auto-konfirmasi: $e');
              }
            });
          }
        } catch (e) {
          appLog('⚠️ [RiwayatPengambilan] Error parsing pickup date: $e');
        }
      }

      // Calculate totals for this pickup
      // Untuk off-schedule, waste_items mungkin kosong, gunakan bag_count
      int totalItems = isOffSchedule
          ? (pickup['bag_count'] ?? 1)
          : (wasteItems?.length ?? 0);

      // ✅ Gunakan total_amount dari API sebagai sumber kebenaran
      // Ini memastikan harga yang ditampilkan sama dengan yang ada di admin/kolektor
      double totalPrice = 0;
      final apiTotalAmount = pickup['total_amount'];
      if (apiTotalAmount != null) {
        if (apiTotalAmount is num) {
          totalPrice = apiTotalAmount.toDouble();
        } else if (apiTotalAmount is String) {
          totalPrice = double.tryParse(apiTotalAmount) ?? 0;
        }
        appLog(
          '💰 [RiwayatPengambilan] Using total_amount from API: $totalPrice',
        );
      } else if (wasteItems != null && wasteItems.isNotEmpty) {
        // Fallback: hitung dari waste_items jika total_amount tidak tersedia
        appLog(
          '⚠️ [RiwayatPengambilan] total_amount not found, calculating from waste_items',
        );
        for (var item in wasteItems) {
          try {
            final itemPrice = item['total_price'] ?? 0;
            totalPrice += itemPrice is String
                ? double.tryParse(itemPrice) ?? 0
                : (itemPrice as num).toDouble();
          } catch (e) {
            appLog('⚠️ [RiwayatPengambilan] Error calculating item price: $e');
          }
        }
      }

      // Get dominant waste type (yang paling banyak)
      Map<String, int> typeCount = {};

      if (wasteItems != null && wasteItems.isNotEmpty) {
        for (var item in wasteItems) {
          try {
            // Count waste types
            final wasteType =
                item['waste_type']?.toString() ??
                item['waste']?['type']?.toString() ??
                _getCategoryFromName(item['waste_category'] ?? '');
            typeCount[wasteType] = (typeCount[wasteType] ?? 0) + 1;
          } catch (e) {
            appLog('⚠️ [RiwayatPengambilan] Error processing waste item: $e');
          }
        }
      }

      final address =
          serviceAccount?['address'] ??
          serviceAccount?['alamat'] ??
          widget.accountName;

      // Get photo URL - check multiple possible field names & format robustly
      String? rawPhoto =
          pickup['photo_url'] as String? ??
          pickup['pickup_photo'] as String? ??
          pickup['image'] as String? ??
          pickup['photo'] as String? ??
          pickup['photo_path'] as String? ??
          pickup['image_path'] as String?;

      String? photoUrl = ApiConfig.formatImageUrl(rawPhoto);

      final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

      if (hasPhoto) {
        appLog('📷 [Card] Photo URL for pickup: $photoUrl');
      }

      return GestureDetector(
        onTap: () {
          try {
            appLog(
              '👆 [RiwayatPengambilan] Card tapped, showing detail dialog',
            );
            _showDetailDialog(pickup);
          } catch (e, stackTrace) {
            appLog('💥 [RiwayatPengambilan] Error opening detail dialog: $e');
            appLog('Stack trace: $stackTrace');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Gagal membuka detail: ${e.toString()}',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header dengan label tipe pickup dan tanggal
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row pertama: Label tipe dan tanggal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge tipe pickup (Request / Terjadwal)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: typeBgColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOffSchedule ? Icons.flash_on : Icons.schedule,
                                size: 14,
                                color: typeColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                typeLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: typeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tanggal
                        Text(
                          pickupDate != null
                              ? _formatDateShort(pickupDate)
                              : '-',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row kedua: Icon dan judul
                    Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pengambilan Sampah',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Body dengan info ringkas (tanpa foto thumbnail)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Alamat
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Photo thumbnail jika ada
                    if (hasPhoto) ...[
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
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
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Info row (Total Items saja, tanpa berat)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Item',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalItems jenis sampah',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Tombol Konfirmasi (jika status masih pending - belum dikonfirmasi user)
                    if (confirmationStatus == 'pending') ...[
                      // Hitung hari sejak pickup untuk menampilkan countdown
                      Builder(
                        builder: (context) {
                          int? daysRemaining;
                          bool isAutoConfirming = false;

                          if (pickupDate != null) {
                            try {
                              final pickupDateTime = DateTime.parse(pickupDate);
                              final now = DateTime.now();
                              final daysPassed = now
                                  .difference(pickupDateTime)
                                  .inDays;
                              daysRemaining = 3 - daysPassed;

                              // Jika sudah >= 3 hari, akan auto-konfirmasi
                              if (daysPassed >= 3) {
                                isAutoConfirming = true;
                              }
                            } catch (e) {
                              appLog('⚠️ Error calculating days remaining: $e');
                            }
                          }

                          // Tentukan warna berdasarkan status
                          final Color backgroundColor;
                          final Color borderColor;
                          final Color textColor;
                          final IconData iconData;

                          if (isAutoConfirming) {
                            // Hijau: Akan auto-konfirmasi (sudah >= 3 hari)
                            backgroundColor = Colors.green.shade50;
                            borderColor = Colors.green.shade200;
                            textColor = Colors.green.shade700;
                            iconData = Icons.timer_outlined;
                          } else if (daysRemaining != null &&
                              daysRemaining == 1) {
                            // Merah: Warning kuat, besok auto-konfirmasi
                            backgroundColor = Colors.red.shade50;
                            borderColor = Colors.red.shade200;
                            textColor = Colors.red.shade700;
                            iconData = Icons.warning_amber_outlined;
                          } else {
                            // Orange: Masih ada waktu (2+ hari)
                            backgroundColor = Colors.orange.shade50;
                            borderColor = Colors.orange.shade200;
                            textColor = Colors.orange.shade700;
                            iconData = Icons.info_outline;
                          }

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(iconData, size: 20, color: textColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isAutoConfirming
                                            ? 'Batas waktu konfirmasi telah terlewati. Akan dikonfirmasi otomatis.'
                                            : 'Kolektor telah menginput sampah. Konfirmasi apakah sudah diambil.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (daysRemaining != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAutoConfirming
                                          ? Colors.green.shade100
                                          : daysRemaining == 1
                                          ? Colors.red.shade100
                                          : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isAutoConfirming
                                              ? Icons.check_circle_outline
                                              : Icons.access_time,
                                          size: 14,
                                          color: textColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isAutoConfirming
                                              ? 'Sedang diproses otomatis...'
                                              : daysRemaining == 1
                                              ? 'Auto-konfirmasi besok!'
                                              : 'Auto-konfirmasi dalam $daysRemaining hari',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showConfirmationDialog(pickupId!, pickup),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 20,
                          ),
                          label: Text(
                            'Konfirmasi Pengambilan',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Status badge jika sudah dikonfirmasi
                    if (confirmationStatus == 'confirmed') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF4CAF50),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sudah Dikonfirmasi - Tagihan telah dibuat',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4CAF50),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Status badge jika tidak ada sampah
                    if (confirmationStatus == 'no_waste') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              size: 16,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tidak Ada Sampah - Tidak ada tagihan',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Total Harga & Lihat Detail
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Harga',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Rp. ${_formatCurrency(totalPrice)}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4CAF50),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF009688),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Detail',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e, stackTrace) {
      appLog('💥 [RiwayatPengambilan] Error building pickup card: $e');
      appLog('Stack trace: $stackTrace');
      return const SizedBox.shrink();
    }
  }

  /// Tampilkan dialog konfirmasi pengambilan
  void _showConfirmationDialog(String pickupId, Map<String, dynamic> pickup) {
    // Ekstrak data untuk pelaporan
    final serviceAccount = pickup['service_account'] as Map<String, dynamic>?;

    // Debug: Print struktur data service account
    appLog('🔍 [DEBUG] Service Account Data: $serviceAccount');
    appLog('🔍 [DEBUG] Service Account Keys: ${serviceAccount?.keys.toList()}');
    appLog('🔍 [DEBUG] Widget Account Address: ${widget.accountAddress}');

    // Cari address - prioritaskan dari widget.accountAddress (yang dikirim dari home screen)
    String address = widget.accountAddress ?? 'Alamat tidak tersedia';

    // Jika tidak ada di widget, coba ambil dari service account API
    if (address == 'Alamat tidak tersedia' && serviceAccount != null) {
      // Coba berbagai kemungkinan field untuk address
      address =
          serviceAccount['address']?.toString() ??
          serviceAccount['alamat']?.toString() ??
          serviceAccount['alamat_lengkap']?.toString() ??
          serviceAccount['full_address']?.toString() ??
          serviceAccount['location']?.toString() ??
          widget.accountAddress ??
          'Alamat tidak tersedia';
    }

    appLog('🔍 [DEBUG] Final Address yang digunakan: $address');

    final serviceAccountId =
        serviceAccount?['id']?.toString() ?? widget.serviceAccountId;
    final serviceAccountName =
        serviceAccount?['account_name']?.toString() ??
        serviceAccount?['name']?.toString() ??
        serviceAccount?['nama']?.toString() ??
        widget.accountName;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Konfirmasi Pengambilan',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
              'Apakah sampah sudah diambil oleh petugas kolektor?',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Setelah dikonfirmasi, tagihan akan dibuat dan muncul di menu pembayaran',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Tutup dialog konfirmasi
              Navigator.pop(ctx);

              // Navigate to pelaporan screen
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BuatLaporanScreen(
                    imageFile: null,
                    isAsset: false,
                    initialType: 'sampah_tidak_diangkut',
                    initialLocation: address,
                    initialServiceAccountId: serviceAccountId,
                    initialServiceAccountName: serviceAccountName,
                    fromRiwayatPengambilan:
                        true, // ✅ Aktifkan kategori "Sampah Tidak Diangkut"
                  ),
                ),
              );
            },
            child: Text(
              'Sampah belum diambil',
              style: GoogleFonts.poppins(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // ✅ Pass informasi is_off_schedule ke _confirmPickup
              final isOffSchedule = pickup['is_off_schedule'] == true;
              _confirmPickup(pickupId, isOffSchedule: isOffSchedule);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              'Ya, Sudah Diambil',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Konfirmasi pickup ke API
  /// - Regular pickup: POST /resident/waste-deliveries/{id}/confirm
  /// - Off-schedule pickup: PUT /mobile/resident/off-schedule-pickups/{id}/confirm
  Future<void> _confirmPickup(
    String pickupId, {
    bool isOffSchedule = false,
  }) async {
    appLog(
      '🔄 [Confirm] Starting confirmation for pickup #$pickupId (isOffSchedule: $isOffSchedule)',
    );

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text(
                'Memproses konfirmasi...',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      bool success = false;
      String message = '';
      Map<String, dynamic>? data;

      if (isOffSchedule) {
        // ✅ Gunakan API off-schedule: PUT /mobile/resident/off-schedule-pickups/{id}/confirm
        appLog('📡 [Confirm] Using Off-Schedule API for pickup #$pickupId');
        try {
          final pickupIdInt = int.tryParse(pickupId);
          if (pickupIdInt == null) {
            throw Exception('Invalid pickup ID');
          }

          final confirmedPickup = await _offScheduleService.confirmPickup(
            pickupIdInt,
          );
          success = true;
          message = 'Terima kasih! Pengambilan sampah telah dikonfirmasi.';
          data = {
            'id': confirmedPickup.id,
            'status': confirmedPickup.status,
            'confirmed_at': DateTime.now().toIso8601String(),
          };
          appLog('✅ [Confirm] Off-schedule confirmation successful');
        } catch (e) {
          appLog('❌ [Confirm] Off-schedule confirmation failed: $e');
          success = false;
          message = e.toString().replaceAll('Exception: ', '');
        }
      } else {
        // ✅ Gunakan API regular: POST /resident/waste-deliveries/{id}/confirm
        appLog('📡 [Confirm] Using Waste Delivery API for pickup #$pickupId');
        final result = await _pickupService.confirmWasteDelivery(pickupId);
        success = result.$1;
        message = result.$2;
        data = result.$3;
      }

      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      if (success) {
        // Show success dialog
        if (mounted) {
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
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green.shade600,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Terima Kasih!',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (data != null && data['confirmed_at'] != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tagihan akan muncul di Riwayat Pembayaran',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'OK',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Reload data
        await _loadHistory();
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Format tanggal pendek (contoh: Selasa, 27 Mei 2025 13:58)
  String _formatDateShort(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';

    try {
      final date = DateTime.parse(dateStr);
      final dayName = DateFormat('EEEE', 'id_ID').format(date);
      final dateFormatted = DateFormat('d MMM yyyy', 'id_ID').format(date);
      return '$dayName, $dateFormatted';
    } catch (e) {
      return dateStr;
    }
  }

  /// Format currency
  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';

    final number = amount is String ? double.tryParse(amount) ?? 0 : amount;
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(number);
  }

  /// Get category from waste name (fallback jika tidak ada waste_type dari API)
  String _getCategoryFromName(String wasteName) {
    final lowerName = wasteName.toLowerCase();

    // Organik keywords
    if (lowerName.contains('dapur') ||
        lowerName.contains('sisa') ||
        lowerName.contains('makanan') ||
        lowerName.contains('organik')) {
      return 'Organik';
    }

    // B3 keywords
    if (lowerName.contains('baterai') ||
        lowerName.contains('elektronik') ||
        lowerName.contains('lampu') ||
        lowerName.contains('b3')) {
      return 'B3';
    }

    // Default: Anorganik (kertas, plastik, kaleng, dll)
    return 'Anorganik';
  }

  /// Get category color based on waste type
  /// Show detail dialog - Design sesuai gambar
  void _showDetailDialog(Map<String, dynamic> pickup) {
    final pickupDate =
        pickup['pickup_date'] ?? pickup['requested_pickup_date'] as String?;
    final wasteItems = pickup['waste_items'] as List<dynamic>?;
    final accountId = pickup['id']?.toString() ?? '-';

    // Deteksi tipe pickup: data sudah ditandai saat load
    final isOffSchedule = pickup['is_off_schedule'] == true;
    final typeLabel = isOffSchedule ? 'Request' : 'Terjadwal';
    final typeColor = isOffSchedule ? Colors.orange : const Color(0xFF009688);

    // Get photo URL - check multiple possible field names & format robustly
    String? rawPhoto =
        pickup['photo_url'] as String? ??
        pickup['pickup_photo'] as String? ??
        pickup['image'] as String? ??
        pickup['photo'] as String? ??
        pickup['photo_path'] as String? ??
        pickup['image_path'] as String?;

    String? photoUrl = ApiConfig.formatImageUrl(rawPhoto);

    appLog('📷 [DetailDialog] Original pickup data: $pickup');
    appLog('📷 [DetailDialog] Final Photo URL: $photoUrl');

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dengan checkmark, title dan badge tipe
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pengambilan Sampah',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // Badge tipe pickup
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: typeColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOffSchedule
                                      ? Icons.flash_on
                                      : Icons.schedule,
                                  size: 12,
                                  color: typeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  typeLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: typeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Foto Bukti Pengambilan (jika ada)
                      if (photoUrl != null && photoUrl.isNotEmpty) ...[
                        Text(
                          'Foto Bukti Pengambilan',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final imageUrl = photoUrl;
                            appLog(
                              '🖼️ [DetailDialog] Loading image from: $imageUrl',
                            );
                            return AspectRatio(
                              aspectRatio: 4 / 3,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => Scaffold(
                                            backgroundColor: Colors.black,
                                            appBar: AppBar(
                                              backgroundColor: Colors.black,
                                              foregroundColor: Colors.white,
                                              title: Text(
                                                'Foto Bukti Pengambilan',
                                                style: GoogleFonts.poppins(),
                                              ),
                                            ),
                                            body: Center(
                                              child: InteractiveViewer(
                                                child: Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Center(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          const Icon(
                                                            Icons.broken_image,
                                                            size: 64,
                                                            color:
                                                                Colors.white54,
                                                          ),
                                                          const SizedBox(
                                                            height: 16,
                                                          ),
                                                          Text(
                                                            'Foto tidak dapat dimuat',
                                                            style:
                                                                GoogleFonts.poppins(
                                                                  color: Colors
                                                                      .white70,
                                                                  fontSize: 14,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress ==
                                                        null) {
                                                      return child;
                                                    }
                                                    return Center(
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
                                                        color: Colors.white,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Image.network(
                                          imageUrl,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            appLog(
                                              '❌ [DetailDialog] Error loading image from: $imageUrl',
                                            );
                                            appLog(
                                              '❌ [DetailDialog] Error: $error',
                                            );
                                            appLog(
                                              '❌ [DetailDialog] StackTrace: $stackTrace',
                                            );
                                            return Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.broken_image,
                                                    size: 48,
                                                    color: Colors.grey[400],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Foto tidak tersedia',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                        ),
                                                    child: Text(
                                                      'File mungkin sudah dihapus dari server',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            color: Colors
                                                                .grey[500],
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return Center(
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
                                              ),
                                            );
                                          },
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.6,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.zoom_in,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Tap untuk perbesar',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                      ] else ...[
                        // Pesan jika foto tidak tersedia
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Foto bukti pengambilan tidak tersedia',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],

                      // ID Pickup
                      Text(
                        '#$accountId',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Waktu Pengambilan
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Waktu Pengambilan',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pickupDate != null
                            ? _formatDateWithTime(pickupDate)
                            : '-',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Sampah Header
                      Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sampah',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Detail Sampah List
                      if (wasteItems != null && wasteItems.isNotEmpty)
                        ...wasteItems.map((item) {
                          // Get waste category (organic, anorganik, dll)
                          final wasteCategory =
                              item['waste_category'] ??
                              item['waste']?['category'] ??
                              item['waste_name'] ??
                              '-';

                          // Get pocket size (Besar, Sedang, Kecil)
                          final pocketSize =
                              item['pocket_size'] ??
                              item['size'] ??
                              item['waste_size'] ??
                              '';

                          // Combine category with size if available
                          final displayName = pocketSize.isNotEmpty
                              ? '$wasteCategory $pocketSize'
                              : wasteCategory;

                          final quantity = item['quantity'] ?? 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${quantity}x',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                      // Untuk off-schedule pickup yang tidak punya waste_items
                      if (isOffSchedule &&
                          (wasteItems == null || wasteItems.isEmpty))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Pengambilan Request',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${pickup['bag_count'] ?? 1} kantong',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Total (Jumlah) - Sum of all quantities
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Jumlah',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            isOffSchedule &&
                                    (wasteItems == null || wasteItems.isEmpty)
                                ? '${pickup['bag_count'] ?? 1} kantong'
                                : '${wasteItems?.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0)) ?? 0}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Tombol Konfirmasi atau Tutup (tergantung status)
                      Builder(
                        builder: (context) {
                          final pickupId = pickup['id']?.toString();
                          final confirmationStatus =
                              pickup['confirmation_status']?.toString() ??
                              'pending';
                          final isPending = confirmationStatus == 'pending';

                          if (isPending && pickupId != null) {
                            // Jika status pending, tampilkan tombol konfirmasi
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showConfirmationDialog(pickupId, pickup);
                                },
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 20,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                label: Text(
                                  'Konfirmasi Pengambilan',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            // Jika sudah dikonfirmasi, tampilkan tombol tutup
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF009688),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Tutup',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Format tanggal dengan waktu (contoh: Selasa, 27 Mei 2025 13:58)
  String _formatDateWithTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';

    try {
      final date = DateTime.parse(dateStr);
      final dayName = DateFormat('EEEE', 'id_ID').format(date);
      final dateFormatted = DateFormat(
        'd MMMM yyyy HH:mm',
        'id_ID',
      ).format(date);
      return '$dayName, $dateFormatted';
    } catch (e) {
      return dateStr;
    }
  }
}
