import 'dart:convert';
import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> addTestRiwayatPembayaran() async {
  // Mock SharedPreferences untuk testing
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  
  // Data test untuk riwayat pembayaran
  final testData = {
    'id': 'TEST_001',
    'namaKolektor': 'Kolektor Test',
    'alamat': 'Jl. Test No. 123',
    'items': [
      {
        'category': 'Organik',
        'size': 'Sedang',
        'quantity': 2,
        'price': 10000.0,
        'total': 20000.0
      }
    ],
    'totalHarga': 20000.0,
    'tanggalPengambilan': DateTime.now().toIso8601String(),
    'status': 'Selesai',
    'metodePembayaran': 'Tunai',
    'createdAt': DateTime.now().toIso8601String(),
  };
  
  final existingData = prefs.getStringList('riwayat_pembayaran') ?? [];
  existingData.insert(0, jsonEncode(testData));
  await prefs.setStringList('riwayat_pembayaran', existingData);
  
  appLog('Test data added successfully!');
}

void main() {
  testWidgets('Test add riwayat pembayaran', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await addTestRiwayatPembayaran();
  });
}