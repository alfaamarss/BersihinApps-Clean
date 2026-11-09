import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'review_foto_screen.dart';

class AmbilFotoScreen extends StatefulWidget {
  final int pickupId;
  final String userName;
  final String address;
  final String idPengambilan;
  final bool isOffSchedule;

  const AmbilFotoScreen({
    super.key,
    required this.pickupId,
    required this.userName,
    required this.address,
    required this.idPengambilan,
    this.isOffSchedule = false,
  });

  @override
  State<AmbilFotoScreen> createState() => _AmbilFotoScreenState();
}

class _AmbilFotoScreenState extends State<AmbilFotoScreen> {
  File? _imageFile;
  XFile? _pickedFile;
  final ImagePicker _picker = ImagePicker();
  final int _currentStep =
      1; // 0: Datang, 1: Foto, 2: Input Kantong, 3: Selesai

  @override
  void initState() {
    super.initState();
    // Reset foto state saat masuk ke halaman ini
    _resetPhotoState();
  }

  void _resetPhotoState() {
    _imageFile = null;
    _pickedFile = null;
  }

  Future<void> _ambilFoto() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      // Jangan update state di sini, langsung navigate ke review
      // Navigate ke ReviewFotoScreen setelah foto diambil
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewFotoScreen(
              pickupId: widget.pickupId,
              userName: widget.userName,
              address: widget.address,
              idPengambilan: widget.idPengambilan,
              imageFile: pickedFile,
              isOffSchedule: widget.isOffSchedule,
            ),
          ),
        ).then((_) {
          // Ketika kembali dari review screen, reset state
          if (mounted) {
            _resetPhotoState();
            setState(() {}); // Refresh UI
          }
        });
      }
    }
    // Jika user cancel kamera, tetap di halaman ini tanpa foto
  }

  Widget _buildProgressStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _buildStepItem(0, 'Datang', 'Selesai'),
          _buildStepLine(0),
          _buildStepItem(1, 'Foto', 'Progress'),
          _buildStepLine(1),
          _buildStepItem(2, 'Input Kantong', 'Pending'),
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

  Widget _buildImagePreview() {
    if (_pickedFile == null) {
      return Container(
        height: 300,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_a_photo_outlined,
                size: 50,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tambah Foto',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 300,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: kIsWeb
            ? Image.network(
                _pickedFile!.path,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            : Image.file(
                _imageFile!,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF009688);

    return Scaffold(
      backgroundColor: Colors.white,
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
      body: Column(
        children: [
          // Progress Stepper
          _buildProgressStepper(),

          // Spacer yang bisa di-expand
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image Preview dengan gesture detector untuk tap
                GestureDetector(onTap: _ambilFoto, child: _buildImagePreview()),
              ],
            ),
          ),

          // Button di bagian bawah
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _ambilFoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Ambil Foto',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
