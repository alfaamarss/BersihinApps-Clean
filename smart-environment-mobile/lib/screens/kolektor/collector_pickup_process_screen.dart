import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Screen untuk proses pengambilan sampah oleh kolektor
/// dengan 4 tahap: Datang -> Foto Progress -> Input Kantong -> Selesai
class CollectorPickupProcessScreen extends StatefulWidget {
  final Map<String, dynamic> complaint;

  const CollectorPickupProcessScreen({super.key, required this.complaint});

  @override
  State<CollectorPickupProcessScreen> createState() =>
      _CollectorPickupProcessScreenState();
}

class _CollectorPickupProcessScreenState
    extends State<CollectorPickupProcessScreen> {
  int _currentStep = 0; // 0: Datang, 1: Foto, 2: Input, 3: Selesai
  XFile? _pickupPhoto;
  final ImagePicker _picker = ImagePicker();

  // Data untuk input kantong sampah
  final Map<String, int> _wasteQuantities = {
    'organic_besar': 0,
    'organic_sedang': 0,
    'organic_kecil': 0,
    'anorganic_besar': 0,
    'anorganic_sedang': 0,
    'anorganic_kecil': 0,
  };

  /// Helper method untuk cek apakah complaint memerlukan input kantong
  /// HANYA sampah_tidak_diambil yang perlu input kantong
  /// sampah_menumpuk dan lainnya TIDAK perlu input kantong
  bool _needsBagInput() {
    final type = widget.complaint['type']?.toString().toLowerCase() ?? '';
    return type == 'sampah_tidak_diambil';
  }

  /// Get total steps based on complaint type
  int _getTotalSteps() {
    return _needsBagInput() ? 4 : 3; // 4 steps with bag input, 3 without
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF159189);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Pengambilan Sampah',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress Stepper
          _buildProgressStepper(primaryColor),

          // Content berdasarkan step
          Expanded(child: _buildStepContent(primaryColor)),

          // Bottom Button
          if (_currentStep < _getTotalSteps() - 1)
            _buildBottomButton(primaryColor),
        ],
      ),
    );
  }

  /// Build progress stepper - dynamic based on complaint type
  Widget _buildProgressStepper(Color primaryColor) {
    final needsBagInput = _needsBagInput();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      color: Colors.white,
      child: Row(
        children: [
          _buildStepIndicator(
            step: 0,
            label: 'Datang',
            sublabel: 'Selesai',
            primaryColor: primaryColor,
          ),
          _buildStepConnector(
            isCompleted: _currentStep > 0,
            primaryColor: primaryColor,
          ),
          _buildStepIndicator(
            step: 1,
            label: 'Foto',
            sublabel: 'Progress',
            primaryColor: primaryColor,
          ),
          if (needsBagInput) ...[
            _buildStepConnector(
              isCompleted: _currentStep > 1,
              primaryColor: primaryColor,
            ),
            _buildStepIndicator(
              step: 2,
              label: 'Input Kantong',
              sublabel: 'Pending',
              primaryColor: primaryColor,
            ),
          ],
          _buildStepConnector(
            isCompleted: _currentStep > (needsBagInput ? 2 : 1),
            primaryColor: primaryColor,
          ),
          _buildStepIndicator(
            step: needsBagInput ? 3 : 2,
            label: 'Selesai',
            sublabel: 'Pending',
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator({
    required int step,
    required String label,
    required String sublabel,
    required Color primaryColor,
  }) {
    final isCompleted = _currentStep > step;
    final isCurrent = _currentStep == step;

    Color circleColor;
    Color textColor;

    if (isCompleted) {
      circleColor = primaryColor;
      textColor = primaryColor;
    } else if (isCurrent) {
      circleColor = primaryColor;
      textColor = Colors.black87;
    } else {
      circleColor = Colors.grey.shade300;
      textColor = Colors.grey.shade400;
    }

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: circleColor,
              border: Border.all(color: circleColor, width: 2),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent ? Colors.white : Colors.transparent,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              color: textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            isCompleted
                ? 'Selesai'
                : isCurrent
                ? 'Progress'
                : 'Pending',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector({
    required bool isCompleted,
    required Color primaryColor,
  }) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 40),
        color: isCompleted ? primaryColor : Colors.grey.shade300,
      ),
    );
  }

  /// Build content berdasarkan step yang aktif
  Widget _buildStepContent(Color primaryColor) {
    final needsBagInput = _needsBagInput();

    // Mapping step based on whether bag input is needed
    if (!needsBagInput) {
      // Flow tanpa input kantong: 0: Datang, 1: Foto, 2: Selesai
      switch (_currentStep) {
        case 0:
          return _buildDatangStep(primaryColor);
        case 1:
          return _buildFotoStep(primaryColor);
        case 2:
          return _buildSelesaiStep(primaryColor);
        default:
          return const SizedBox.shrink();
      }
    } else {
      // Flow dengan input kantong: 0: Datang, 1: Foto, 2: Input, 3: Selesai
      switch (_currentStep) {
        case 0:
          return _buildDatangStep(primaryColor);
        case 1:
          return _buildFotoStep(primaryColor);
        case 2:
          return _buildInputStep(primaryColor);
        case 3:
          return _buildSelesaiStep(primaryColor);
        default:
          return const SizedBox.shrink();
      }
    }
  }

  /// Step 1: Datang - Info lokasi dan konfirmasi kedatangan
  Widget _buildDatangStep(Color primaryColor) {
    final complaint = widget.complaint;
    final location = complaint['location'] ?? 'Alamat tidak tersedia';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Informasi Pengambilan',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.location_on_outlined, 'Lokasi', location),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.person_outline, 'Pelapor', 'Warga'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.access_time, 'Waktu', 'Sekarang'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Instruksi
          Text(
            'Instruksi:',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildInstructionItem(
            '1',
            'Pastikan Anda sudah tiba di lokasi pengambilan',
          ),
          _buildInstructionItem(
            '2',
            'Konfirmasi kedatangan dengan menekan tombol di bawah',
          ),
          _buildInstructionItem('3', 'Lanjutkan ke tahap pengambilan foto'),
        ],
      ),
    );
  }

  /// Step 2: Foto - Ambil foto bukti pengambilan
  Widget _buildFotoStep(Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ambil Foto Bukti Pengambilan',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Foto digunakan sebagai bukti pengambilan sampah',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Photo Area
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: _pickupPhoto == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ketuk untuk mengambil foto',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: kIsWeb
                          ? Image.network(
                              _pickupPhoto!.path,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Image.file(
                              File(_pickupPhoto!.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Button ambil foto
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt, size: 20),
              label: Text(
                _pickupPhoto == null ? 'Ambil Foto' : 'Ambil Ulang Foto',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 3: Input - Input jumlah kantong sampah
  Widget _buildInputStep(Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Input Jumlah Kantong Sampah',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Masukkan jumlah kantong untuk setiap kategori',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // Organik Section
          _buildCategoryHeader('Sampah Organik', Colors.green),
          const SizedBox(height: 12),
          _buildWasteInput('Kantong Besar', 'organic_besar', primaryColor),
          const SizedBox(height: 8),
          _buildWasteInput('Kantong Sedang', 'organic_sedang', primaryColor),
          const SizedBox(height: 8),
          _buildWasteInput('Kantong Kecil', 'organic_kecil', primaryColor),

          const SizedBox(height: 24),

          // Anorganik Section
          _buildCategoryHeader('Sampah Anorganik', Colors.blue),
          const SizedBox(height: 12),
          _buildWasteInput('Kantong Besar', 'anorganic_besar', primaryColor),
          const SizedBox(height: 8),
          _buildWasteInput('Kantong Sedang', 'anorganic_sedang', primaryColor),
          const SizedBox(height: 8),
          _buildWasteInput('Kantong Kecil', 'anorganic_kecil', primaryColor),

          const SizedBox(height: 24),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Kantong:',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${_getTotalBags()} kantong',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Step 4: Selesai - Konfirmasi selesai
  Widget _buildSelesaiStep(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.1),
              ),
              child: Icon(Icons.check_circle, size: 60, color: primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Pengambilan Selesai!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Data pengambilan sampah telah berhasil disimpan',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // ✅ Kembali ke home screen dan refresh data
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home-kolektor',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Kembali ke Beranda',
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

  /// Build bottom button untuk navigasi step
  Widget _buildBottomButton(Color primaryColor) {
    final canProceed = _canProceedToNextStep();

    return Container(
      padding: const EdgeInsets.all(16),
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
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canProceed ? _nextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade500,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              _getButtonText(),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF159189).withValues(alpha: 0.1),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF159189),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildWasteInput(String label, String key, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (_wasteQuantities[key]! > 0) {
                    setState(() {
                      _wasteQuantities[key] = _wasteQuantities[key]! - 1;
                    });
                  }
                },
                icon: const Icon(Icons.remove_circle_outline),
                color: primaryColor,
                iconSize: 28,
              ),
              Container(
                width: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  '${_wasteQuantities[key]}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _wasteQuantities[key] = _wasteQuantities[key]! + 1;
                  });
                },
                icon: const Icon(Icons.add_circle),
                color: primaryColor,
                iconSize: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _getTotalBags() {
    return _wasteQuantities.values.fold(0, (sum, count) => sum + count);
  }

  bool _canProceedToNextStep() {
    final needsBagInput = _needsBagInput();

    if (!needsBagInput) {
      // Flow tanpa input kantong: 0: Datang, 1: Foto, 2: Selesai
      switch (_currentStep) {
        case 0:
          return true; // Datang - always can proceed
        case 1:
          return _pickupPhoto != null; // Foto - need photo
        default:
          return false;
      }
    } else {
      // Flow dengan input kantong: 0: Datang, 1: Foto, 2: Input, 3: Selesai
      switch (_currentStep) {
        case 0:
          return true; // Datang - always can proceed
        case 1:
          return _pickupPhoto != null; // Foto - need photo
        case 2:
          return _getTotalBags() > 0; // Input - need at least 1 bag
        default:
          return false;
      }
    }
  }

  String _getButtonText() {
    final needsBagInput = _needsBagInput();

    if (!needsBagInput) {
      // Flow tanpa input kantong
      switch (_currentStep) {
        case 0:
          return 'Konfirmasi Kedatangan';
        case 1:
          return 'Selesaikan Pengambilan';
        default:
          return 'Lanjutkan';
      }
    } else {
      // Flow dengan input kantong
      switch (_currentStep) {
        case 0:
          return 'Konfirmasi Kedatangan';
        case 1:
          return 'Lanjut ke Input Kantong';
        case 2:
          return 'Selesaikan Pengambilan';
        default:
          return 'Lanjutkan';
      }
    }
  }

  void _nextStep() {
    final totalSteps = _getTotalSteps();
    if (_currentStep < totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (photo != null) {
        setState(() {
          _pickupPhoto = photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengambil foto: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
