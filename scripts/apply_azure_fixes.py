import os

def patch_file(filepath, search_str, replace_str):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    if search_str not in content:
        raise ValueError(f"Target not found in {filepath}!")
    new_content = content.replace(search_str, replace_str, 1)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"Successfully patched {filepath}")

# 3. collector_pickup_process_screen.dart
patch_file(
    'smart-environment-mobile/lib/screens/kolektor/collector_pickup_process_screen.dart',
    """      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );""",
    """      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );"""
)

# 4. collector_complaint_detail_screen.dart
patch_file(
    'smart-environment-mobile/lib/screens/kolektor/collector_complaint_detail_screen.dart',
    """      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );""",
    """      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );"""
)

# 5. pelaporan_screen.dart
patch_file(
    'smart-environment-mobile/lib/screens/user/pelaporan_screen.dart',
    """      final XFile? pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
      );""",
    """      final XFile? pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );"""
)

# 6. collector_off_schedule_pickup_service.dart
patch_file(
    'smart-environment-mobile/lib/services/collector_off_schedule_pickup_service.dart',
    """      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['data']);
      } else if (response.statusCode == 422) {
        final error = jsonDecode(response.body);
        final errors = error['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          final firstError = errors.values.first;
          final errorMessage = firstError is List ? firstError.first : firstError.toString();
          throw Exception(errorMessage);
        }
        throw Exception(error['message'] ?? 'Validation error');
      } else {
        throw Exception('Failed to complete pickup: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }""",
    """      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['data']);
      } else if (response.statusCode == 413) {
        throw Exception('Ukuran foto terlalu besar untuk server. Silakan gunakan foto yang lebih kecil.');
      } else if (response.statusCode == 422) {
        final error = jsonDecode(response.body);
        final errors = error['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          final firstError = errors.values.first;
          final errorMessage = firstError is List ? firstError.first : firstError.toString();
          throw Exception(errorMessage);
        }
        throw Exception(error['message'] ?? 'Validation error');
      } else {
        throw Exception('Failed to complete pickup: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Koneksi ke server terputus (${e.message}). Pastikan jaringan stabil dan ukuran foto tidak terlalu besar.');
    } catch (e) {
      rethrow;
    }"""
)

# 7. detail_sampah_screen.dart
patch_file(
    'smart-environment-mobile/lib/screens/kolektor/detail_sampah_screen.dart',
    """        } catch (e) {
          success = false;
          message = e.toString().replaceAll('Exception: ', '');
          appLog('❌ [DetailSampah] Off-schedule complete FAILED: $message');
        }""",
    """        } catch (e) {
          success = false;
          final errorStr = e.toString().replaceAll('Exception: ', '');
          if (errorStr.contains('ClientLoad failed') ||
              errorStr.contains('XMLHttpRequest') ||
              errorStr.contains('Failed to fetch')) {
            message = 'Gagal mengirim data ke server (koneksi terputus atau ukuran foto terlalu besar). Silakan coba lagi.';
          } else {
            message = errorStr;
          }
          appLog('❌ [DetailSampah] Off-schedule complete FAILED: $message');
        }"""
)

print("Remaining patches applied successfully!")
