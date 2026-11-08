import 'package:beresin_app/utils/app_log.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../models/payment_transaction.dart';

class PaymentService {
  final Dio _dio = ApiClient.instance.dio;
  static const String _pendingPaymentKey = 'pending_payment_order_id';

  /// Create new payment transaction
  /// 
  /// Parameters:
  /// - invoiceIds: List of invoice IDs to pay
  /// - paymentType: 'virtual_account', 'qris', or 'ewallet'
  /// - paymentChannel: Specific channel (e.g., 'bca', 'gopay', 'shopeepay')
  Future<PaymentTransaction> createPayment({
    required List<int> invoiceIds,
    required String paymentType,
    String? paymentChannel,
  }) async {
    try {
      final response = await _dio.post(
        '/mobile/resident/payments/create',
        data: {
          'invoice_ids': invoiceIds,
          'payment_type': paymentType,
          if (paymentChannel != null) 'payment_channel': paymentChannel,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && 
          response.data['success'] == true) {
        // Backend returns payment data directly in 'payment' key
        final paymentData = response.data['payment'];
        return PaymentTransaction.fromJson(paymentData);
      }

      throw Exception(response.data['message'] ?? 'Failed to create payment');
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final data = e.response!.data;
        
        // Handle authentication error
        if (statusCode == 401) {
          throw Exception('Sesi Anda telah berakhir. Silakan login kembali.');
        }
        
        // Handle validation errors
        if (statusCode == 422 && data is Map) {
          final errors = data['errors'] as Map?;
          if (errors != null && errors.isNotEmpty) {
            final firstError = errors.values.first;
            throw Exception(firstError is List ? firstError.first : firstError.toString());
          }
        }
        
        // Handle other errors
        final message = data is Map ? (data['message'] ?? 'Payment creation failed') : 'Payment creation failed';
        throw Exception(message);
      }
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error creating payment: $e');
    }
  }

  /// Simulate payment success (Sandbox mode)
  Future<bool> simulatePayment(String orderId) async {
    try {
      final response = await _dio.post(
        '/mobile/resident/payments/$orderId/simulate-pay',
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      appLog('Error simulating payment: $e');
      return false;
    }
  }

  /// Check payment status
  Future<PaymentTransaction> checkPaymentStatus(String orderId) async {
    try {
      final response = await _dio.get(
        '/mobile/resident/payments/$orderId/status',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return PaymentTransaction.fromJson(response.data['payment']);
      }

      throw Exception('Failed to check payment status');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['message'] ?? 'Status check failed');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error checking payment status: $e');
    }
  }

  /// Get payment detail
  Future<PaymentTransaction> getPaymentDetail(int paymentId) async {
    try {
      final response = await _dio.get(
        '/mobile/resident/payments/$paymentId',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return PaymentTransaction.fromJson(response.data['data']['payment']);
      }

      throw Exception('Failed to get payment detail');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response!.data['message'] ?? 'Failed to load payment');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting payment detail: $e');
    }
  }

  /// Get available payment methods
  /// This returns static list for now, but can be made dynamic from API
  List<PaymentMethod> getAvailablePaymentMethods() {
    return [
      PaymentMethod(
        id: 'va',
        name: 'Virtual Account',
        type: 'va',
        channels: [
          PaymentChannel(
            id: 'bca',
            name: 'BCA Virtual Account',
            description: 'Transfer via ATM/Mobile Banking BCA',
          ),
          PaymentChannel(
            id: 'bni',
            name: 'BNI Virtual Account',
            description: 'Transfer via ATM/Mobile Banking BNI',
          ),
          PaymentChannel(
            id: 'bri',
            name: 'BRI Virtual Account',
            description: 'Transfer via ATM/Mobile Banking BRI',
          ),
          PaymentChannel(
            id: 'permata',
            name: 'Permata Virtual Account',
            description: 'Transfer via ATM/Mobile Banking Permata',
          ),
        ],
      ),
      PaymentMethod(
        id: 'qris',
        name: 'QRIS',
        type: 'qris',
      ),
      PaymentMethod(
        id: 'ewallet',
        name: 'E-Wallet',
        type: 'ewallet',
        channels: [
          PaymentChannel(
            id: 'gopay',
            name: 'GoPay',
            description: 'Bayar dengan GoPay',
          ),
          PaymentChannel(
            id: 'shopeepay',
            name: 'ShopeePay',
            description: 'Bayar dengan ShopeePay',
          ),
        ],
      ),
    ];
  }

  /// Cancel payment
  Future<bool> cancelPayment(String orderId) async {
    try {
      final response = await _dio.post(
        '/mobile/resident/payments/$orderId/cancel',
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && 
          response.data['success'] == true) {
        return true;
      }

      throw Exception(response.data['message'] ?? 'Failed to cancel payment');
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final data = e.response!.data;
        
        // Handle specific errors
        if (statusCode == 400) {
          throw Exception(data['message'] ?? 'Payment cannot be cancelled');
        }
        
        final message = data is Map ? (data['message'] ?? 'Failed to cancel payment') : 'Failed to cancel payment';
        throw Exception(message);
      }
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error cancelling payment: $e');
    }
  }

  /// Get pending payments from API (payments with status 'pending')
  Future<List<PaymentTransaction>> getPendingPaymentsFromAPI() async {
    try {
      final response = await _dio.get(
        '/mobile/resident/payments/pending',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final payments = response.data['data']['payments'] as List?;
        if (payments != null) {
          return payments
              .map((p) => PaymentTransaction.fromJson(p))
              .toList();
        }
      }
      return [];
    } catch (e) {
      appLog('❌ [PaymentService] Error getting pending payments from API: $e');
      return [];
    }
  }

  /// Save pending payment order ID to local storage
  Future<void> savePendingPayment(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingPaymentKey, orderId);
  }

  /// Get pending payment order ID from local storage
  Future<String?> getPendingPaymentOrderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingPaymentKey);
  }

  /// Clear pending payment from local storage
  Future<void> clearPendingPayment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingPaymentKey);
  }

  /// Check if there's a pending payment and get its details
  /// This will check both local storage AND API to find any pending payments
  Future<PaymentTransaction?> checkPendingPayment() async {
    try {
      // STEP 1: Check local storage first (faster)
      final orderId = await getPendingPaymentOrderId();
      appLog('🔍 [PaymentService] Checking pending payment. Local Order ID: $orderId');
      
      if (orderId != null && orderId.isNotEmpty) {
        appLog('📡 [PaymentService] Fetching payment status for order: $orderId');
        try {
          // Check payment status from API
          final payment = await checkPaymentStatus(orderId);
          appLog('📊 [PaymentService] Payment status: ${payment.status}');

          // Clear pending if payment is completed or failed
          if (payment.isSuccess || payment.isFailed) {
            appLog('🗑️ [PaymentService] Payment is ${payment.status}, clearing pending payment');
            await clearPendingPayment();
            // Continue to check API for other pending payments
          } else if (payment.isPending) {
            appLog('⏳ [PaymentService] Found pending payment from local: ${payment.orderId}');
            return payment;
          }
        } catch (e) {
          appLog('⚠️ [PaymentService] Local payment not found or invalid: $e');
          await clearPendingPayment();
          // Continue to check API
        }
      }

      // STEP 2: Check API for any pending payments (in case local storage is empty or outdated)
      appLog('📡 [PaymentService] Checking pending payments from API...');
      final pendingPayments = await getPendingPaymentsFromAPI();
      
      if (pendingPayments.isNotEmpty) {
        // Get the most recent pending payment
        final latestPending = pendingPayments.first;
        appLog('⏳ [PaymentService] Found pending payment from API: ${latestPending.orderId}');
        
        // Save to local storage for next time
        if (latestPending.orderId != null) {
          await savePendingPayment(latestPending.orderId!);
          appLog('💾 [PaymentService] Saved pending payment to local storage');
        }
        
        return latestPending;
      }

      appLog('✅ [PaymentService] No pending payments found');
      return null;
    } catch (e) {
      appLog('❌ [PaymentService] Error checking pending payment: $e');
      return null;
    }
  }
}
