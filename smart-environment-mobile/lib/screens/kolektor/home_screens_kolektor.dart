import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import 'pengambilan_sampah_screen.dart';
import 'ambil_foto_screen.dart';
import 'collector_complaint_detail_screen.dart';
import 'tps_map_screen.dart';
import '../../services/pickup_service.dart';
import '../../services/kolektor_notification_service.dart';
import '../../services/user_storage.dart';
import '../../services/tps_deposit_service.dart';
import '../../services/notification_api_service.dart';
import '../../models/tps.dart';
import '../../models/tps_deposit.dart';
import 'profile_screen.dart';
import 'riwayat_sampah_screen.dart';
import '../user/notification_screen.dart';
import '../../services/collector_complaint_service.dart';
import '../../models/complaint.dart';
import '../../services/off_schedule_pickup_service.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';

class HomeScreensKolektor extends StatefulWidget {
  const HomeScreensKolektor({super.key});

  @override
  State<HomeScreensKolektor> createState() => _HomeScreensKolektorState();
}

class _HomeScreensKolektorState extends State<HomeScreensKolektor>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> pengambilanList = [];
  List<Map<String, dynamic>> todayPickups = [];
  List<Map<String, dynamic>> pengangkutanList = []; // Riwayat pengangkutan
  String _userName = 'Kolektor';
  String _profileImagePath = ''; // Tambahkan untuk menyimpan path foto profile
  bool _isLoadingPickups = false;
  bool _isLoadingHistory = false;

  // ✅ COMPLAINT STATE
  List<Complaint> assignedComplaints =
      []; // Hanya complaint aktif (untuk task list)
  List<Complaint> allComplaints =
      []; // Semua complaint termasuk resolved (untuk history)
  bool _isLoadingComplaints = false;
  String? _errorMessage;
  int _unreadNotifCount = 0;

  // ✅ OFF-SCHEDULE PICKUP STATE
  List<Map<String, dynamic>> offSchedulePickups =
      []; // Active pickups untuk tugas
  List<Map<String, dynamic>> allOffSchedulePickups =
      []; // Semua pickups termasuk completed untuk history
  bool _hasShownWelcomeMessage = false;
  int _selectedIndex = 0;
  int _riwayatTabIndex = 0; // 0 = Pengambilan, 1 = Pengangkutan
  int _tugasTabIndex = 0; // 0 = Pengambilan, 1 = Pelaporan

  // ✅ TPS DEPOSITS STATE
  List<TPS> _tpsList = [];
  List<TPSDeposit> _depositHistory = [];
  bool _isLoadingTPS = false;
  bool _isLoadingDeposits = false;

  // ✅ TAMBAHAN: Simpan semua RW yang ditugaskan ke kolektor (bisa lebih dari 1)
  List<String> _kolektorRWList = [];
  @override
  void initState() {
    super.initState();
    appLog(' [HomeCollector] Screen initialized');

    // Add lifecycle observer untuk detect app resume
    WidgetsBinding.instance.addObserver(this);

    _initializeData();
  }

  @override
  void dispose() {
    appLog(' [HomeCollector] Screen disposed');
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appLog('[HomeCollector] App lifecycle changed: $state');

    if (state == AppLifecycleState.resumed) {
      // App kembali ke foreground - refresh data
      appLog('✨ [HomeCollector] App resumed, refreshing pickups...');

      // ✅ FIX: Gunakan async function untuk memastikan urutan yang benar
      _refreshDataOnResume();
    } else if (state == AppLifecycleState.paused) {
      appLog('[HomeCollector] App paused');
    } else if (state == AppLifecycleState.inactive) {
      appLog('[HomeCollector] App inactive');
    }
  }

  /// ✅ METHOD BARU: Refresh data saat app resume dengan urutan yang benar
  Future<void> _refreshDataOnResume() async {
    // Load semua data secara paralel terlebih dahulu
    await Future.wait([
      _loadTodayPickups(forceRefresh: true),
      _loadAssignedComplaints(),
      _loadOffSchedulePickups(),
      _loadPengambilanDataOnly(),
      _loadTPSList(), // ✅ TAMBAHAN: Refresh TPS list
      _loadDepositHistory(), // ✅ TAMBAHAN: Refresh deposit history
    ]);

    // ✅ FIX: Panggil _addCompletedTasksToHistory SETELAH semua data selesai dimuat
    _addCompletedTasksToHistory();
  }

  /// Initialize semua data dan trigger notifikasi otomatis
  Future<void> _initializeData() async {
    appLog('[HomeCollector] ===== INITIALIZING DATA =====');
    await _loadUserData();

    // ✅ OPTIMASI: Load data secara parallel untuk mengurangi waktu loading
    // PENTING: _loadPengambilanData diganti dengan _loadPengambilanDataOnly
    // karena _addCompletedTasksToHistory harus dipanggil SETELAH offSchedulePickups terisi
    appLog('[HomeCollector] Loading all data in parallel...');
    await Future.wait([
      _loadTodayPickups(),
      _loadAssignedComplaints(),
      _loadPengambilanDataOnly(), // ✅ GANTI: Tidak memanggil _addCompletedTasksToHistory
      _loadOffSchedulePickups(),
      _loadTPSList(), // ✅ TAMBAHAN: Load TPS list
      _loadDepositHistory(), // ✅ TAMBAHAN: Load deposit history
    ]);

    appLog(
      '[HomeCollector] All data loaded. offSchedulePickups count: ${offSchedulePickups.length}',
    );

    // ✅ FIX: Panggil _addCompletedTasksToHistory SETELAH semua data selesai dimuat
    _addCompletedTasksToHistory();

    // Trigger notifikasi otomatis setelah data dimuat
    await _checkAndTriggerNotifications();

    // Load unread notification count
    await _loadUnreadNotifCount();
    appLog('[HomeCollector] ===== INITIALIZATION COMPLETE =====');
  }

  /// Load user data dari UserStorage
  Future<void> _loadUserData() async {
    final name = await UserStorage.getUserName();
    final prefs = await SharedPreferences.getInstance();

    // ✅ PERBAIKAN: Load RW kolektor dari UserStorage
    final kolektorRW = await UserStorage.getKolektorRW();

    appLog('[HomeCollector] Loading user data...');
    appLog('   - Name: $name');
    appLog('   - Kolektor RW: $kolektorRW');

    // Fallback: Jika tidak ada di UserStorage, coba dari SharedPreferences langsung
    if (kolektorRW == null) {
      final userData = prefs.getString('user_data');
      if (userData != null) {
        try {
          final data = jsonDecode(userData) as Map<String, dynamic>;
          final rwFromPrefs =
              data['rw']?.toString() ?? data['assigned_rw']?.toString();
          appLog('   - RW from prefs fallback: $rwFromPrefs');

          if (mounted) {
            setState(() {
              _userName = name ?? 'Kolektor';
              _profileImagePath = prefs.getString('profile_image_path') ?? '';
              _kolektorRWList = rwFromPrefs != null ? [rwFromPrefs] : [];
            });
          }
          return;
        } catch (e) {
          appLog('[HomeCollector] Error parsing user_data: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _userName = name ?? 'Kolektor';
        _profileImagePath = prefs.getString('profile_image_path') ?? '';
        _kolektorRWList = kolektorRW != null ? [kolektorRW] : [];
      });
    }

    if (_kolektorRWList.isEmpty) {
      appLog('[HomeCollector] WARNING: Kolektor RW list is EMPTY!');
      appLog(
        '   This means filtering will NOT work until RW is detected from pickups!',
      );
    } else {
      appLog(
        '[HomeCollector] Kolektor RW loaded successfully: ${_kolektorRWList.join(", ")}',
      );
    }
  }

  /// Check dan trigger notifikasi otomatis
  Future<void> _checkAndTriggerNotifications() async {
    try {
      await KolektorNotificationService.checkAndTriggerNotifications(
        todayPickups: todayPickups,
        recentHistory: pengambilanList,
      );

      // Send daily reminder jika perlu (pagi hari)
      await KolektorNotificationService.sendDailyReminders(todayPickups);

      // Refresh unread count setelah check notifikasi
      await _loadUnreadNotifCount();
    } catch (e) {
      appLog('Error checking notifications: $e');
    }
  }

  /// Load unread notification count untuk badge dari API
  Future<void> _loadUnreadNotifCount() async {
    try {
      final count = await NotificationApiService.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadNotifCount = count;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _unreadNotifCount = 0;
        });
      }
    }
  }

  /// ✅ METHOD BARU: Load Assigned Complaints
  Future<void> _loadAssignedComplaints() async {
    if (!mounted) return;

    appLog('[HomeCollector] Loading assigned complaints...');

    setState(() {
      _isLoadingComplaints = true;
    });

    try {
      appLog('[Complaints] ===== LOADING ASSIGNED COMPLAINTS =====');
      appLog('[Complaints] API URL: /mobile/collector/complaints');

      final service = CollectorComplaintService();

      // Load semua complaint yang assigned ke kolektor ini
      final complaints = await service.getAssignedComplaints();

      appLog('[Complaints] Received ${complaints.length} complaints from API');

      // Debug: print setiap complaint
      if (complaints.isNotEmpty) {
        for (var complaint in complaints) {
          appLog(
            '   - Complaint #${complaint.id}: ${complaint.type}, Status: ${complaint.status}',
          );
        }
      } else {
        appLog('[Complaints] API returned EMPTY list!');
      }

      // ✅ Simpan SEMUA complaints (termasuk resolved) untuk history
      final allComplaintsData = complaints;

      // Filter hanya complaint yang belum selesai untuk task list
      final activeComplaints = complaints
          .where(
            (c) =>
                c.status == 'pending' ||
                c.status == 'assigned' ||
                c.status == 'in_progress' ||
                c.status == 'open',
          )
          .toList();

      final resolvedCount = complaints
          .where((c) => c.status == 'resolved')
          .length;

      appLog(
        '[Complaints] Active: ${activeComplaints.length}, Resolved: $resolvedCount, Total: ${complaints.length}',
      );
      appLog('═══════════════════════════════════════════════════════');

      if (mounted) {
        setState(() {
          assignedComplaints = activeComplaints; // Untuk task list
          allComplaints = allComplaintsData; // Untuk history
          _isLoadingComplaints = false;
        });
      }
    } on SocketException catch (e) {
      // Network error - retry after delay
      appLog('[Complaints] Network error: ${e.message}');
      appLog('   Will retry in 3 seconds...');

      if (mounted) {
        setState(() {
          assignedComplaints = [];
          _isLoadingComplaints = false;
        });

        // Retry setelah 3 detik
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          appLog('🔄 [Complaints] Retrying to load complaints...');
          _loadAssignedComplaints();
        }
      }
    } catch (e) {
      appLog('[Complaints] Error loading: $e');
      appLog('   Stack trace: ${StackTrace.current}');

      if (mounted) {
        setState(() {
          assignedComplaints = [];
          _isLoadingComplaints = false;
        });
      }
    }
  }

  Future<void> _loadTodayPickups({bool forceRefresh = false}) async {
    if (forceRefresh) {
      appLog('[HomeCollector] Force refresh requested');
    }

    setState(() {
      _isLoadingPickups = true;
      _errorMessage = null;
    });

    // ✅ Ambil user_id collector yang sedang login untuk filtering
    final prefs = await SharedPreferences.getInstance();
    final userIdRaw = prefs.get('user_id');
    final currentCollectorId = userIdRaw?.toString();
    appLog('[HomeCollector] Current collector ID: $currentCollectorId');

    final (success, message, data) = await PickupService.getTodayPickups();

    if (mounted) {
      setState(() {
        _isLoadingPickups = false;
        if (success && data != null) {
          appLog('[HomeCollector] Received ${data.length} pickups from API');

          // Debug: Print first pickup to see structure
          if (data.isNotEmpty) {
            appLog('[DEBUG] First pickup structure:');
            appLog(jsonEncode(data.first));
          }

          // ✅ PERBAIKAN KRITIS: HANYA detect RW dari pickup yang ASSIGNED ke collector ini
          // Filter by collector_id untuk memastikan hanya RW yang ditugaskan yang muncul
          if (data.isNotEmpty && currentCollectorId != null) {
            Set<String> detectedRWs = {};
            int assignedPickupCount = 0;
            int otherCollectorCount = 0;

            appLog(
              '[AutoDetect] Scanning ${data.length} pickups untuk detect RW yang ASSIGNED ke collector #$currentCollectorId...',
            );

            for (var pickup in data) {
              // ✅ KUNCI: Hanya proses pickup yang assigned ke collector ini
              final pickupCollectorId = pickup['collector_id']?.toString();

              if (pickupCollectorId == currentCollectorId) {
                assignedPickupCount++;
                String? rwFromPickup;

                // Cek di house_info
                final houseInfo = pickup['house_info'] as Map<String, dynamic>?;
                if (houseInfo != null) {
                  rwFromPickup = houseInfo['rw']?.toString();
                }

                // Cek di service_account jika belum ketemu
                if (rwFromPickup == null) {
                  final serviceAccount =
                      pickup['service_account'] as Map<String, dynamic>?;
                  if (serviceAccount != null) {
                    rwFromPickup = serviceAccount['rw']?.toString();
                  }
                }

                // Cek langsung di pickup object jika belum ketemu
                rwFromPickup ??= pickup['rw']?.toString();

                if (rwFromPickup != null && rwFromPickup.isNotEmpty) {
                  detectedRWs.add(rwFromPickup.trim().toUpperCase());
                  appLog(
                    '   ✅ Pickup #${pickup['id']}: RW $rwFromPickup (Assigned to me)',
                  );
                }
              } else {
                otherCollectorCount++;
                appLog(
                  'Pickup #${pickup['id']}: Assigned to collector #$pickupCollectorId (Skip)',
                );
              }
            }

            appLog('[AutoDetect] Scan result:');
            appLog('   - Total pickups scanned: ${data.length}');
            appLog('   - Assigned to me: $assignedPickupCount');
            appLog('   - Assigned to others: $otherCollectorCount');

            if (detectedRWs.isNotEmpty) {
              // Merge dengan RW yang sudah ada dari UserStorage (jika ada)
              final existingRWs = _kolektorRWList
                  .map((rw) => rw.trim().toUpperCase())
                  .toSet();
              detectedRWs.addAll(existingRWs);

              _kolektorRWList = detectedRWs.toList()..sort();
              appLog(
                '[AutoDetect] Total ${_kolektorRWList.length} RW terdeteksi untuk collector ini: ${_kolektorRWList.join(", ")}',
              );
            } else {
              appLog(
                '[AutoDetect] TIDAK ADA RW terdeteksi dari $assignedPickupCount pickups yang assigned!',
              );
            }
          } else if (currentCollectorId == null) {
            appLog('[AutoDetect] GAGAL: Collector ID tidak ditemukan!');
          }

          // ✅ PERBAIKAN: Filter pickup berdasarkan SEMUA RW yang ditugaskan
          List<Map<String, dynamic>> filteredPickups = data;

          appLog('[Filter] ===== FILTERING PICKUPS =====');
          appLog(
            '[Filter] Kolektor assigned to ${_kolektorRWList.length} RW(s): ${_kolektorRWList.join(", ")}',
          );
          appLog('[Filter] Total pickups to filter: ${data.length}');

          if (_kolektorRWList.isNotEmpty) {
            int filteredCount = 0;
            filteredPickups = data.where((pickup) {
              // Cek di berbagai kemungkinan lokasi data RW
              String? pickupRW;
              String? displayName;

              // Kemungkinan 1: RW ada di house_info
              final houseInfo = pickup['house_info'] as Map<String, dynamic>?;
              if (houseInfo != null) {
                pickupRW = houseInfo['rw']?.toString();
                displayName =
                    houseInfo['resident_name']?.toString() ??
                    houseInfo['account_number']?.toString();
              }

              // Kemungkinan 2: RW ada di service_account
              if (pickupRW == null) {
                final serviceAccount =
                    pickup['service_account'] as Map<String, dynamic>?;
                if (serviceAccount != null) {
                  pickupRW = serviceAccount['rw']?.toString();
                  displayName ??= serviceAccount['name']?.toString();
                }
              }

              // Kemungkinan 3: RW ada langsung di pickup object
              pickupRW ??= pickup['rw']?.toString();

              // Ambil name dari pickup jika belum ada
              displayName ??= pickup['name']?.toString() ?? 'N/A';

              // Filter: cek apakah pickup RW ada di list RW kolektor (case-insensitive)
              final isMatch =
                  pickupRW != null &&
                  _kolektorRWList.any(
                    (kolektorRW) =>
                        pickupRW!.trim().toUpperCase() ==
                        kolektorRW.trim().toUpperCase(),
                  );

              // Log setiap pickup untuk debugging
              appLog(
                '   ${isMatch ? "✅" : "❌"} Pickup #${pickup['id']}: $displayName (RW ${pickupRW ?? "?"}) - ${pickup['status'] ?? "?"}, Date: ${pickup['pickup_date'] ?? "?"}',
              );

              if (!isMatch) {
                filteredCount++;
              }
              return isMatch;
            }).toList();

            appLog('[Filter] HASIL:');
            appLog('   - Original pickups: ${data.length}');
            appLog('   - Filtered out: $filteredCount');
            appLog(
              '   - Remaining (matched): ${filteredPickups.length} pickups',
            );
            appLog('   - RW matched: ${_kolektorRWList.join(", ")}');
            appLog('═══════════════════════════════════════════════════════');
          } else {
            appLog('[Filter] WARNING: Kolektor RW list is EMPTY!');
            appLog(
              '[Filter] Showing ALL ${data.length} pickups (NO FILTERING)',
            );
            appLog('[Filter] This should NOT happen if collector is assigned!');
            appLog('═══════════════════════════════════════════════════════');
          }

          todayPickups = filteredPickups;
          appLog(
            '[OK] [HomeCollector] Loaded ${filteredPickups.length} pickups for RW ${_kolektorRWList.join(", ")}',
          );

          // Debug: Print data structure untuk melihat apa yang diterima dari API
          if (filteredPickups.isNotEmpty) {
            appLog(
              '[DATA] [HomeKolektor] Sample filtered pickup data: ${filteredPickups.first}',
            );
            if (filteredPickups.first['service_account'] != null) {
              appLog(
                '[OK] [HomeKolektor] Service account data: ${filteredPickups.first['service_account']}',
              );
            } else {
              appLog('[WARN] [HomeKolektor] No service_account in pickup data');
            }
            if (filteredPickups.first['house_info'] != null) {
              appLog(
                '[HOME] [HomeKolektor] House info data: ${filteredPickups.first['house_info']}',
              );
            }
          }
        } else {
          appLog('[ERROR] [HomeCollector] Failed to load pickups: $message');
          _errorMessage = message;
          todayPickups = [];
        }
      });

      // Trigger notifikasi setelah data pickup dimuat (gunakan data yang sudah difilter)
      if (success && todayPickups.isNotEmpty) {
        await _checkAndTriggerNotifications();
      }
    }
  }

  Future<void> _loadPengambilanData() async {
    setState(() {
      _isLoadingHistory = true;
    });

    final (success, message, data) =
        await PickupService.getPickupHistoryFromAPI();
    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        if (success && data != null) {
          pengambilanList = data;
        } else {
          pengambilanList = [];
        }
      });

      // ✅ Tambahkan off-schedule dan complaint yang sudah selesai ke riwayat
      _addCompletedTasksToHistory();

      // Trigger notifikasi setelah data history dimuat
      if (success && data != null && data.isNotEmpty) {
        await _checkAndTriggerNotifications();
      }
    }
  }

  /// ✅ METHOD BARU: Load pengambilan data TANPA memanggil _addCompletedTasksToHistory
  /// Digunakan oleh _initializeData agar _addCompletedTasksToHistory dipanggil
  /// SETELAH semua data (termasuk offSchedulePickups) selesai dimuat
  Future<void> _loadPengambilanDataOnly() async {
    setState(() {
      _isLoadingHistory = true;
    });

    final (success, message, data) =
        await PickupService.getPickupHistoryFromAPI();
    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        if (success && data != null) {
          pengambilanList = data;
        } else {
          pengambilanList = [];
        }
      });

      // CATATAN: _addCompletedTasksToHistory TIDAK dipanggil di sini
      // Akan dipanggil oleh _initializeData setelah semua data dimuat

      // Trigger notifikasi setelah data history dimuat
      if (success && data != null && data.isNotEmpty) {
        await _checkAndTriggerNotifications();
      }
    }
  }

  /// ✅ METHOD BARU: Tambahkan off-schedule dan complaint yang selesai ke riwayat
  void _addCompletedTasksToHistory() {
    appLog('[HomeCollector] ===== ADDING COMPLETED TASKS TO HISTORY =====');

    // ✅ PERBAIKAN: Hanya tampilkan pickup yang selesai HARI INI
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    appLog('[HomeCollector] Today date filter: $todayStr');

    // ✅ Gunakan allOffSchedulePickups untuk mencari completed pickups
    // Status completed: 'completed', 'collected', 'pending', 'paid'
    // Pickup yang sudah selesai: punya photo_url (berarti sudah difoto dan disubmit)
    final completedOffSchedule = allOffSchedulePickups.where((pickup) {
      final requestStatus = pickup['request_status']?.toString() ?? '';
      final status = pickup['status']?.toString() ?? '';
      final photoUrl = pickup['photo_url']?.toString() ?? '';

      // Tampilkan seluruh off-schedule yang selesai dikerjakan kolektor

      // ✅ Pickup dianggap selesai jika:
      // 1. request_status = completed/paid, ATAU
      // 2. status = completed/collected, ATAU
      // 3. Ada photo_url (berarti sudah difoto dan disubmit oleh kolektor)
      final hasPhoto = photoUrl.isNotEmpty && photoUrl != 'null';
      final isCompleted =
          requestStatus == 'completed' ||
          requestStatus == 'paid' ||
          status == 'completed' ||
          status == 'collected';

      return isCompleted || hasPhoto;
    }).toList();

    appLog(
      '[HomeCollector] Found ${completedOffSchedule.length} completed off-schedule pickups from allOffSchedulePickups (${allOffSchedulePickups.length} total)',
    );

    bool hasChanges = false;

    for (var pickup in completedOffSchedule) {
      // Check if already exists in pengambilanList
      final pickupId = pickup['id'];
      final exists = pengambilanList.any(
        (item) =>
            item['id'] == pickupId &&
            (item['pickup_type'] == 'off-schedule' ||
             item['pickup_type'] == 'off_schedule' ||
             item['pickup_type'] == 'request'),
      );

      if (!exists) {
        appLog('Adding off-schedule #$pickupId to history');

        // ✅ Get waste_items from pickup and transform to history format
        final wasteItems = pickup['waste_items'] as List<dynamic>? ?? [];
        appLog('  Raw waste_items count: ${wasteItems.length}');

        if (wasteItems.isNotEmpty) {
          appLog('  Sample waste_item: ${wasteItems.first}');
        }

        final transformedItems = wasteItems.map((item) {
          final wasteItem = item as Map<String, dynamic>;

          // Debug: print all keys in waste item
          appLog('   Waste item keys: ${wasteItem.keys.toList()}');

          // ✅ Use correct field names from API response:
          // waste_name: "Sampah Organik", pocket_size_name: "Besar"
          final wasteName =
              wasteItem['waste_name']?.toString() ??
              wasteItem['waste_category']?.toString() ??
              'Lainnya';
          final pocketSizeName =
              wasteItem['pocket_size_name']?.toString() ??
              wasteItem['size']?.toString() ??
              '';

          // Extract category (e.g., "Organik" from "Sampah Organik")
          String category = wasteName;
          if (wasteName.toLowerCase().startsWith('sampah ')) {
            category = wasteName.substring(7); // Remove "Sampah " prefix
          }

          // ✅ Convert Indonesian naming to English to match regular pickup format
          // "Organik" -> "organic", "Anorganik" -> "inorganic"
          final categoryLower = category.toLowerCase();
          if (categoryLower == 'organik') {
            category = 'organic';
          } else if (categoryLower == 'anorganik') {
            category = 'inorganic';
          } else {
            category = categoryLower; // Keep other categories lowercase
          }

          final quantity = wasteItem['quantity'] as int? ?? 0;
          final unitPrice = wasteItem['unit_price'] as int? ?? 0;
          final totalPrice =
              wasteItem['total_price'] as int? ?? (quantity * unitPrice);

          // Build name: "organic Besar", "organic Sedang", etc. (to match regular pickup)
          final name = pocketSizeName.isNotEmpty
              ? '$category $pocketSizeName'
              : category;

          appLog(
            '   ✅ Transformed: category=$category, pocketSize=$pocketSizeName, name=$name, qty=$quantity',
          );

          return {
            'category': category,
            'name': name,
            'quantity': quantity,
            'price': unitPrice,
            'totalPrice': totalPrice,
          };
        }).toList();

        appLog(
          '   ✅ Transformed ${transformedItems.length} waste items for history',
        );

        // Transform off-schedule pickup to history format
        pengambilanList.insert(0, {
          'id': pickup['id'],
          'pickup_type': 'off-schedule',
          'name': pickup['service_account_name'] ?? 'N/A',
          'address': pickup['address'] ?? 'N/A',
          'idPengambilan': '#${pickup['id']}',
          'totalPrice': pickup['total_amount'] ?? 0,
          'date':
              pickup['requested_pickup_date'] ?? pickup['requested_date'] ?? '',
          'image':
              pickup['photo_url'] ??
              pickup['photo'] ??
              'assets/images/dummy.jpg',
          'items': transformedItems, // ✅ Use actual waste items from API
          'status': pickup['status'],
        });
        hasChanges = true;
      }
    }

    // Tambahkan resolved complaints ke riwayat
    final resolvedComplaints = allComplaints.where((complaint) {
      return complaint.status == 'resolved';
    }).toList();

    appLog(
      '[HomeCollector] Found ${resolvedComplaints.length} resolved complaints TODAY in allComplaints',
    );
    appLog('[HomeCollector] Total allComplaints: ${allComplaints.length}');

    for (var complaint in resolvedComplaints) {
      // Check if already exists in pengambilanList
      final exists = pengambilanList.any(
        (item) => item['id'] == complaint.id && item['type'] != null,
      );

      if (!exists) {
        appLog('   Adding complaint #${complaint.id} to history');
        appLog('     - Type: ${complaint.type}');
        appLog('     - Status: ${complaint.status}');
        appLog('     - Reporter: ${complaint.reporter?['name'] ?? 'N/A'}');

        // Transform complaint to history format
        // ✅ Prioritas: resolution_photo dari API > foto terakhir > dummy
        String imageUrl = 'assets/images/dummy.jpg';
        if (complaint.resolutionPhoto != null &&
            complaint.resolutionPhoto!.isNotEmpty) {
          imageUrl = complaint.resolutionPhoto!; // Foto resolution dari API
          appLog('     📸 Using resolution_photo: $imageUrl');
        } else if (complaint.photos.isNotEmpty) {
          imageUrl = complaint.photos.last.url; // Fallback ke foto terakhir
          appLog('     📸 Fallback to last photo: $imageUrl');
        } else {
          appLog('     📸 Using dummy image (no photos available)');
        }

        final reporterName = complaint.reporter?['name']?.toString() ?? 'Warga';

        pengambilanList.insert(0, {
          'id': complaint.id,
          'type': complaint.type, // Marker for complaint
          'name': reporterName,
          'address': complaint.location ?? 'N/A',
          'idPengambilan': '#${complaint.id}',
          'totalPrice': 0,
          'date': complaint.createdAt.toString().split(' ')[0],
          'image': imageUrl,
          'items': [],
          'status': complaint.status,
        });
        hasChanges = true;
        appLog('     ✅ Successfully added to pengambilanList');
      } else {
        appLog('  ⏭️ Complaint #${complaint.id} already in history, skipping');
      }
    }

    appLog('✅ [HomeCollector] History now has ${pengambilanList.length} items');
    appLog('═══════════════════════════════════════════════════════');

    // ✅ Update UI jika ada perubahan
    if (hasChanges && mounted) {
      setState(() {
        // pengambilanList sudah diupdate di atas
      });
    }
  }

  /// ✅ METHOD BARU: Load Off-Schedule Pickups untuk kolektor
  Future<void> _loadOffSchedulePickups() async {
    if (!mounted) return;

    try {
      appLog('📋 [HomeCollector] ===== LOADING OFF-SCHEDULE PICKUPS =====');
      final service = OffSchedulePickupService();

      // ✅ Load SEMUA pickups (termasuk completed untuk history)
      final allPickups = await service.getCollectorAllPickups();

      appLog(
        '📦 [HomeCollector] Received ${allPickups.length} ALL off-schedule pickups from API',
      );

      if (!mounted) return;

      // ✅ Transform function untuk pickup
      Map<String, dynamic> transformPickup(pickup) {
        // DEBUG: Log request_status untuk verifikasi
        appLog(
          '🔄 [Transform] Pickup #${pickup.id}: request_status=${pickup.requestStatus}, status=${pickup.status}',
        );

        return {
          'id': pickup.id,
          'pickup_type': 'off-schedule', // Marker untuk membedakan
          'service_account_name': pickup.serviceAccountName,
          'address': pickup.address,
          'requested_pickup_date': pickup.requestedPickupDate,
          'requested_pickup_time': pickup.requestedPickupTime ?? '-',
          'status': pickup.status,
          'request_status': pickup.requestStatus,
          'bag_count': pickup.bagCount,
          'total_amount': pickup.totalAmount,
          'resident_note': pickup.residentNote ?? pickup.note ?? '',
          'photo_url': pickup.photoUrl,
          'waste_items':
              pickup.wasteItems ?? [], // ✅ Include waste items from API
          // ✅ TAMBAHAN: Data untuk navigasi ke detail screen
          'service_account': pickup.serviceAccount != null
              ? {
                  'id': pickup.serviceAccount!.id,
                  'name': pickup.serviceAccount!.name,
                  'contact_phone':
                      pickup.serviceAccount!.contactPhone?.isNotEmpty == true
                      ? pickup.serviceAccount!.contactPhone
                      : null,
                  'address': pickup.serviceAccount!.address,
                  'latitude': pickup.serviceAccount!.latitude,
                  'longitude': pickup.serviceAccount!.longitude,
                }
              : null,
          'house_info': pickup.serviceAccount != null
              ? {
                  'service_account_name': pickup.serviceAccount!.name,
                  'service_account_phone':
                      pickup.serviceAccount!.contactPhone?.isNotEmpty == true
                      ? pickup.serviceAccount!.contactPhone
                      : null,
                  'latitude': pickup.serviceAccount!.latitude ?? 0.0,
                  'longitude': pickup.serviceAccount!.longitude ?? 0.0,
                }
              : null,
        };
      }

      // ✅ Transform semua pickups
      final allTransformed = allPickups.map(transformPickup).toList();

      // ✅ Filter untuk active pickups (untuk daftar tugas)
      // Hanya tampilkan pickup yang tanggal request-nya adalah HARI INI
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final activeTransformed = allPickups
          .where((pickup) {
            final isPendingOrProcessing = pickup.requestStatus == 'processing' ||
                pickup.requestStatus == 'pending' ||
                pickup.requestStatus == 'sent';
            final notCancelled = pickup.status != 'cancelled' &&
                pickup.requestStatus != 'rejected' &&
                pickup.requestStatus != 'completed';

            return isPendingOrProcessing && notCancelled;
          })
          .map(transformPickup)
          .toList();

      setState(() {
        offSchedulePickups = activeTransformed; // Untuk daftar tugas
        allOffSchedulePickups =
            allTransformed; // Untuk history (termasuk completed)
      });

      // ✅ DEBUG: Log transformed data untuk verifikasi
      appLog(
        '📊 [HomeCollector] Active pickups (today only): ${activeTransformed.length}',
      );
      appLog(
        '📊 [HomeCollector] All pickups (for history): ${allTransformed.length}',
      );
      appLog('📅 [HomeCollector] Today: $todayStr');

      if (activeTransformed.isNotEmpty) {
        final sample = activeTransformed.first;
        final serviceAccount =
            sample['service_account'] as Map<String, dynamic>?;
        final houseInfo = sample['house_info'] as Map<String, dynamic>?;
        appLog('   - Sample ID: ${sample['id']}');
        appLog('   - Name: ${sample['service_account_name']}');
        appLog('   - Phone: ${serviceAccount?['contact_phone']}');
        appLog('   - Latitude: ${houseInfo?['latitude']}');
        appLog('   - Longitude: ${houseInfo?['longitude']}');
      }

      appLog('✅ [HomeCollector] Successfully loaded off-schedule pickups');
      appLog('═══════════════════════════════════════════════════════');
    } catch (e, stackTrace) {
      appLog('❌ [HomeCollector] Error loading off-schedule pickups: $e');
      appLog('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          offSchedulePickups = [];
          allOffSchedulePickups = [];
        });
      }
    }
  }

  /// ✅ METHOD BARU: Load TPS list dari API
  Future<void> _loadTPSList() async {
    if (!mounted) return;

    setState(() {
      _isLoadingTPS = true;
    });

    try {
      appLog('🏭 [HomeCollector] ===== LOADING TPS LIST =====');
      final tpsList = await TPSDepositService.getAssignedTPS();

      if (mounted) {
        setState(() {
          _tpsList = tpsList;
          _isLoadingTPS = false;
        });
        appLog('✅ [HomeCollector] Loaded ${_tpsList.length} TPS');
      }
    } catch (e, stackTrace) {
      appLog('❌ [HomeCollector] Error loading TPS: $e');
      appLog('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _tpsList = [];
          _isLoadingTPS = false;
        });
      }
    }
  }

  /// ✅ METHOD BARU: Load deposit history dari API
  Future<void> _loadDepositHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoadingDeposits = true;
    });

    try {
      appLog('📋 [HomeCollector] ===== LOADING DEPOSIT HISTORY =====');
      final (success, message, deposits, meta) =
          await TPSDepositService.getDepositHistory();

      if (mounted) {
        setState(() {
          if (success) {
            _depositHistory = deposits;
            // Also update pengangkutanList for backward compatibility
            pengangkutanList = deposits
                .map(
                  (d) => {
                    'id': d.id,
                    'tpsId': d.garbageDumpId,
                    'tpsName': d.tpsName,
                    'tpsAddress': d.tpsAddress,
                    'date': d.formattedDate,
                    'time': d.formattedTime,
                    'timestamp': d.depositedAt.toIso8601String(),
                    'notes': d.notes,
                    'status': 'completed',
                  },
                )
                .toList();
          }
          _isLoadingDeposits = false;
        });
        appLog('✅ [HomeCollector] Loaded ${_depositHistory.length} deposits');
      }
    } catch (e, stackTrace) {
      appLog('❌ [HomeCollector] Error loading deposits: $e');
      appLog('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _depositHistory = [];
          _isLoadingDeposits = false;
        });
      }
    }
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Build image widget dengan handling untuk berbagai tipe path
  Widget _buildPickupImage(String imagePath) {
    appLog('[IMG] [HomeKolektor] Building pickup image: $imagePath');

    // Placeholder widget jika image kosong
    if (imagePath.isEmpty) {
      return Container(
        height: 100,
        width: 100,
        color: Colors.grey[300],
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 40,
        ),
      );
    }

    // Convert relative URL to full URL if needed (from API)
    String finalImagePath = imagePath;
    if (!imagePath.startsWith('assets/')) {
      final formatted = ApiConfig.formatImageUrl(imagePath);
      if (formatted != null) {
        finalImagePath = formatted;
        appLog('[SYNC] [HomeKolektor] Formatted photo URL: $finalImagePath');
      }
    }

    // HTTP/HTTPS URL - gunakan Image.network
    if (finalImagePath.startsWith('http://') ||
        finalImagePath.startsWith('https://')) {
      appLog('[NET] [HomeKolektor] Loading network image: $finalImagePath');
      return Image.network(
        finalImagePath,
        height: 100,
        width: 100,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          appLog('[ERROR] [HomeKolektor] Image load error: $error');
          return Container(
            height: 100,
            width: 100,
            color: Colors.grey[300],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Gagal memuat',
                    style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            appLog('[OK] [HomeKolektor] Image loaded successfully');
            return child;
          }
          return Container(
            height: 100,
            width: 100,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }

    // File path lokal (dimulai dengan / atau berisi path lengkap) - hanya untuk file lokal sebenarnya
    if (finalImagePath.startsWith('/') ||
        finalImagePath.contains('storagePickups')) {
      final file = File(finalImagePath);

      // Cek apakah file exists
      if (!file.existsSync()) {
        return Container(
          height: 100,
          width: 100,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.image_not_supported,
                color: Colors.grey,
                size: 40,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'File tidak ditemukan',
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      }

      return Image.file(
        file,
        height: 100,
        width: 100,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 100,
            width: 100,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
          );
        },
      );
    }

    // Asset path (fallback - untuk backward compatibility)
    return Image.asset(
      finalImagePath,
      height: 100,
      width: 100,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 100,
          width: 100,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.image_not_supported,
                color: Colors.grey,
                size: 40,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Asset tidak ditemukan',
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan welcome message jika ada dari login
    if (!_hasShownWelcomeMessage && !_isLoadingPickups) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map && args['welcomeMessage'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      args['welcomeMessage'],
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() {
            _hasShownWelcomeMessage = true;
          });
        }
      });
    }

    const Color primaryColor = Color(0xFF009688);
    final TextStyle titleStyle = GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _selectedIndex == 0
          ? _buildBerandaPage(primaryColor, titleStyle)
          : _selectedIndex == 1
          ? _buildPengangkutanPage(primaryColor, titleStyle)
          : _selectedIndex == 2
          ? _buildRiwayatPage(primaryColor)
          : ProfileScreen(
              onProfileUpdated: (newImagePath) {
                setState(() {
                  _profileImagePath = newImagePath;
                });
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Pengangkutan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            activeIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildBerandaPage(Color primaryColor, TextStyle titleStyle) {
    // ✅ GABUNGKAN total tugas (pickup reguler + off-schedule + complaint)
    final totalTasks =
        todayPickups.length +
        offSchedulePickups.length +
        assignedComplaints.length;
    final completedPickups = _getCompletedCount();
    final completedOffSchedule = offSchedulePickups
        .where((p) => p['status'] == 'completed')
        .length;
    final completedComplaints = assignedComplaints
        .where((c) => c.status == 'resolved')
        .length;
    final totalCompleted =
        completedPickups + completedOffSchedule + completedComplaints;
    final totalPending = totalTasks - totalCompleted;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          appLog('↓ [HomeCollector] Pull to refresh triggered');
          await _loadTodayPickups(forceRefresh: true);
          await _loadAssignedComplaints(); // ✅ REFRESH COMPLAINTS
          await _loadOffSchedulePickups(); // ✅ REFRESH OFF-SCHEDULE
          await _loadPengambilanData();
        },
        color: primaryColor,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh even when content is short
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Profile Icon/Avatar
                        _buildProfileAvatar(primaryColor),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Notification button dengan badge
                    Stack(
                      children: [
                        IconButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const NotificationScreen(isKolektor: true),
                              ),
                            );
                            // Refresh unread count setelah kembali dari notification screen
                            await _loadUnreadNotifCount();
                          },
                          icon: Image.asset(
                            'assets/images/notification.png',
                            width: 26,
                            height: 26,
                            color: Colors.black87,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.notifications_outlined,
                                size: 26,
                                color: Colors.black87,
                              );
                            },
                          ),
                        ),
                        // Badge untuk unread notifications
                        if (_unreadNotifCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Center(
                                child: Text(
                                  _unreadNotifCount > 9
                                      ? '9+'
                                      : _unreadNotifCount.toString(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ✅ INFO BOX - Tampilkan RW Kolektor dan info complaint
              if (_kolektorRWList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
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
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kolektor ditugaskan di: ${_kolektorRWList.join(", ")}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              // ✅ TAMPILKAN INFO COMPLAINT
                              Text(
                                '${todayPickups.length} pickup reguler • ${assignedComplaints.length} pengaduan',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Card Ringkasan
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Tugas Hari Ini",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTodayDate(),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(totalTasks.toString(), "Total"),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            _statItem(totalCompleted.toString(), "Selesai"),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            _statItem(totalPending.toString(), "Belum"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Daftar Tugas Header dengan Tab
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Daftar Tugas", style: titleStyle),
                    TextButton(
                      onPressed: () {
                        // Navigate ke halaman riwayat atau list lengkap
                        setState(() {
                          _selectedIndex = 2; // Pindah ke tab Riwayat
                        });
                      },
                      child: Text(
                        "Lainnya",
                        style: GoogleFonts.poppins(
                          color: primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Navigation untuk Pengambilan dan Pelaporan
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _tugasTabIndex = 0;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _tugasTabIndex == 0
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: _tugasTabIndex == 0
                                  ? Border(
                                      bottom: BorderSide(
                                        color: primaryColor,
                                        width: 3,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                "Pengambilan",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: _tugasTabIndex == 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _tugasTabIndex == 0
                                      ? Colors.black87
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _tugasTabIndex = 1;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _tugasTabIndex == 1
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: _tugasTabIndex == 1
                                  ? Border(
                                      bottom: BorderSide(
                                        color: primaryColor,
                                        width: 3,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                "Pengaduan",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: _tugasTabIndex == 1
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _tugasTabIndex == 1
                                      ? Colors.black87
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ✅ LOADING STATE
              if (_isLoadingPickups || _isLoadingComplaints)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.red[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          _loadTodayPickups();
                          _loadAssignedComplaints(); // ✅ RETRY COMPLAINTS
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                        ),
                        child: Text('Coba Lagi', style: GoogleFonts.poppins()),
                      ),
                    ],
                  ),
                )
              // ✅ FIX: Juga periksa offSchedulePickups dan allOffSchedulePickups
              // Card tugas Request ada di allOffSchedulePickups yang akan difilter di _buildPengambilanList
              else if (todayPickups.isEmpty &&
                  assignedComplaints.isEmpty &&
                  allOffSchedulePickups.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _tugasTabIndex == 0
                              ? 'Belum ada pengambilan sampah'
                              : 'Belum ada pengambilan sampah',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // ✅ TAMPILKAN BERDASARKAN TAB
                _tugasTabIndex == 0
                    ? _buildPengambilanList(primaryColor)
                    : _buildPelaporanList(primaryColor),

              const SizedBox(height: 24),

              // Pengambilan Terakhir
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Pengambilan Terakhir", style: titleStyle),
                    Text(
                      "Lainnya",
                      style: GoogleFonts.poppins(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 220,
                child: _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : Builder(
                        builder: (context) {
                          // ✅ PERBAIKAN: Filter pengambilanList hanya untuk hari ini
                          final today = DateTime.now();
                          final todayStr =
                              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

                          final todayPickupHistory = pengambilanList.where((
                            item,
                          ) {
                            final pickupDate = item['date']?.toString() ?? '';
                            // Cek apakah tanggal pickup sama dengan hari ini
                            // Format date bisa: "YYYY-MM-DD" atau "Senin, 16 Desember 2025 10.00"
                            if (pickupDate.contains(todayStr)) {
                              return true;
                            }
                            // Cek format alternatif (tanggal dalam format readable)
                            final dayStr = today.day.toString();
                            if (pickupDate.contains(' $dayStr ') &&
                                pickupDate.contains('${today.year}')) {
                              return true;
                            }
                            return false;
                          }).toList();

                          final displayList = todayPickupHistory.isNotEmpty
                              ? todayPickupHistory
                              : pengambilanList;

                          if (displayList.isEmpty) {
                            return Center(
                              child: Text(
                                'Belum ada pengambilan sampah',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: displayList.length,
                            itemBuilder: (context, index) {
                              final item = displayList[index];
                              return _pickupCard(
                                item["name"]?.toString() ?? "",
                                item["address"]?.toString() ?? "",
                                "Rp. ${(item["totalPrice"] as num?)?.toInt() ?? 0}",
                                item["image"]?.toString() ??
                                    "assets/images/dummy.jpg",
                                primaryColor,
                                item, // Pass the full item data
                              );
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ), // Close RefreshIndicator
    );
  }

  /// ✅ METHOD: Build list pengambilan sampah (reguler + off-schedule)
  Widget _buildPengambilanList(Color primaryColor) {
    // ✅ PERBAIKAN: Filter hanya untuk hari ini
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // ✅ Filter off-schedule pickups dari allOffSchedulePickups:
    // - HANYA yang tanggal request-nya adalah HARI INI
    // - Yang sedang diproses (processing) ATAU sudah selesai
    // - KECUALI yang cancelled atau rejected
    final activeOffSchedule = allOffSchedulePickups.where((pickup) {
      final status = pickup['status']?.toString() ?? '';
      final requestStatus = pickup['request_status']?.toString() ?? '';
      final photoUrl = pickup['photo_url']?.toString() ?? '';
      final hasPhoto = photoUrl.isNotEmpty && photoUrl != 'null';

      // Skip yang cancelled atau rejected
      if (status == 'cancelled' || requestStatus == 'rejected') {
        return false;
      }

      // Tampilkan yang masih pending, sent, atau processing (belum selesai dijemput)
      if (requestStatus == 'processing' ||
          requestStatus == 'pending' ||
          requestStatus == 'sent' ||
          (status == 'pending' && !hasPhoto)) {
        return true;
      }

      // Tampilkan yang sudah selesai hari ini (punya foto atau status completed/paid)
      final pickupDate =
          pickup['requested_pickup_date']?.toString() ??
          pickup['requested_date']?.toString() ??
          '';
      final isToday = pickupDate == todayStr;
      if (isToday && (hasPhoto || requestStatus == 'completed' || requestStatus == 'paid')) {
        return true;
      }

      return false;
    }).toList();

    // Gabungkan regular pickups dan active off-schedule pickups
    final allPickups = [...todayPickups, ...activeOffSchedule];

    // ✅ SORT: Pindahkan card yang sudah selesai ke bawah
    allPickups.sort((a, b) {
      final statusA = a['status']?.toString() ?? '';
      final statusB = b['status']?.toString() ?? '';
      final photoUrlA = a['photo_url']?.toString() ?? '';
      final photoUrlB = b['photo_url']?.toString() ?? '';
      final hasPhotoA = photoUrlA.isNotEmpty && photoUrlA != 'null';
      final hasPhotoB = photoUrlB.isNotEmpty && photoUrlB != 'null';

      // Status selesai: status collected/completed/resolved ATAU punya foto
      final isCompletedA =
          statusA == 'completed' ||
          statusA == 'collected' ||
          statusA == 'resolved' ||
          hasPhotoA;
      final isCompletedB =
          statusB == 'completed' ||
          statusB == 'collected' ||
          statusB == 'resolved' ||
          hasPhotoB;

      if (isCompletedA && !isCompletedB) return 1; // A ke bawah
      if (!isCompletedA && isCompletedB) return -1; // B ke bawah
      return 0; // Urutan sama
    });

    if (allPickups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Belum ada pengambilan sampah',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: allPickups.map((pickup) {
        final pType1 = pickup['pickup_type']?.toString().toLowerCase();
        final isOffSchedule = pType1 == 'off-schedule' || pType1 == 'off_schedule' || pType1 == 'request';

        if (isOffSchedule) {
          // Handle off-schedule pickup display
          final displayName =
              pickup['service_account_name']?.toString() ?? 'N/A';
          final address = pickup['address']?.toString() ?? 'N/A';
          final pickupId = '${pickup['id']}'; // Simple ID number
          final requestStatus =
              pickup['request_status']?.toString() ?? 'pending';
          final photoUrl = pickup['photo_url']?.toString() ?? '';
          final hasPhoto = photoUrl.isNotEmpty && photoUrl != 'null';

          // ✅ FIX: Tentukan status berdasarkan:
          // 1. Jika ada photo_url = sudah selesai (kolektor sudah foto dan submit)
          // 2. Jika request_status = completed = sudah selesai
          // 3. Jika request_status = processing = masih dalam proses
          String status;
          if (hasPhoto ||
              requestStatus == 'completed' ||
              requestStatus == 'paid') {
            status =
                'collected'; // Gunakan 'collected' agar tombol Ambil disabled
          } else if (requestStatus == 'processing') {
            status = 'pending'; // Masih dalam proses, tombol aktif
          } else {
            status = requestStatus;
          }

          return _taskCard(
            displayName,
            address,
            pickupId,
            status,
            0.0, // latitude - bisa ditambahkan jika ada di data
            0.0, // longitude - bisa ditambahkan jika ada di data
            primaryColor,
            context,
            pickup,
          );
        } else {
          // Handle regular pickup display
          final houseInfo = pickup['house_info'] as Map<String, dynamic>?;
          final serviceAccountInfo =
              pickup['service_account'] as Map<String, dynamic>?;

          String displayName = 'N/A';
          if (serviceAccountInfo != null &&
              serviceAccountInfo['name'] != null) {
            displayName = serviceAccountInfo['name'].toString();
          } else if (houseInfo != null) {
            if (houseInfo['account_number'] != null) {
              displayName = houseInfo['account_number'].toString();
            } else if (houseInfo['service_account_name'] != null) {
              displayName = houseInfo['service_account_name'].toString();
            } else if (houseInfo['resident_name'] != null) {
              displayName = houseInfo['resident_name'].toString();
            }
          }

          return _taskCard(
            displayName,
            houseInfo?['address']?.toString() ?? 'N/A',
            pickup['id']?.toString() ?? '',
            pickup['status']?.toString() ?? 'scheduled',
            houseInfo?['latitude'] as double? ?? 0.0,
            houseInfo?['longitude'] as double? ?? 0.0,
            primaryColor,
            context,
            pickup,
          );
        }
      }).toList(),
    );
  }

  /// ✅ METHOD BARU: Build list pelaporan/complaint
  Widget _buildPelaporanList(Color primaryColor) {
    // ✅ FILTER: Hanya tampilkan complaint yang belum resolved
    final activeComplaints = assignedComplaints.where((complaint) {
      return complaint.status != 'resolved' && complaint.status != 'rejected';
    }).toList();

    // ✅ SORT: Pindahkan complaint in_progress ke atas
    activeComplaints.sort((a, b) {
      final isProgressA = a.status == 'in_progress';
      final isProgressB = b.status == 'in_progress';

      if (isProgressA && !isProgressB) return -1; // A ke atas
      if (!isProgressA && isProgressB) return 1; // B ke atas
      return 0;
    });

    if (activeComplaints.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Belum ada tugas pengaduan',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: activeComplaints.map((complaint) {
        return _buildComplaintCard(
          complaint: complaint,
          primaryColor: primaryColor,
          context: context,
        );
      }).toList(),
    );
  }

  Widget _buildPengangkutanPage(Color primaryColor, TextStyle titleStyle) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadTPSList();
        },
        color: primaryColor,
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Text(
                    'Daftar TPS',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Refresh button
                  IconButton(
                    onPressed: _isLoadingTPS ? null : () => _loadTPSList(),
                    icon: _isLoadingTPS
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.refresh, color: primaryColor),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // List TPS
            Expanded(
              child: _isLoadingTPS
                  ? const Center(child: CircularProgressIndicator())
                  : _tpsList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada TPS yang di-assign',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hubungi admin untuk assign TPS',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _loadTPSList(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _tpsList.length,
                      itemBuilder: (context, index) {
                        final tps = _tpsList[index];
                        return _buildTPSCardFromAPI(
                          tps: tps,
                          primaryColor: primaryColor,
                          context: context,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatPage(Color primaryColor) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Text(
                  'Riwayat',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _riwayatTabIndex = 0;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _riwayatTabIndex == 0
                                ? primaryColor
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'Pengambilan',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: _riwayatTabIndex == 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _riwayatTabIndex == 0
                              ? primaryColor
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _riwayatTabIndex = 1;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _riwayatTabIndex == 1
                                ? primaryColor
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'Pengangkutan',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: _riwayatTabIndex == 1
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _riwayatTabIndex == 1
                              ? primaryColor
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content based on selected tab
          Expanded(
            child: _riwayatTabIndex == 0
                ? _buildRiwayatPengambilanContent(primaryColor)
                : _buildRiwayatPengangkutanContent(primaryColor),
          ),
        ],
      ),
    );
  }

  // Riwayat Pengambilan Content
  Widget _buildRiwayatPengambilanContent(Color primaryColor) {
    // Tampilkan seluruh riwayat pengambilan yang telah dikerjakan kolektor
    final pickupHistory = pengambilanList;

    return _isLoadingHistory
        ? const Center(child: CircularProgressIndicator())
        : pickupHistory.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Belum ada riwayat pengambilan',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: pickupHistory.length,
            itemBuilder: (context, index) {
              final item = pickupHistory[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: _buildPickupImage(
                        item["image"]?.toString() ?? "assets/images/dummy.jpg",
                      ),
                    ),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label jenis pengambilan di atas nama
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getPickupTypeColor(item),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getPickupTypeLabel(item),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item["name"]?.toString() ?? "Unknown",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        item["address"]?.toString() ?? "",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Rp. ${(item["totalPrice"] as num?)?.toInt() ?? 0}",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RiwayatSampahScreen(pickupData: item),
                        ),
                      );
                    },
                    child: Text(
                      'Detail',
                      style: GoogleFonts.poppins(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }

  // Riwayat Pengangkutan Content
  Widget _buildRiwayatPengangkutanContent(Color primaryColor) {
    // Loading state
    if (_isLoadingDeposits) {
      return const Center(child: CircularProgressIndicator());
    }

    // Empty state
    if (_depositHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 100,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Riwayat',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Riwayat pengangkutan akan muncul setelah Anda menyelesaikan tugas pengangkutan ke TPS',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadDepositHistory(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // List content
    return RefreshIndicator(
      onRefresh: () => _loadDepositHistory(),
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _depositHistory.length,
        itemBuilder: (context, index) {
          final deposit = _depositHistory[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => _showDepositDetailDialog(context, deposit),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_shipping,
                        color: Colors.green[600],
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deposit.tpsName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                deposit.formattedDate,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                deposit.formattedTime,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          if (deposit.notes != null &&
                              deposit.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              deposit.notes!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Selesai',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Check icon
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Show deposit detail dialog
  void _showDepositDetailDialog(BuildContext context, TPSDeposit deposit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Detail Setor',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('TPS', deposit.tpsName),
            _detailRow('Alamat', deposit.tpsAddress),
            _detailRow('Tanggal', deposit.formattedDate),
            _detailRow('Waktu', deposit.formattedTime),
            if (deposit.notes != null && deposit.notes!.isNotEmpty)
              _detailRow('Catatan', deposit.notes!),
            _detailRow(
              'Lokasi GPS',
              '${deposit.latitude.toStringAsFixed(6)}, ${deposit.longitude.toStringAsFixed(6)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _taskCard(
    String name,
    String address,
    String pickupId,
    String status,
    double latitude,
    double longitude,
    Color primaryColor,
    BuildContext context,
    Map<String, dynamic> pickupData,
  ) {
    // Status badge configuration
    final pType2 = pickupData['pickup_type']?.toString().toLowerCase();
    final isOffSchedule = pType2 == 'off-schedule' || pType2 == 'off_schedule' || pType2 == 'request';
    final statusConfig = _getStatusConfig(status, pickupData: pickupData);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ✅ Badge untuk Off-Schedule
              if (isOffSchedule)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 14, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Luar Jadwal',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isOffSchedule) const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusConfig['color'].withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusConfig['label'],
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: statusConfig['color'],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "#$pickupId",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            address,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  status == 'completed' ||
                      status == 'cancelled' ||
                      status == 'skipped' ||
                      status == 'collected'
                  ? null
                  : () {
                      final houseInfo =
                          pickupData['house_info'] as Map<String, dynamic>?;

                      // Jika status on_progress, langsung ke halaman Ambil Foto
                      if (status == 'on_progress') {
                        // Ambil nama dari service account, bukan resident
                        final serviceAccountInfo =
                            pickupData['service_account']
                                as Map<String, dynamic>?;
                        String displayName = name;

                        if (serviceAccountInfo != null &&
                            serviceAccountInfo['name'] != null) {
                          displayName = serviceAccountInfo['name'] as String;
                        } else if (houseInfo != null &&
                            houseInfo['service_account_name'] != null) {
                          displayName =
                              houseInfo['service_account_name'] as String;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AmbilFotoScreen(
                              pickupId: pickupData['id'] as int,
                              userName: displayName,
                              address: address,
                              idPengambilan: pickupId,
                            ),
                          ),
                        ).then((_) async {
                          // Refresh data setelah kembali dari foto screen
                          // ✅ FIX: Load off-schedule dulu, kemudian update history
                          await _loadOffSchedulePickups();
                          await _loadTodayPickups();
                          await _loadPengambilanDataOnly();
                          // ✅ PENTING: Panggil _addCompletedTasksToHistory setelah semua data dimuat
                          _addCompletedTasksToHistory();
                        });
                        return;
                      }

                      // PERBAIKAN: Ambil data service account dengan prioritas yang benar
                      final serviceAccountInfo =
                          pickupData['service_account']
                              as Map<String, dynamic>?;

                      // Debug logging - PENTING untuk melihat struktur data!
                      appLog(
                        '═══════════════════════════════════════════════════════',
                      );
                      appLog(
                        '🔍 [PICKUP DATA] All keys: ${pickupData.keys.toList()}',
                      );
                      appLog('🔍 [SERVICE ACCOUNT] Data: $serviceAccountInfo');
                      appLog('🔍 [HOUSE INFO] Data: $houseInfo');

                      // Variabel untuk nama dan telepon yang akan ditampilkan
                      String displayName = 'Data tidak tersedia';
                      String displayPhone = '-';

                      // ✅ PRIORITAS KHUSUS: Untuk off-schedule pickup, gunakan data yang sudah lengkap
                      if (isOffSchedule && serviceAccountInfo != null) {
                        displayName =
                            serviceAccountInfo['name'] as String? ??
                            'Data tidak tersedia';
                        final phone =
                            serviceAccountInfo['contact_phone'] as String?;
                        displayPhone = (phone != null && phone.isNotEmpty)
                            ? phone
                            : '-';
                        appLog(
                          '✅ [DATA SOURCE] Off-schedule pickup - service_account',
                        );
                        appLog('   Contact Phone from serviceAccount: $phone');
                      } else if (serviceAccountInfo != null &&
                          serviceAccountInfo['name'] != null) {
                        // PRIORITAS 1: service_account object terpisah
                        displayName = serviceAccountInfo['name'] as String;
                        final phone =
                            serviceAccountInfo['contact_phone'] as String?;
                        displayPhone = (phone != null && phone.isNotEmpty)
                            ? phone
                            : '-';
                        appLog('✅ [DATA SOURCE] service_account object');
                      } else if (houseInfo != null) {
                        // PRIORITAS 2: account_number (INI NAMA SERVICE ACCOUNT!)
                        if (houseInfo['account_number'] != null) {
                          displayName = houseInfo['account_number'] as String;
                          final phone = houseInfo['phone_number'] as String?;
                          displayPhone = (phone != null && phone.isNotEmpty)
                              ? phone
                              : '-';
                          appLog(
                            '✅ [DATA SOURCE] house_info.account_number (NAMA SERVICE ACCOUNT)',
                          );
                        } else if (houseInfo['service_account_name'] != null) {
                          // Ada field service_account_name di house_info
                          displayName =
                              houseInfo['service_account_name'] as String;
                          final phone =
                              houseInfo['service_account_phone'] as String?;
                          displayPhone = (phone != null && phone.isNotEmpty)
                              ? phone
                              : '-';
                          appLog(
                            '✅ [DATA SOURCE] house_info.service_account_*',
                          );
                        } else if (houseInfo.containsKey('service_account')) {
                          // Kadang service_account nested di house_info
                          final nestedSA =
                              houseInfo['service_account']
                                  as Map<String, dynamic>?;
                          if (nestedSA != null) {
                            displayName =
                                nestedSA['name'] as String? ?? 'Nama tidak ada';
                            final phone = nestedSA['contact_phone'] as String?;
                            displayPhone = (phone != null && phone.isNotEmpty)
                                ? phone
                                : '-';
                            appLog(
                              '✅ [DATA SOURCE] house_info.service_account (nested)',
                            );
                          }
                        } else {
                          // FALLBACK: Gunakan resident name (ini yang saat ini terjadi)
                          displayName =
                              houseInfo['resident_name'] as String? ?? name;
                          final phone = houseInfo['phone'] as String?;
                          displayPhone = (phone != null && phone.isNotEmpty)
                              ? phone
                              : '-';
                          appLog(
                            '⚠️ [DATA SOURCE] resident (FALLBACK - BUKAN SERVICE ACCOUNT!)',
                          );
                          appLog(
                            '⚠️ service_account_id: ${houseInfo['service_account_id']}',
                          );
                        }
                      }

                      appLog('📌 [RESULT] Name: $displayName');
                      appLog('📌 [RESULT] Phone: $displayPhone');
                      appLog(
                        '═══════════════════════════════════════════════════════',
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PengambilanSampahScreen(
                            pickupId: pickupData['id'] as int,
                            userName: displayName,
                            userPhone: displayPhone,
                            address: address,
                            idPengambilan: pickupId,
                            distance: '0.5 km',
                            time: '5 min',
                            latitude: houseInfo?['latitude'] as double? ?? 0.0,
                            longitude:
                                houseInfo?['longitude'] as double? ?? 0.0,
                            status: status, // Tambahkan parameter status
                            isOffSchedule:
                                isOffSchedule, // Pass flag off-schedule
                          ),
                        ),
                      ).then((_) async {
                        // Refresh list setelah kembali
                        // ✅ FIX: Load off-schedule dulu, kemudian update history
                        await _loadOffSchedulePickups();
                        await _loadTodayPickups();
                        await _loadPengambilanDataOnly();
                        // ✅ PENTING: Panggil _addCompletedTasksToHistory setelah semua data dimuat
                        _addCompletedTasksToHistory();
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                status == 'on_progress'
                    ? "Lanjutkan"
                    : status == 'completed'
                    ? "Selesai"
                    : "Ambil",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickupCard(
    String name,
    String address,
    String price,
    String image,
    Color primaryColor,
    Map<String, dynamic> fullData,
  ) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: _buildPickupImage(image),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Label jenis pengambilan
                  Wrap(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getPickupTypeColor(fullData),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getPickupTypeLabel(fullData),
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[600],
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RiwayatSampahScreen(pickupData: fullData),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "Detail",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ NEW: Widget untuk Card TPS dari API
  Widget _buildTPSCardFromAPI({
    required TPS tps,
    required Color primaryColor,
    required BuildContext context,
  }) {
    // Build location string
    String locationStr = tps.address;
    if (tps.kelurahan != null || tps.kecamatan != null) {
      final parts = <String>[];
      if (tps.kelurahan != null) parts.add(tps.kelurahan!.name);
      if (tps.kecamatan != null) parts.add(tps.kecamatan!.name);
      if (parts.isNotEmpty) {
        locationStr = parts.join(', ');
      }
    }

    // Build capacity info
    String capacityInfo = '';
    if (tps.capacityWeight != null) {
      capacityInfo = '${tps.capacityWeight!.toStringAsFixed(0)} kg';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar TPS
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: _buildTPSImage(tps.imageUrl),
          ),

          // Info TPS
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama TPS dengan status badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tps.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tps.status == 'active'
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tps.status == 'active' ? 'Aktif' : 'Nonaktif',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tps.status == 'active'
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Lokasi
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        locationStr,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Info tambahan (Kapasitas & RW jika ada)
                Row(
                  children: [
                    // Kapasitas
                    if (capacityInfo.isNotEmpty) ...[
                      Icon(Icons.scale, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        capacityInfo,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    // RW
                    if (tps.rw != null) ...[
                      Icon(Icons.people_outline, size: 16, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        tps.rw!.name,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Tombol Angkut Sampah
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: tps.status == 'active'
                        ? () => _handleAngkutSampahFromAPI(context, tps)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Angkut Sampah',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build TPS image widget
  Widget _buildTPSImage(String? imageUrl) {
    // Default placeholder
    Widget placeholder = Container(
      width: double.infinity,
      height: 180,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'TPS',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return placeholder;
    }

    // Handle relative URLs
    String fullUrl = imageUrl;
    if (!imageUrl.startsWith('http')) {
      fullUrl = '${ApiConfig.serverUrl}$imageUrl';
    }

    return Image.network(
      fullUrl,
      width: double.infinity,
      height: 180,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: double.infinity,
          height: 180,
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  /// ✅ NEW: Handler untuk angkut sampah - Navigate to Maps
  void _handleAngkutSampahFromAPI(BuildContext context, TPS tps) async {
    // Navigate to TPS Map Screen
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => TPSMapScreen(tps: tps)),
    );

    // If deposit was successful, refresh data
    if (result == true && context.mounted) {
      _loadTPSList();
      _loadDepositHistory();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Berhasil setor ke ${tps.name}',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // Helper methods
  String _formatTodayDate() {
    final now = DateTime.now();
    const List<String> months = [
      '',
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
    return '${now.day} ${months[now.month]} ${now.year}';
  }

  int _getCompletedCount() {
    return todayPickups
        .where((p) => p['status'] == 'completed' || p['status'] == 'collected')
        .length;
  }

  Map<String, dynamic> _getStatusConfig(
    String status, {
    Map<String, dynamic>? pickupData,
  }) {
    // ✅ PERBAIKAN: Cek apakah ini off-schedule pickup (express request)
    final pType3 = pickupData?['pickup_type']?.toString().toLowerCase();
    final isOffSchedule = pType3 == 'off-schedule' || pType3 == 'off_schedule' || pType3 == 'request';

    // ✅ Untuk off-schedule, gunakan request_status sebagai prioritas
    if (isOffSchedule) {
      final requestStatus = pickupData?['request_status']?.toString() ?? status;
      final photoUrl = pickupData?['photo_url']?.toString() ?? '';
      final hasPhoto = photoUrl.isNotEmpty && photoUrl != 'null';

      // ✅ PERBAIKAN: Jika sudah ada foto, berarti sudah selesai
      // Ini mengatasi kasus di mana request_status masih 'pending' tapi kolektor sudah submit foto
      if (hasPhoto) {
        return {'label': 'Selesai', 'color': Colors.green[600]};
      }

      switch (requestStatus) {
        case 'sent':
          return {'label': 'Menunggu', 'color': Colors.orange[600]};
        case 'processing':
        case 'assigned':
          return {'label': 'Request', 'color': Colors.orange[700]};
        case 'pending':
          return {'label': 'Menunggu', 'color': Colors.orange[600]};
        case 'on_progress':
        case 'in_progress':
          return {'label': 'Dalam Proses', 'color': Colors.blue[600]};
        case 'completed':
          return {'label': 'Selesai', 'color': Colors.green[600]};
        case 'cancelled':
          return {'label': 'Dibatalkan', 'color': Colors.red[600]};
        default:
          return {'label': 'Request', 'color': Colors.orange[700]};
      }
    }

    // Regular pickup status
    switch (status) {
      case 'pending':
      case 'scheduled':
      case 'assigned':
      case 'open': // ✅ TAMBAHAN: "open" = complaint sudah di-assign
        return {'label': 'Dijadwalkan', 'color': Colors.blue[600]};
      case 'on_progress':
      case 'in_progress':
        return {'label': 'Dalam Proses', 'color': Colors.orange[600]};
      case 'collected':
        return {'label': 'Selesai', 'color': Colors.green[600]};
      case 'completed':
      case 'resolved':
        return {'label': 'Selesai', 'color': Colors.green[600]};
      case 'cancelled':
        return {'label': 'Dibatalkan', 'color': Colors.red[600]};
      case 'skipped':
        return {'label': 'Dilewati', 'color': Colors.grey[600]};
      default:
        return {'label': status, 'color': Colors.grey[600]};
    }
  }

  /// ✅ Build Complaint Card - Simple design seperti card pengambilan
  Widget _buildComplaintCard({
    required Complaint complaint,
    required Color primaryColor,
    required BuildContext context,
  }) {
    // Map status complaint ke status config
    String displayStatus = complaint.status;
    if (displayStatus == 'assigned' || displayStatus == 'open') {
      displayStatus = 'pending';
    }

    final statusConfig = _getStatusConfig(displayStatus);
    final reporterName = complaint.reporter?['name']?.toString() ?? 'Warga';
    final reporterAddress = complaint.location ?? 'Alamat tidak tersedia';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Label + Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.report_problem,
                        size: 12,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PENGADUAN',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusConfig['color'].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusConfig['label'],
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: statusConfig['color'],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  "#${complaint.id}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Nama & Alamat
            Text(
              reporterName,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    reporterAddress,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tombol Aksi
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: displayStatus == 'resolved'
                    ? null
                    : () async {
                        appLog(
                          '🚀 [HomeCollector] Navigate to complaint detail: ${complaint.id}',
                        );

                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CollectorComplaintDetailScreen(
                                  complaint: complaint,
                                ),
                          ),
                        );

                        // Refresh data setelah proses selesai
                        if (result == true) {
                          appLog(
                            '🔄 [HomeCollector] Complaint resolved, refreshing data...',
                          );
                          // ✅ FIX: Load semua data paralel dulu, baru panggil _addCompletedTasksToHistory
                          await Future.wait([
                            _loadAssignedComplaints(),
                            _loadPengambilanDataOnly(),
                            _loadOffSchedulePickups(),
                            _loadTodayPickups(forceRefresh: true),
                          ]);
                          // Panggil _addCompletedTasksToHistory setelah semua data dimuat
                          _addCompletedTasksToHistory();
                          if (mounted) setState(() {});
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  displayStatus == 'in_progress'
                      ? "Lanjutkan Proses"
                      : displayStatus == 'resolved'
                      ? "Selesai"
                      : "Mulai Proses",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ HELPER: Get pickup type label
  String _getPickupTypeLabel(Map<String, dynamic> data) {
    // Check if it's a complaint
    final pickupType = data['pickup_type']?.toString().toLowerCase();
    if ((data.containsKey('type') && data['type'] != null) || pickupType == 'complaint') {
      return 'Tugas Pengaduan';
    }

    // Check if it's off-schedule (request)
    if (pickupType == 'off-schedule' ||
        pickupType == 'off_schedule' ||
        pickupType == 'request') {
      return 'Request Pengambilan';
    }

    // Default: regular scheduled pickup
    return 'Pengambilan Reguler';
  }

  /// ✅ HELPER: Get pickup type color
  Color _getPickupTypeColor(Map<String, dynamic> data) {
    // Check if it's a complaint
    final pickupType = data['pickup_type']?.toString().toLowerCase();
    if ((data.containsKey('type') && data['type'] != null) || pickupType == 'complaint') {
      return Colors.red; // Merah untuk pelaporan
    }

    // Check if it's off-schedule (request)
    if (pickupType == 'off-schedule' ||
        pickupType == 'off_schedule' ||
        pickupType == 'request') {
      return Colors.orange; // Orange untuk request
    }

    // Default: regular scheduled pickup
    return const Color(0xFF009688); // Hijau tosca untuk jadwal reguler
  }

  /// Widget untuk menampilkan profile avatar
  Widget _buildProfileAvatar(Color primaryColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: primaryColor, width: 2),
      ),
      child: ClipOval(
        child:
            _profileImagePath.isNotEmpty && File(_profileImagePath).existsSync()
            ? Image.file(
                File(_profileImagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: primaryColor.withValues(alpha: 0.1),
                    child: Icon(Icons.person, color: primaryColor, size: 24),
                  );
                },
              )
            : Container(
                color: primaryColor.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: primaryColor, size: 24),
              ),
      ),
    );
  }
}
