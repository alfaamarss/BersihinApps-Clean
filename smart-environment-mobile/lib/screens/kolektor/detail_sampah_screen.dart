import 'package:beresin_app/utils/app_log.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/api_config.dart';
import 'tagihan_pembayaran_screen.dart';
import '../../services/pickup_service.dart';
import '../../services/collector_off_schedule_pickup_service.dart';

class DetailSampahScreen extends StatefulWidget {
  final int pickupId;
  final String userName;
  final String address;
  final String idPengambilan;
  final Map<String, List<Map<String, dynamic>>> selectedSampah;
  final XFile imageFile;
  final bool isOffSchedule;

  const DetailSampahScreen({
    super.key,
    required this.pickupId,
    required this.userName,
    required this.address,
    required this.idPengambilan,
    required this.selectedSampah,
    required this.imageFile,
    this.isOffSchedule = false,
  });

  @override
  State<DetailSampahScreen> createState() => _DetailSampahScreenState();
}

class _DetailSampahScreenState extends State<DetailSampahScreen> {
  final int _currentStep = 2; // Still in Input Kantong Progress
  late Map<String, List<Map<String, dynamic>>> _editableSelectedSampah;

  @override
  void initState() {
    super.initState();
    // Make a deep copy of selectedSampah to make it editable
    _editableSelectedSampah = {};
    widget.selectedSampah.forEach((category, items) {
      _editableSelectedSampah[category] = items
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    });
  }

  List<Map<String, dynamic>> _getSelectedItems() {
    List<Map<String, dynamic>> selectedItems = [];

    _editableSelectedSampah.forEach((category, items) {
      for (var item in items) {
        if ((item['quantity'] as int) > 0) {
          selectedItems.add({
            'category': category,
            'name': item['name'],
            'quantity': item['quantity'],
            'price': item['price'],
            'total': (item['quantity'] as int) * (item['price'] as double),
            'waste_id': item['waste_id'],
            'pocket_size_id': item['pocket_size_id'],
          });
        }
      }
    });

    return selectedItems;
  }

  void _editItem(Map<String, dynamic> item, int itemIndex) {
    showDialog(
      context: context,
      builder: (context) {
        int tempQuantity = item['quantity'] as int;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Edit Jumlah',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item['name'],
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Decrease button
                      IconButton(
                        onPressed: () {
                          if (tempQuantity > 1) {
                            setDialogState(() {
                              tempQuantity--;
                            });
                          }
                        },
                        icon: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.remove, color: Colors.grey),
                        ),
                      ),

                      // Quantity display
                      Container(
                        width: 80,
                        alignment: Alignment.center,
                        child: Text(
                          '$tempQuantity',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      // Increase button
                      IconButton(
                        onPressed: () {
                          setDialogState(() {
                            tempQuantity++;
                          });
                        },
                        icon: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF009688),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Total: Rp ${(tempQuantity * (item['price'] as double)).toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF009688),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // Update quantity in the editable data
                      String category = item['category'];
                      _editableSelectedSampah[category]!.firstWhere(
                        (i) =>
                            i['waste_id'] == item['waste_id'] &&
                            i['pocket_size_id'] == item['pocket_size_id'],
                      )['quantity'] = tempQuantity;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Simpan',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double _getTotalPrice() {
    double total = 0;
    List<Map<String, dynamic>> items = _getSelectedItems();
    for (var item in items) {
      total += item['total'] as double;
    }
    return total;
  }

  String _getCategoryTag(String category) {
    return category; // Return the actual category (Organik/Anorganik)
  }

  Future<void> _konfirmasi() async {
    final selectedItems = _getSelectedItems();

    // Show loading
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
                'Menyimpan data...',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      appLog('🔄 [DetailSampah] Starting to submit...');
      appLog('📷 [DetailSampah] Image name: ${widget.imageFile.name}');
      appLog('🏷️ [DetailSampah] isOffSchedule: ${widget.isOffSchedule}');

      // Convert image to base64 (support web & mobile)
      final imageBytes = await widget.imageFile.readAsBytes();
      appLog('📦 [DetailSampah] Image bytes: ${imageBytes.length}');

      final base64Image = base64Encode(imageBytes);
      appLog(
        '🔐 [DetailSampah] Base64 encoded: ${base64Image.substring(0, 50)}...',
      );

      // Prepare waste items for API
      final wasteItems = selectedItems.map((item) {
        return {
          'waste_id': item['waste_id'],
          'pocket_size_id': item['pocket_size_id'],
          'quantity': item['quantity'],
        };
      }).toList();

      appLog('📋 [DetailSampah] Waste items: $wasteItems');
      appLog('🚀 [DetailSampah] Calling API...');

      bool success;
      String? message;
      Map<String, dynamic>? data;

      // Use different service based on pickup type
      if (widget.isOffSchedule) {
        // Off-schedule pickup - use CollectorOffSchedulePickupService
        appLog('🔄 [DetailSampah] Using OFF-SCHEDULE pickup service');
        try {
          final offScheduleService = CollectorOffSchedulePickupService();
          data = await offScheduleService.completePickup(
            id: widget.pickupId,
            photoBase64: base64Image,
            wasteItems: wasteItems,
          );
          success = true;
          message = null;
          appLog('✅ [DetailSampah] Off-schedule complete SUCCESS');
        } catch (e) {
          success = false;
          message = e.toString().replaceAll('Exception: ', '');
          appLog('❌ [DetailSampah] Off-schedule complete FAILED: $message');
        }
      } else {
        // Regular pickup - use PickupService
        appLog('🔄 [DetailSampah] Using REGULAR pickup service');
        final result = await PickupService.completePickup(
          id: widget.pickupId,
          photo: base64Image,
          wasteItems: wasteItems,
        );
        success = result.$1;
        message = result.$2;
        data = result.$3;
      }

      appLog(
        '✅ [DetailSampah] API Response - Success: $success, Message: $message',
      );
      appLog('📷 [DetailSampah] Photo URL from API: ${data?['photo_url']}');

      // Close loading
      if (mounted) Navigator.of(context).pop();

      if (success) {
        // Navigate to Pembayaran screen with API response data
        if (mounted) {
          // Parse total_amount safely - handle both int, double, and String
          double totalAmount;
          if (data?['total_amount'] != null) {
            final totalValue = data!['total_amount'];
            if (totalValue is int) {
              totalAmount = totalValue.toDouble();
            } else if (totalValue is double) {
              totalAmount = totalValue;
            } else if (totalValue is String) {
              totalAmount = double.tryParse(totalValue) ?? _getTotalPrice();
            } else {
              totalAmount = _getTotalPrice();
            }
          } else {
            totalAmount = _getTotalPrice();
          }

          // Convert photo URL to full URL if needed
          var photoUrl = data?['photo_url'] as String?;
          if (photoUrl != null &&
              photoUrl.isNotEmpty &&
              !photoUrl.startsWith('http')) {
            photoUrl = '${ApiConfig.serverUrl}$photoUrl';
            appLog('🔄 [DetailSampah] Converted photo URL to: $photoUrl');
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TagihanPembayaranScreen(
                userName: widget.userName,
                address: widget.address,
                idPengambilan: widget.idPengambilan,
                selectedItems: selectedItems,
                totalPrice: totalAmount,
                photoUrl: photoUrl,
                imageFile: widget.imageFile,
              ),
            ),
          );
        }
      } else {
        // Show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message ?? 'Gagal menyimpan data'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      appLog('💥 [DetailSampah] Exception: $e');
      appLog('💥 [DetailSampah] StackTrace: $stackTrace');

      // Close loading if still open
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildProgressStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _buildStepItem(0, 'Datang', 'Selesai'),
          _buildStepLine(0),
          _buildStepItem(1, 'Foto', 'Selesai'),
          _buildStepLine(1),
          _buildStepItem(2, 'Input Kantong', 'Progress'),
          _buildStepLine(2),
          _buildStepItem(3, 'Selesai', 'Pending'),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String title, String status) {
    Color circleColor;
    Color textColor;

    if (step < _currentStep) {
      circleColor = const Color(0xFF009688);
      textColor = const Color(0xFF009688);
    } else if (step == _currentStep) {
      circleColor = const Color(0xFF009688);
      textColor = const Color(0xFF009688);
    } else {
      circleColor = Colors.grey[300]!;
      textColor = Colors.grey[500]!;
    }

    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
          child: step < _currentStep
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        Text(
          status,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    bool isCompleted = step < _currentStep;

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 40),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFF009688) : Colors.grey[300],
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedItems = _getSelectedItems();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Detail Sampah',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress Stepper
          Container(color: Colors.white, child: _buildProgressStepper()),

          // Section Title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              'Jenis Sampah',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),

          // Items List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: selectedItems.length,
              itemBuilder: (context, index) {
                final item = selectedItems[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      // Category Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item['category'] == 'Organik'
                              ? Colors.green[600]
                              : Colors.blue[600],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getCategoryTag(item['category']),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Item Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '${item['category']}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Biaya',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Edit Button
                      GestureDetector(
                        onTap: () => _editItem(item, index),
                        child: Text(
                          'Edit',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF009688),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Weight and Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rp ${(item['price'] as double).toStringAsFixed(0)} / kantong',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${item['quantity']} kantong',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Rp ${(item['total'] as double).toStringAsFixed(0)}',
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
                );
              },
            ),
          ),

          // Detail Pengambilan Section
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Pengangkutan',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ongkos Sampah Organik',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Rp ${_getTotalPrice().toInt()}',
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

          // Konfirmasi Button
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _konfirmasi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Konfirmasi',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
