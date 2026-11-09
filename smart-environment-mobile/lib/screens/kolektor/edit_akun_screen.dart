import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/user_storage.dart';
import '../../services/collector_profile_service.dart';
import '../../widgets/auto_fill_demo_button.dart';

class EditAkunScreen extends StatefulWidget {
  const EditAkunScreen({super.key});

  @override
  State<EditAkunScreen> createState() => _EditAkunScreenState();
}

class _EditAkunScreenState extends State<EditAkunScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _profileService = CollectorProfileService();

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      // Load profile from API
      final (success, message, data) = await _profileService.getProfile();

      if (success && data != null) {
        if (mounted) {
          setState(() {
            _nameController.text = data['name']?.toString() ?? '';
            _emailController.text = data['email']?.toString() ?? '';
            _phoneController.text = data['phone']?.toString() ?? '';
            _isLoading = false;
          });
        }
      } else {
        // Fallback to local storage if API fails
        final email = await UserStorage.getUserEmail();
        final name = await UserStorage.getUserName();
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('kolektor_phone') ?? '';

        if (mounted) {
          setState(() {
            _nameController.text = name ?? '';
            _emailController.text = email ?? '';
            _phoneController.text = phone;
            _isLoading = false;
          });
        }

        // Show warning if API failed
        if (mounted && message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Memuat data lokal: $message'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Call API to update profile
      final (success, message, data) = await _profileService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (success) {
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', _nameController.text.trim());
        await prefs.setString('kolektor_phone', _phoneController.text.trim());

        // Update UserStorage
        if (data != null) {
          // Safely extract id - handle both int and string
          int? userId;
          if (data['id'] != null) {
            if (data['id'] is int) {
              userId = data['id'] as int;
            } else if (data['id'] is String) {
              userId = int.tryParse(data['id'] as String);
            }
          }

          // Only save if we have valid user id
          if (userId != null) {
            await UserStorage.saveUser(
              id: userId,
              name: data['name']?.toString() ?? _nameController.text.trim(),
              email: data['email']?.toString() ?? _emailController.text.trim(),
              roles: (data['roles'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList(),
              fullData: data,
            );
          }
        }

        if (mounted) {
          setState(() => _isSaving = false);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'Profil berhasil diperbarui',
                    style: GoogleFonts.poppins(),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF009688),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          // Kembali ke halaman sebelumnya
          Navigator.pop(context, true); // true = data updated
        }
      } else {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message ?? 'Gagal memperbarui profil'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _autoFillDemo() async {
    setState(() {
      _nameController.text = 'Budi Santoso';
      _phoneController.text = '081234567890';
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF009688),
        title: Text(
          "Edit Akun",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF009688).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFF009688,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Color(0xFF009688),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Pastikan data yang Anda masukkan benar dan aktif',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF009688),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      AutoFillDemoButton(
                        isFormEmpty:
                            _nameController.text.trim().isEmpty &&
                            _phoneController.text.trim().isEmpty,
                        onFill: _autoFillDemo,
                        enabled: !_isSaving,
                      ),
                      const SizedBox(height: 24),

                      // Name Field
                      Text(
                        'Nama Lengkap',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                        decoration: InputDecoration(
                          hintText: 'Masukkan nama lengkap Anda',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF009688),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nama lengkap tidak boleh kosong';
                          }
                          if (value.length < 3) {
                            return 'Nama lengkap minimal 3 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Email Field
                      Text(
                        'Email (untuk login)',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: false, // Email tidak bisa diubah
                        decoration: InputDecoration(
                          hintText: 'Email yang terdaftar',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Phone Field
                      Text(
                        'Nomor Telepon',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Contoh: 081234567890',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                          prefixIcon: const Icon(Icons.phone_outlined),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF009688),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nomor telepon tidak boleh kosong';
                          }
                          if (!RegExp(r'^[0-9+]+$').hasMatch(value)) {
                            return 'Nomor telepon hanya boleh berisi angka';
                          }
                          if (value.length < 10) {
                            return 'Nomor telepon minimal 10 digit';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF009688),
                            disabledBackgroundColor: Colors.grey.shade400,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Simpan Perubahan',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
