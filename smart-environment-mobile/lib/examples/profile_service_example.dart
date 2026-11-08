import 'package:beresin_app/utils/app_log.dart';
import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../models/user_profile.dart';

/// Example: How to use ProfileService in your Flutter app
class ProfileServiceExample {
  final _profileService = ProfileService();

  /// Example 1: Get User Profile
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

  /// Example 2: Update User Profile
  Future<void> exampleUpdateProfile() async {
    // Call the service
    final (success, message, data) = await _profileService.updateProfile(
      name: 'John Doe',
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

  /// Example 4: Complete Profile Screen Example
  Widget buildProfileScreen(BuildContext context) {
    return FutureBuilder(
      future: _profileService.getProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          final (success, message, data) = snapshot.data!;

          if (success && data != null) {
            final profile = UserProfile.fromJson(data);

            return Column(
              children: [
                ListTile(
                  title: const Text('Name'),
                  subtitle: Text(profile.name),
                ),
                ListTile(
                  title: const Text('Email'),
                  subtitle: Text(profile.email),
                ),
                ListTile(
                  title: const Text('Phone'),
                  subtitle: Text(profile.phone ?? '-'),
                ),
              ],
            );
          } else {
            return Center(child: Text('Error: $message'));
          }
        }

        return const Center(child: Text('No data'));
      },
    );
  }

  /// Example 5: Update Profile with UI Feedback
  Future<void> exampleUpdateProfileWithUI(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final (success, message, data) = await _profileService.updateProfile(
        name: 'John Doe Updated',
        phone: '081234567890',
      );

      // Hide loading
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (success) {
        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Show error message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message ?? 'Failed to update profile'),
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
            backgroundColor: Colors.green,
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
}
