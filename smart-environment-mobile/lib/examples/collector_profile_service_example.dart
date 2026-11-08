import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import '../services/collector_profile_service.dart';
import '../models/user_profile.dart';

/// Example: How to use CollectorProfileService in your Flutter app
class CollectorProfileServiceExample {
  final _profileService = CollectorProfileService();

  /// Example 1: Get Collector Profile
  Future<void> exampleGetProfile() async {
    // Call the service
    final (success, message, data) = await _profileService.getProfile();

    if (success && data != null) {
      // Convert to model (optional)
      final profile = UserProfile.fromJson(data);

      appLog('Profile loaded successfully!');
      appLog('Name: ${profile.name}');
      appLog('Email: ${profile.email}');
      appLog('Phone: ${profile.phone}');
      appLog('Roles: ${profile.roles}');
    } else {
      appLog('Failed to load profile: $message');
    }
  }

  /// Example 2: Update Collector Profile
  Future<void> exampleUpdateProfile() async {
    // Call the service
    final (success, message, data) = await _profileService.updateProfile(
      name: 'Budi Collector',
      phone: '081234567890',
    );

    if (success) {
      appLog('Profile updated successfully!');
      if (data != null) {
        final updatedProfile = UserProfile.fromJson(data);
        appLog('New name: ${updatedProfile.name}');
        appLog('New phone: ${updatedProfile.phone}');
      }
    } else {
      appLog('Failed to update profile: $message');
    }
  }

  /// Example 3: Change Password
  Future<void> exampleChangePassword() async {
    // Call the service
    final (success, message) = await _profileService.changePassword(
      currentPassword: 'oldpassword123',
      newPassword: 'newpassword123',
      newPasswordConfirmation: 'newpassword123',
    );

    if (success) {
      appLog('Password changed successfully!');
    } else {
      appLog('Failed to change password: $message');
    }
  }

  /// Example 4: Complete Collector Profile Screen with Teal Theme
  Widget buildCollectorProfileScreen(BuildContext context) {
    return FutureBuilder(
      future: _profileService.getProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF009688)),
            ),
          );
        }

        if (snapshot.hasData) {
          final (success, message, data) = snapshot.data!;

          if (success && data != null) {
            final profile = UserProfile.fromJson(data);

            return Container(
              color: Colors.grey[50],
              child: Column(
                children: [
                  // Profile Header with Teal Color
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF009688),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: 50,
                            color: Color(0xFF009688),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          profile.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.email,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Profile Info
                  ListTile(
                    leading: const Icon(Icons.person, color: Color(0xFF009688)),
                    title: const Text('Nama'),
                    subtitle: Text(profile.name),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.email, color: Color(0xFF009688)),
                    title: const Text('Email'),
                    subtitle: Text(profile.email),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.phone, color: Color(0xFF009688)),
                    title: const Text('Telepon'),
                    subtitle: Text(profile.phone ?? '-'),
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $message'),
                ],
              ),
            );
          }
        }

        return const Center(child: Text('No data'));
      },
    );
  }

  /// Example 5: Update Profile with UI Feedback (Teal Theme)
  Future<void> exampleUpdateProfileWithUI(BuildContext context) async {
    // Show loading with teal color
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF009688)),
        ),
      ),
    );

    try {
      final (success, message, data) = await _profileService.updateProfile(
        name: 'Budi Collector Updated',
        phone: '081234567890',
      );

      // Hide loading
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (success) {
        // Show success message with teal color
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil berhasil diperbarui!'),
              backgroundColor: Color(0xFF009688),
            ),
          );
        }
      } else {
        // Show error message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message ?? 'Gagal memperbarui profil'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Example 6: Change Password with Validation
  Future<void> exampleChangePasswordWithValidation(
    BuildContext context,
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    // Client-side validation
    if (newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password minimal 8 karakter'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(newPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password harus mengandung huruf dan angka'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password tidak cocok'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Call API
    final (success, message) = await _profileService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      newPasswordConfirmation: confirmPassword,
    );

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password berhasil diubah!'),
            backgroundColor: Color(0xFF009688),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? 'Gagal mengubah password'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Example 7: Build Edit Profile Form for Collector
  Widget buildEditProfileForm(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF009688),
        title: const Text('Edit Profil Kolektor'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Name Field
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Nama Lengkap',
                prefixIcon: const Icon(Icons.person, color: Color(0xFF009688)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF009688),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Phone Field
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Nomor Telepon',
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF009688)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF009688),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await exampleUpdateProfileWithUI(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Simpan Perubahan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
