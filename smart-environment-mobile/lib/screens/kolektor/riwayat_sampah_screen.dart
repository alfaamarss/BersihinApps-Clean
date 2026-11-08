import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/api_config.dart';

class RiwayatSampahScreen extends StatelessWidget {
  final Map<String, dynamic> pickupData;

  const RiwayatSampahScreen({super.key, required this.pickupData});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
      pickupData['items'] ?? [],
    );

    // Get photo URL and convert to full URL if needed
    var photoUrl = pickupData['image'] as String?;
    debugPrint('📷 [RiwayatSampah] Original photo URL: $photoUrl');

    if (photoUrl != null &&
        photoUrl.isNotEmpty &&
        !photoUrl.startsWith('http') &&
        !photoUrl.startsWith('assets')) {
      photoUrl = '${ApiConfig.serverUrl}$photoUrl';
      debugPrint('🔄 [RiwayatSampah] Converted to full URL: $photoUrl');
    }

    // Group items by category
    Map<String, List<Map<String, dynamic>>> groupedItems = {};
    for (var item in items) {
      String category = item['category'] ?? 'Lainnya';
      if (!groupedItems.containsKey(category)) {
        groupedItems[category] = [];
      }
      groupedItems[category]!.add(item);
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Pengambilan Sampah',
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header dengan Icon Check
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pengambilan Sampah',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Label jenis pengambilan
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getPickupTypeColor(),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getPickupTypeLabel(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Photo Section
            Container(
              margin: const EdgeInsets.all(20),
              child: AspectRatio(
                aspectRatio: 4 / 3, // Aspect ratio standar foto
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[200],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildPhotoWidget(photoUrl),
                ),
              ),
            ),

            // Address and ID
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    pickupData['address'] ?? 'Alamat tidak tersedia',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pickupData['idPengambilan'] ?? '#ID000000',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Waktu Pengambilan
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waktu Pengambilan',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    pickupData['date'] ?? 'Tanggal tidak tersedia',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Sampah Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sampah',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sampah Items by Category
                  for (var entry in groupedItems.entries) ...[
                    // Category Header
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Sampah ${entry.key}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    // Items in this category
                    for (var item in entry.value)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['name'] ?? 'Item tidak diketahui',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${item['quantity'] ?? 0}x',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),
                  ],

                  // Total Items
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
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
                          '${_getTotalQuantity(items)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoWidget(String? photoUrl) {
    debugPrint('🖼️ [RiwayatSampah] Building photo widget with URL: $photoUrl');

    if (photoUrl == null || photoUrl.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image, size: 50, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              'Tidak ada foto',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Check if it's an asset image
    if (photoUrl.startsWith('assets/')) {
      return Image.asset(
        photoUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'Foto tidak ditemukan',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      );
    }

    // Network image
    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          debugPrint('✅ [RiwayatSampah] Image loaded successfully');
          return child;
        }
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('❌ [RiwayatSampah] Image load error: $error');
        debugPrint('❌ [RiwayatSampah] URL was: $photoUrl');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, size: 50, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'Gagal memuat foto',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  error.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _getTotalQuantity(List<Map<String, dynamic>> items) {
    int total = 0;
    for (var item in items) {
      total += (item['quantity'] as int? ?? 0);
    }
    return total;
  }

  /// Get pickup type label
  String _getPickupTypeLabel() {
    // Check if it's a complaint
    final pickupType = pickupData['pickup_type']?.toString().toLowerCase();
    if ((pickupData.containsKey('type') && pickupData['type'] != null) || pickupType == 'complaint') {
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

  /// Get pickup type color
  Color _getPickupTypeColor() {
    // Check if it's a complaint
    final pickupType = pickupData['pickup_type']?.toString().toLowerCase();
    if ((pickupData.containsKey('type') && pickupData['type'] != null) || pickupType == 'complaint') {
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
}
