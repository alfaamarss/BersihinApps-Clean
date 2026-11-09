import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../models/complaint.dart';
import '../../services/collector_complaint_service.dart';
import '../../services/token_storage.dart';

class CollectorComplaintDetailScreen extends StatefulWidget {
  final Complaint complaint;

  const CollectorComplaintDetailScreen({super.key, required this.complaint});

  @override
  State<CollectorComplaintDetailScreen> createState() =>
      _CollectorComplaintDetailScreenState();
}

class _CollectorComplaintDetailScreenState
    extends State<CollectorComplaintDetailScreen> {
  final CollectorComplaintService _complaintService =
      CollectorComplaintService();
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isUpdating = false;
  bool _isLoadingDetail = true;
  Complaint? _detailedComplaint;
  Map<String, dynamic>? _serviceAccountData;
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadComplaintDetail();
  }

  Future<void> _loadComplaintDetail() async {
    setState(() {
      _isLoadingDetail = true;
    });

    try {
      final detailedComplaint = await _complaintService.getComplaintDetail(
        widget.complaint.id,
      );

      // Debug logging - PRINT FULL RESPONSE
      debugPrint('🔍 [CollectorDetail] ========== COMPLAINT DETAIL ==========');
      debugPrint(
        '   - Service Account ID: ${detailedComplaint.serviceAccountId}',
      );
      debugPrint('   - Photos count: ${detailedComplaint.photos.length}');
      for (var photo in detailedComplaint.photos) {
        debugPrint('   - Photo ID: ${photo.id}, URL: ${photo.url}');
      }
      debugPrint('   - Reporter data: ${detailedComplaint.reporter}');
      debugPrint(
        '   - Reporter keys: ${detailedComplaint.reporter?.keys.toList()}',
      );
      if (detailedComplaint.reporter != null) {
        debugPrint(
          '   - Reporter name: ${detailedComplaint.reporter!['name']}',
        );
        debugPrint(
          '   - Reporter photo: ${detailedComplaint.reporter!['photo']}',
        );
        debugPrint(
          '   - Reporter email: ${detailedComplaint.reporter!['email']}',
        );
        debugPrint('   - Reporter id: ${detailedComplaint.reporter!['id']}');
      }
      debugPrint('========================================');

      // Try to load service account data if service_account_id exists
      if (detailedComplaint.serviceAccountId != null &&
          detailedComplaint.serviceAccountId!.isNotEmpty) {
        await _loadServiceAccountData(detailedComplaint.serviceAccountId!);
      }

      setState(() {
        _detailedComplaint = detailedComplaint;
        _isLoadingDetail = false;
      });
    } catch (e) {
      debugPrint('❌ [CollectorDetail] Error: $e');
      setState(() {
        _detailedComplaint = widget.complaint; // Fallback to initial data
        _isLoadingDetail = false;
      });
    }
  }

  Future<void> _loadServiceAccountData(String serviceAccountId) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/mobile/collector/service-accounts/$serviceAccountId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('📡 [ServiceAccount] Response: $data');

        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _serviceAccountData =
                data['data']['service_account'] ?? data['data'];
          });
          debugPrint('✅ [ServiceAccount] Loaded: $_serviceAccountData');
          if (_serviceAccountData != null) {
            debugPrint('   - Name: ${_serviceAccountData!['name']}');
            debugPrint('   - Photo: ${_serviceAccountData!['photo']}');
          }
        }
      } else {
        debugPrint('❌ [ServiceAccount] Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [ServiceAccount] Exception: $e');
      // Non-critical error, continue without service account data
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Complaint get _currentComplaint => _detailedComplaint ?? widget.complaint;

  Color _getStatusColor() {
    switch (_currentComplaint.status.toLowerCase()) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Gagal mengambil foto: $e');
    }
  }

  /// Tampilkan foto dalam layar penuh
  void _showFullScreenPhoto(String photoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('Foto Bukti', style: GoogleFonts.poppins()),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                photoUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image,
                          size: 64,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Foto tidak dapat dimuat',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    // Validation
    if (newStatus == 'resolved' && _selectedImage == null) {
      _showErrorSnackBar('Foto bukti wajib untuk menyelesaikan pelaporan');
      return;
    }

    final confirm = await _showConfirmDialog(
      'Update Status',
      'Apakah Anda yakin ingin mengubah status menjadi ${_getStatusText(newStatus)}?',
    );

    if (!confirm) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await _complaintService.updateComplaintStatus(
        complaintId: _currentComplaint.id,
        status: newStatus,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        photo: _selectedImage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status berhasil diupdate',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate update
      }
    } catch (e) {
      _showErrorSnackBar('Gagal update status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return 'Menunggu';
      case 'in_progress':
        return 'Diproses';
      case 'resolved':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 21, 145, 137),
            ),
            child: Text('Ya', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while fetching detailed data
    if (_isLoadingDetail) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            'Detail Pelaporan',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 21, 145, 137),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 21, 145, 137),
          ),
        ),
      );
    }

    // Priority 1: Use service account data if available
    String reporterName = 'Nama tidak tersedia';
    String reporterPhone = 'Nomor tidak tersedia';
    String reporterAddress = 'Alamat tidak tersedia';
    String? reporterPhoto;

    if (_serviceAccountData != null) {
      reporterName = _serviceAccountData!['name']?.toString() ?? reporterName;
      reporterPhone =
          _serviceAccountData!['contact_phone']?.toString() ??
          _serviceAccountData!['phone']?.toString() ??
          _serviceAccountData!['contact_number']?.toString() ??
          _serviceAccountData!['phone_number']?.toString() ??
          reporterPhone;
      reporterAddress =
          _serviceAccountData!['address']?.toString() ??
          _serviceAccountData!['alamat']?.toString() ??
          reporterAddress;

      // Try multiple field names for photo
      reporterPhoto =
          _serviceAccountData!['photo']?.toString() ??
          _serviceAccountData!['foto']?.toString() ??
          _serviceAccountData!['profile_picture']?.toString() ??
          _serviceAccountData!['avatar']?.toString() ??
          _serviceAccountData!['image']?.toString() ??
          _serviceAccountData!['profile_photo']?.toString();

      debugPrint('🖼️ [ServiceAccount] Photo field check:');
      debugPrint('   - photo: ${_serviceAccountData!['photo']}');
      debugPrint('   - foto: ${_serviceAccountData!['foto']}');
      debugPrint(
        '   - profile_picture: ${_serviceAccountData!['profile_picture']}',
      );
      debugPrint('   - avatar: ${_serviceAccountData!['avatar']}');
      debugPrint('   - All keys: ${_serviceAccountData!.keys.toList()}');
    }
    // Priority 2: Use complaint.reporter if service account not available
    else if (_currentComplaint.reporter != null) {
      reporterName =
          _currentComplaint.reporter?['name']?.toString() ?? reporterName;
      reporterPhone =
          _currentComplaint.reporter?['phone']?.toString() ??
          _currentComplaint.reporter?['contact_phone']?.toString() ??
          reporterPhone;
      reporterAddress =
          _currentComplaint.reporter?['address']?.toString() ?? reporterAddress;

      // Try multiple field names for photo
      reporterPhoto =
          _currentComplaint.reporter?['photo']?.toString() ??
          _currentComplaint.reporter?['foto']?.toString() ??
          _currentComplaint.reporter?['profile_picture']?.toString() ??
          _currentComplaint.reporter?['avatar']?.toString() ??
          _currentComplaint.reporter?['image']?.toString() ??
          _currentComplaint.reporter?['profile_photo']?.toString();

      debugPrint('🖼️ [Complaint.reporter] Photo field check:');
      debugPrint('   - photo: ${_currentComplaint.reporter?['photo']}');
      debugPrint('   - foto: ${_currentComplaint.reporter?['foto']}');
      debugPrint('   - All keys: ${_currentComplaint.reporter?.keys.toList()}');
    }

    // Fix photo URL if it's relative path
    if (reporterPhoto != null &&
        reporterPhoto.isNotEmpty &&
        !reporterPhoto.startsWith('http')) {
      reporterPhoto = '${ApiConfig.serverUrl}$reporterPhoto';
    }

    // Debug logging
    debugPrint('👤 [UI] Reporter Info:');
    debugPrint('   - Name: $reporterName');
    debugPrint('   - Phone: $reporterPhone');
    debugPrint('   - Photo: $reporterPhoto');
    debugPrint('   - Address: $reporterAddress');

    // Fallback to location
    if (reporterAddress == 'Alamat tidak tersedia' &&
        _currentComplaint.location != null) {
      reporterAddress = _currentComplaint.location!;
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Detail Pelaporan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 21, 145, 137),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Badge
                Container(
                  color: _getStatusColor().withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: _getStatusColor(),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: ${_currentComplaint.statusText}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Complaint Info
                _buildSection(
                  title: 'Informasi Pelaporan',
                  children: [
                    _buildInfoRow(
                      icon: Icons.category_outlined,
                      label: 'Jenis',
                      value: _currentComplaint.typeText,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.access_time,
                      label: 'Tanggal',
                      value: DateFormat(
                        'dd MMMM yyyy, HH:mm',
                      ).format(_currentComplaint.createdAt),
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.description_outlined,
                      label: 'Deskripsi',
                      value: _currentComplaint.description,
                      isMultiline: true,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Reporter Info with Photo
                _buildSection(
                  title: 'Informasi Pelapor',
                  children: [
                    _buildInfoRow(
                      icon: Icons.person_outline,
                      label: 'Nama',
                      value: reporterName,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Telepon',
                      value: reporterPhone,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Alamat',
                      value: reporterAddress,
                      isMultiline: true,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Photos
                if (_currentComplaint.photos.isNotEmpty)
                  _buildSection(
                    title: 'Foto Bukti',
                    children: [
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _currentComplaint.photos.length,
                          itemBuilder: (context, index) {
                            final photo = _currentComplaint.photos[index];
                            // Fix photo URL - tambahkan base URL jika relative path
                            String photoUrl = photo.url;
                            if (photoUrl.isNotEmpty &&
                                !photoUrl.startsWith('http')) {
                              // Hapus leading slash jika ada
                              if (photoUrl.startsWith('/')) {
                                photoUrl = photoUrl.substring(1);
                              }
                              photoUrl = '${ApiConfig.serverUrl}/$photoUrl';
                            }
                            debugPrint('📷 [Photos] Loading photo: $photoUrl');

                            return GestureDetector(
                              onTap: () => _showFullScreenPhoto(photoUrl),
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    photoUrl,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                            color: const Color.fromARGB(
                                              255,
                                              21,
                                              145,
                                              137,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint(
                                        '❌ [Photos] Error loading: $error',
                                      );
                                      return Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.grey[300],
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Gagal',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Update Status Section
                if (_currentComplaint.status.toLowerCase() != 'resolved')
                  _buildSection(
                    title: 'Update Status',
                    children: [
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Catatan (opsional)',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey[400],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 21, 145, 137),
                              width: 2,
                            ),
                          ),
                        ),
                        style: GoogleFonts.poppins(),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedImage != null) ...[
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                kIsWeb
                                    ? Image.network(
                                        _selectedImage!.path,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(_selectedImage!.path),
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedImage = null;
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                            _selectedImage == null
                                ? 'Ambil Foto Bukti'
                                : 'Ganti Foto',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              21,
                              145,
                              137,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_currentComplaint.status.toLowerCase() == 'open')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isUpdating
                                ? null
                                : () => _updateStatus('in_progress'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: Text(
                              'Mulai Proses',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      if (_currentComplaint.status.toLowerCase() ==
                          'in_progress')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isUpdating
                                ? null
                                : () => _updateStatus('resolved'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                21,
                                145,
                                137,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: Text(
                              'Selesaikan',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 100),
              ],
            ),
          ),
          if (_isUpdating)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color.fromARGB(255, 21, 145, 137),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
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
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: const Color.fromARGB(255, 21, 145, 137)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
