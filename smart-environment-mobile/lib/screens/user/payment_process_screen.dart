import 'package:beresin_app/utils/app_log.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/payment_service.dart';
import '../../models/payment_transaction.dart';

class PaymentProcessScreen extends StatefulWidget {
  final PaymentTransaction payment;

  const PaymentProcessScreen({super.key, required this.payment});

  @override
  State<PaymentProcessScreen> createState() => _PaymentProcessScreenState();
}

class _PaymentProcessScreenState extends State<PaymentProcessScreen> {
  final PaymentService _paymentService = PaymentService();
  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  late PaymentTransaction _currentPayment;
  Timer? _statusCheckTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _isCheckingStatus = false;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _currentPayment = widget.payment;
    _calculateCountdown();
    _startStatusPolling();
    _savePendingPayment();
  }

  Future<void> _savePendingPayment() async {
    if (_currentPayment.orderId != null && _currentPayment.isPending) {
      appLog('💾 [PaymentProcessScreen] Saving pending payment: ${_currentPayment.orderId}');
      await _paymentService.savePendingPayment(_currentPayment.orderId!);
      appLog('✅ [PaymentProcessScreen] Pending payment saved successfully');
    } else {
      appLog('⚠️ [PaymentProcessScreen] Payment not saved - Order ID: ${_currentPayment.orderId}, Status: ${_currentPayment.status}');
    }
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _calculateCountdown() {
    // Use expiredAt field directly or fall back to metadata
    DateTime? expiryTime;

    if (_currentPayment.expiredAt != null) {
      expiryTime = _currentPayment.expiredAt;
    } else if (_currentPayment.metadata != null &&
        _currentPayment.metadata!['expiry_time'] != null) {
      try {
        expiryTime = DateTime.parse(_currentPayment.metadata!['expiry_time']);
      } catch (e) {
        // Ignore parse error
      }
    }

    if (expiryTime != null) {
      final now = DateTime.now();
      _secondsRemaining = expiryTime.difference(now).inSeconds;

      if (_secondsRemaining > 0) {
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _secondsRemaining--;
            if (_secondsRemaining <= 0) {
              timer.cancel();
            }
          });
        });
      }
    }
  }

  void _startStatusPolling() {
    // Check status every 5 seconds
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_isCheckingStatus) return;
    if (_currentPayment.isSuccess || _currentPayment.isFailed) {
      _statusCheckTimer?.cancel();
      return;
    }

    setState(() {
      _isCheckingStatus = true;
    });

    try {
      final updatedPayment = await _paymentService.checkPaymentStatus(
        _currentPayment.orderId!,
      );

      if (!mounted) return;

      setState(() {
        _currentPayment = updatedPayment;
        _isCheckingStatus = false;
      });

      // Show success dialog if payment is successful
      if (_currentPayment.isSuccess) {
        _statusCheckTimer?.cancel();
        await _paymentService.clearPendingPayment();
        _showSuccessDialog();
      } else if (_currentPayment.isFailed) {
        _statusCheckTimer?.cancel();
        await _paymentService.clearPendingPayment();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => _onBackPressed(),
        ),
        title: Text(
          'Menunggu Pembayaran',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status banner
            _buildStatusBanner(),

            const SizedBox(height: 12),

            // Payment details based on type
            if (_currentPayment.paymentType == 'va' ||
                _currentPayment.paymentType == 'bank_transfer')
              _buildVACard()
            else if (_currentPayment.paymentType == 'qris')
              _buildQRISCard()
            else if (_currentPayment.paymentType == 'ewallet' ||
                _currentPayment.paymentType == 'gopay' ||
                _currentPayment.paymentType == 'shopeepay')
              _buildEWalletCard(),

            const SizedBox(height: 12),

            // Instructions
            _buildInstructions(),
            const SizedBox(height: 16),

            // Sandbox Simulator Card
            if (_currentPayment.isPending)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA5D6A7), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.science, color: Color(0xFF2E7D32), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Mode Sandbox / Uji Coba',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tekan tombol di bawah untuk langsung memverifikasi pembayaran berhasil dan melunasi tagihan.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSimulating ? null : _simulatePaymentSuccess,
                        icon: _isSimulating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle, color: Colors.white),
                        label: Text(
                          _isSimulating
                              ? 'Memproses Pembayaran...'
                              : 'Simulasikan Pembayaran Berhasil',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStatusBanner() {
    Color bgColor;
    String statusText;
    IconData icon;

    if (_currentPayment.isSuccess) {
      bgColor = Colors.green.shade600;
      statusText = 'Pembayaran Berhasil!';
      icon = Icons.check_circle_outline;
    } else if (_currentPayment.isFailed) {
      bgColor = Colors.red.shade600;
      statusText = 'Pembayaran Gagal';
      icon = Icons.error_outline;
    } else {
      bgColor = Colors.orange.shade600;
      statusText = 'Menunggu Pembayaran';
      icon = Icons.hourglass_empty;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(color: bgColor),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 42),
          const SizedBox(height: 10),
          Text(
            statusText,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            currencyFormat.format(_currentPayment.amount),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_secondsRemaining > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Berlaku hingga: ${_formatCountdown(_secondsRemaining)}',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVACard() {
    final va = _currentPayment.virtualAccount;
    if (va == null || va.vaNumber == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance,
                  color: Colors.blue.shade700,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${va.bank?.toUpperCase()} Virtual Account',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Transfer ke nomor VA di bawah',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nomor Virtual Account',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    InkWell(
                      onTap: () => _copyToClipboard(va.vaNumber!),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy,
                              color: Colors.blue.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Salin',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  va.vaNumber!,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRISCard() {
    if (_currentPayment.qrisString == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Text(
            'Scan QR Code',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: QrImageView(
              data: _currentPayment.qrisString!,
              version: QrVersions.auto,
              size: 250,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Gunakan aplikasi mobile banking atau e-wallet untuk scan',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEWalletCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Icon(
            Icons.account_balance_wallet,
            size: 64,
            color: Colors.blue.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            '${_currentPayment.paymentChannel?.toUpperCase()}',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Klik tombol di bawah untuk melanjutkan pembayaran',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_currentPayment.deeplink != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openDeeplink(_currentPayment.deeplink!),
                icon: const Icon(Icons.open_in_new, color: Colors.white),
                label: Text(
                  'Buka ${_currentPayment.paymentChannel?.toUpperCase()}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    List<String> instructions = [];

    if (_currentPayment.paymentType == 'va' ||
        _currentPayment.paymentType == 'bank_transfer') {
      instructions = [
        'Buka aplikasi mobile banking atau ATM',
        'Pilih menu Transfer / Transfer ke Virtual Account',
        'Masukkan nomor Virtual Account',
        'Masukkan nominal sesuai tagihan',
        'Konfirmasi pembayaran',
      ];
    } else if (_currentPayment.paymentType == 'qris') {
      instructions = [
        'Buka aplikasi mobile banking atau e-wallet',
        'Pilih menu Scan QR atau QRIS',
        'Scan QR Code di atas',
        'Konfirmasi pembayaran',
      ];
    } else if (_currentPayment.paymentType == 'ewallet' ||
        _currentPayment.paymentType == 'gopay' ||
        _currentPayment.paymentType == 'shopeepay') {
      instructions = [
        'Klik tombol untuk membuka aplikasi',
        'Login ke akun ${_currentPayment.paymentChannel}',
        'Konfirmasi pembayaran',
        'Selesai',
      ];
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            'Cara Pembayaran',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...instructions.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        entry.value,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_isCheckingStatus)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                onPressed: _checkPaymentStatus,
                icon: const Icon(Icons.refresh, size: 22),
                tooltip: 'Refresh Status',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: ${_getStatusText(_currentPayment.status)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    'Otomatis diperbarui setiap 5 detik',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (_currentPayment.isPending)
              TextButton(
                onPressed: _cancelPayment,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Batalkan',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            if (_currentPayment.isSuccess)
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  'Selesai',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _simulatePaymentSuccess() async {
    if (_currentPayment.orderId == null) return;
    setState(() => _isSimulating = true);

    try {
      final success = await _paymentService.simulatePayment(_currentPayment.orderId!);
      if (success) {
        await _checkPaymentStatus();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal menjalankan simulasi pembayaran',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error simulasi: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSimulating = false);
      }
    }
  }

  Future<void> _cancelPayment() async {
    // Validate orderId
    if (_currentPayment.orderId == null || _currentPayment.orderId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order ID tidak ditemukan',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Batalkan Pembayaran?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Anda yakin ingin membatalkan pembayaran ini? Pembayaran yang sudah dibatalkan tidak dapat diaktifkan kembali.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Tidak',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: Text(
              'Ya, Batalkan',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
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
                'Membatalkan pembayaran...',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final success = await _paymentService.cancelPayment(
        _currentPayment.orderId!,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      if (success) {
        // Stop polling
        _statusCheckTimer?.cancel();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pembayaran berhasil dibatalkan',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );

        // Go back to home
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        throw Exception('Gagal membatalkan pembayaran');
      }
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog if still open
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatCountdown(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'settlement':
      case 'success':
        return 'Berhasil';
      case 'failed':
        return 'Gagal';
      case 'expired':
        return 'Kedaluwarsa';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nomor disalin: $text'),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openDeeplink(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Tidak dapat membuka aplikasi';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 64),
            const SizedBox(height: 16),
            Text(
              'Pembayaran Berhasil!',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          'Pembayaran Anda telah dikonfirmasi. Tagihan sudah lunas.',
          style: GoogleFonts.poppins(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Kembali ke Beranda',
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

  Future<bool> _onBackPressed() async {
    if (_currentPayment.isSuccess) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return false;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Keluar dari Pembayaran?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Pembayaran Anda masih dalam proses. Yakin ingin keluar?',
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
              backgroundColor: Colors.red.shade600,
            ),
            child: Text(
              'Keluar',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return false;

    if (shouldExit == true) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return false;
    }
    return false;
  }
}
