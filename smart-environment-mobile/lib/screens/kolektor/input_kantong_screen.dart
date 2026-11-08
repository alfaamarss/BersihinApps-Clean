import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'detail_sampah_screen.dart';
import '../../services/pickup_service.dart';

class InputKantongScreen extends StatefulWidget {
  final int pickupId;
  final String userName;
  final String address;
  final String idPengambilan;
  final XFile imageFile;
  final bool isOffSchedule;

  const InputKantongScreen({
    super.key,
    required this.pickupId,
    required this.userName,
    required this.address,
    required this.idPengambilan,
    required this.imageFile,
    this.isOffSchedule = false,
  });

  @override
  State<InputKantongScreen> createState() => _InputKantongScreenState();
}

class _InputKantongScreenState extends State<InputKantongScreen> {
  final int _currentStep =
      2; // 0: Datang, 1: Foto, 2: Input Kantong (current), 3: Selesai
  String _selectedCategory = 'Organik';
  final TextEditingController _searchController = TextEditingController();

  // Data jenis sampah - akan diload dari API
  Map<String, List<Map<String, dynamic>>> _sampahCategories = {
    'Organik': [],
    'Anorganik': [],
  };

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWasteItems();
  }

  Future<void> _loadWasteItems() async {
    appLog('🔄 [InputKantong] Starting to load waste items...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final (success, message, data) = await PickupService.getWasteItems();
      appLog(
        '📦 [InputKantong] API Response - Success: $success, Message: $message, Data length: ${data?.length}',
      );

      if (mounted) {
        if (success && data != null) {
          appLog('✅ [InputKantong] Processing ${data.length} items...');

          // Group by category
          final organikItems = <Map<String, dynamic>>[];
          final anorganikItems = <Map<String, dynamic>>[];

          for (var item in data) {
            final category = item['waste_category'] as String;

            // Parse price - handle both String and num from API
            final priceValue = item['price'];
            double price;
            if (priceValue is String) {
              price = double.tryParse(priceValue) ?? 0.0;
            } else if (priceValue is num) {
              price = priceValue.toDouble();
            } else {
              price = 0.0;
            }

            final itemData = {
              'name': item['name'],
              'price': price,
              'quantity': 0,
              'waste_id': item['waste_id'],
              'pocket_size_id': item['pocket_size_id'],
            };

            if (category == 'organic') {
              organikItems.add(itemData);
            } else if (category == 'inorganic') {
              anorganikItems.add(itemData);
            }
          }

          appLog(
            '📊 [InputKantong] Grouped - Organik: ${organikItems.length}, Anorganik: ${anorganikItems.length}',
          );

          setState(() {
            _sampahCategories = {
              'Organik': organikItems,
              'Anorganik': anorganikItems,
            };
            _isLoading = false;
          });

          appLog('✅ [InputKantong] Data loaded successfully!');
        } else {
          appLog('❌ [InputKantong] Failed to load: $message');
          setState(() {
            _errorMessage = message ?? 'Gagal memuat data';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      appLog('💥 [InputKantong] Exception: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _incrementQuantity(String category, int index) {
    setState(() {
      _sampahCategories[category]![index]['quantity']++;
    });
  }

  void _decrementQuantity(String category, int index) {
    setState(() {
      if (_sampahCategories[category]![index]['quantity'] > 0) {
        _sampahCategories[category]![index]['quantity']--;
      }
    });
  }

  int _getTotalItems() {
    int total = 0;
    _sampahCategories.forEach((category, items) {
      for (var item in items) {
        total += item['quantity'] as int;
      }
    });
    return total;
  }

  double _getTotalPrice() {
    double total = 0;
    _sampahCategories.forEach((category, items) {
      for (var item in items) {
        total += (item['quantity'] as int) * (item['price'] as double);
      }
    });
    return total;
  }

  Future<void> _lanjutkan() async {
    if (_getTotalItems() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pilih minimal 1 jenis sampah!',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to Detail Sampah screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailSampahScreen(
          pickupId: widget.pickupId,
          userName: widget.userName,
          address: widget.address,
          idPengambilan: widget.idPengambilan,
          selectedSampah: _sampahCategories,
          imageFile: widget.imageFile,
          isOffSchedule: widget.isOffSchedule,
        ),
      ),
    );
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

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: GoogleFonts.poppins(fontSize: 14),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih Jenis Sampah',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _sampahCategories.keys.map((category) {
                bool isSelected = _selectedCategory == category;
                IconData icon;

                switch (category) {
                  case 'Organik':
                    icon = Icons.eco;
                    break;
                  case 'Anorganik':
                    icon = Icons.recycling;
                    break;
                  default:
                    icon = Icons.recycling;
                }

                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF009688)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF009688)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? Colors.white : Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampahList() {
    // Show loading
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    // Show error
    if (_errorMessage != null) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.red[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadWasteItems,
                child: Text('Coba Lagi', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ),
      );
    }

    List<Map<String, dynamic>> items =
        _sampahCategories[_selectedCategory] ?? [];

    // Show empty state
    if (items.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            'Tidak ada data sampah',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _selectedCategory == 'Organik'
                        ? Colors.green[100]
                        : Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item['name'].contains('Kecil')
                        ? Icons.circle_outlined
                        : item['name'].contains('Sedang')
                        ? Icons.circle
                        : Icons.album,
                    color: _selectedCategory == 'Organik'
                        ? Colors.green[600]
                        : Colors.blue[600],
                    size: item['name'].contains('Kecil')
                        ? 16
                        : item['name'].contains('Sedang')
                        ? 20
                        : 24,
                  ),
                ),

                const SizedBox(width: 12),

                // Info
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
                        'Rp ${item['price']} / kantong',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Quantity controls
                Row(
                  children: [
                    // Decrease button
                    GestureDetector(
                      onTap: () => _decrementQuantity(_selectedCategory, index),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.remove,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                    // Quantity
                    Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text(
                        '${item['quantity']}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    // Increase button
                    GestureDetector(
                      onTap: () => _incrementQuantity(_selectedCategory, index),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF009688),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF009688);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Tambah Jenis Sampah',
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
      body: Stack(
        children: [
          // Scrollable content
          Column(
            children: [
              // Progress Stepper
              Container(color: Colors.white, child: _buildProgressStepper()),

              // Search Field
              _buildSearchField(),

              // Category Tabs
              _buildCategoryTabs(),

              const SizedBox(height: 16),

              // Sampah List
              _buildSampahList(),

              // Padding untuk bottom button
              const SizedBox(height: 120),
            ],
          ),

          // Bottom Section with Total and Button (Fixed at bottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Total Info
                  if (_getTotalItems() > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Item: ${_getTotalItems()} kantong',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                              Text(
                                'Estimasi: Rp ${_getTotalPrice().toInt()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.green[600],
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.check_circle,
                            color: Colors.green[600],
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Lanjutkan Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _lanjutkan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Lanjutkan',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
}
