import 'package:beresin_app/utils/app_log.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/user/notification_service.dart';
import 'resident_pickup_service.dart';
import 'invoice_service.dart';

/// Helper untuk mengelola notifikasi otomatis
class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();

  final ResidentPickupService _pickupService = ResidentPickupService();
  final InvoiceService _invoiceService = InvoiceService();

  static const String _lastCheckDateKey = 'last_notification_check_date';
  static const String _lastArticleCountKey = 'last_article_count';
  static const String _lastUnpaidInvoiceKey = 'last_unpaid_invoice_ids';

  /// Check dan trigger semua notifikasi otomatis
  /// Dipanggil saat aplikasi dibuka atau di home screen
  /// [isKolektor] - Set true jika dipanggil dari kolektor, false untuk user/resident
  Future<void> checkAndTriggerNotifications({
    String? serviceAccountId,
    bool isKolektor = false,
  }) async {
    // Notifikasi pickup hanya untuk user/resident, tidak untuk kolektor
    if (!isKolektor) {
      await _checkScheduledPickupNotification(
        serviceAccountId: serviceAccountId,
      );
      await _checkUnpaidInvoiceNotification();
      await _checkNewArticleNotification();
    }
    // Untuk kolektor, gunakan KolektorNotificationService yang terpisah
  }

  /// Notifikasi untuk jadwal pengambilan sampah hari ini
  Future<void> _checkScheduledPickupNotification({
    String? serviceAccountId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final lastCheckDate = prefs.getString(_lastCheckDateKey);

      // Cek apakah sudah dicek hari ini
      if (lastCheckDate == todayStr) {
        return; // Sudah dicek hari ini
      }

      // Ambil jadwal pickup yang akan datang
      final (success, _, pickups) = await _pickupService.getUpcomingPickups(
        serviceAccountId: serviceAccountId,
      );

      if (success && pickups != null && pickups.isNotEmpty) {
        // Filter hanya pickup hari ini
        final todayPickups = pickups.where((pickup) {
          final pickupDate = pickup['pickup_date'] as String?;
          return pickupDate == todayStr;
        }).toList();

        if (todayPickups.isNotEmpty) {
          for (var pickup in todayPickups) {
            final dayName = pickup['day_name'] as String? ?? 'Hari Ini';
            final scheduleInfo =
                pickup['schedule_info'] as Map<String, dynamic>?;
            final timeStart = scheduleInfo?['time_start'] as String? ?? '';
            final timeEnd = scheduleInfo?['time_end'] as String? ?? '';

            String timeText = '';
            if (timeStart.isNotEmpty && timeEnd.isNotEmpty) {
              timeText = ' pukul $timeStart - $timeEnd';
            } else if (timeStart.isNotEmpty) {
              timeText = ' pukul $timeStart';
            }

            await NotificationService.addNotificationWithType(
              type: 'pickup_schedule',
              title: '🚛 Jadwal Pengambilan Sampah',
              message:
                  'Hari ini ($dayName) ada jadwal pengambilan sampah$timeText. Jangan lupa siapkan sampah Anda!',
            );
          }

          // Simpan tanggal terakhir check
          await prefs.setString(_lastCheckDateKey, todayStr);
        }
      }
    } catch (e) {
      appLog('Error checking pickup notification: $e');
    }
  }

  /// Notifikasi untuk tagihan yang belum dibayar
  Future<void> _checkUnpaidInvoiceNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = await _invoiceService.getUnpaidInvoices();

      final invoices = data['invoices'] as List<dynamic>?;
      if (invoices == null || invoices.isEmpty) {
        return; // Tidak ada tagihan
      }

      // Ambil ID invoice yang sudah pernah dinotifikasi
      final lastNotifiedIds = prefs.getStringList(_lastUnpaidInvoiceKey) ?? [];
      final currentInvoiceIds = invoices
          .map((inv) => inv['id'].toString())
          .toList();

      // Cek apakah ada invoice baru yang belum dinotifikasi
      final newInvoiceIds = currentInvoiceIds
          .where((id) => !lastNotifiedIds.contains(id))
          .toList();

      if (newInvoiceIds.isNotEmpty) {
        // Ada tagihan baru yang belum dinotifikasi
        final newInvoices = invoices
            .where((inv) => newInvoiceIds.contains(inv['id'].toString()))
            .toList();

        for (var invoice in newInvoices) {
          final period = invoice['period'] as String? ?? '';
          final amount = invoice['amount'] as num? ?? 0;
          final dueDate = invoice['due_date'] as String? ?? '';

          String message =
              'Tagihan periode $period sebesar Rp ${_formatCurrency(amount)} telah terbit.';
          if (dueDate.isNotEmpty) {
            final dueDateParsed = DateTime.tryParse(dueDate);
            if (dueDateParsed != null) {
              final daysRemaining = dueDateParsed
                  .difference(DateTime.now())
                  .inDays;
              if (daysRemaining > 0 && daysRemaining <= 7) {
                message += ' Jatuh tempo dalam $daysRemaining hari!';
              } else if (daysRemaining == 0) {
                message += ' Jatuh tempo hari ini!';
              } else if (daysRemaining < 0) {
                message += ' Sudah melewati jatuh tempo!';
              }
            }
          }

          await NotificationService.addNotificationWithType(
            type: 'invoice_new',
            title: '💰 Tagihan Baru',
            message: message,
          );
        }

        // Update list invoice yang sudah dinotifikasi
        await prefs.setStringList(_lastUnpaidInvoiceKey, currentInvoiceIds);
      } else {
        // Cek tagihan yang hampir jatuh tempo (reminder)
        for (var invoice in invoices) {
          final dueDate = invoice['due_date'] as String? ?? '';
          final dueDateParsed = DateTime.tryParse(dueDate);

          if (dueDateParsed != null) {
            final daysRemaining = dueDateParsed
                .difference(DateTime.now())
                .inDays;

            // Notifikasi 3 hari sebelum jatuh tempo
            if (daysRemaining == 3) {
              final period = invoice['period'] as String? ?? '';
              final amount = invoice['amount'] as num? ?? 0;

              await NotificationService.addNotificationWithType(
                type: 'invoice_reminder',
                title: '⏰ Pengingat Tagihan',
                message:
                    'Tagihan periode $period sebesar Rp ${_formatCurrency(amount)} akan jatuh tempo dalam 3 hari. Segera lakukan pembayaran!',
              );
            }
          }
        }
      }
    } catch (e) {
      appLog('Error checking invoice notification: $e');
    }
  }

  /// Notifikasi untuk artikel terbaru
  /// Dalam implementasi nyata, ini akan mengambil dari API
  Future<void> _checkNewArticleNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Artikel dummy untuk contoh
      // Dalam implementasi nyata, ambil dari API
      const currentArticleCount = 4; // Jumlah artikel saat ini
      final lastArticleCount = prefs.getInt(_lastArticleCountKey) ?? 0;

      if (currentArticleCount > lastArticleCount) {
        final newArticlesCount = currentArticleCount - lastArticleCount;

        await NotificationService.addNotificationWithType(
          type: 'article_new',
          title: '📰 Artikel Terbaru',
          message:
              'Ada $newArticlesCount artikel baru tentang lingkungan dan pengelolaan sampah. Yuk baca sekarang!',
        );

        await prefs.setInt(_lastArticleCountKey, currentArticleCount);
      }
    } catch (e) {
      appLog('Error checking article notification: $e');
    }
  }

  /// Notifikasi untuk pelaporan yang berhasil dibuat
  Future<void> notifyReportCreated({
    required String category,
    required String location,
  }) async {
    await NotificationService.addNotificationWithType(
      type: 'report_created',
      title: '📝 Laporan Terkirim',
      message:
          'Laporan pelanggaran "$category" di $location telah berhasil dikirim. Terima kasih atas partisipasi Anda!',
    );
  }

  /// Notifikasi untuk pembayaran berhasil
  Future<void> notifyPaymentSuccess({
    required String period,
    required num amount,
  }) async {
    await NotificationService.addNotificationWithType(
      type: 'payment_success',
      title: '✅ Pembayaran Berhasil',
      message:
          'Pembayaran tagihan periode $period sebesar Rp ${_formatCurrency(amount)} telah berhasil. Terima kasih!',
    );
  }

  /// Notifikasi untuk akun layanan berhasil dibuat
  Future<void> notifyServiceAccountCreated({
    required String accountName,
  }) async {
    await NotificationService.addNotificationWithType(
      type: 'service_account_created',
      title: '🎉 Akun Layanan Dibuat',
      message:
          'Akun layanan "$accountName" telah berhasil dibuat. Anda sekarang dapat menggunakan layanan pengambilan sampah.',
    );
  }

  /// Format currency
  String _formatCurrency(num amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  /// Reset semua notifikasi check (untuk testing)
  Future<void> resetNotificationChecks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastCheckDateKey);
    await prefs.remove(_lastArticleCountKey);
    await prefs.remove(_lastUnpaidInvoiceKey);
  }
}
