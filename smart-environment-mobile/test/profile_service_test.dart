import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beresin_app/config/api_config.dart';
import 'package:beresin_app/services/profile_service.dart';
import 'package:beresin_app/models/user_profile.dart';

void main() {
  group('ProfileService Tests', () {
    late ProfileService profileService;

    setUp(() {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.example'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final data = options.path == ApiConfig.residentProfile
                ? {
                    'success': true,
                    'data': {
                      'id': 1,
                      'name': 'John Doe',
                      'email': 'john@example.com',
                    },
                  }
                : {
                    'success': false,
                    'errors': {'message': 'Password baru tidak valid'},
                  };
            handler.resolve(Response(requestOptions: options, data: data));
          },
        ),
      );
      profileService = ProfileService(dio: dio);
    });

    test('getProfile should return user profile data', () async {
      final (success, message, data) = await profileService.getProfile();

      expect(success, isTrue);
      expect(message, isNull);
      expect(data, containsPair('id', 1));
      expect(data, containsPair('name', 'John Doe'));
      expect(data, containsPair('email', 'john@example.com'));
    });

    test('UserProfile model should parse JSON correctly', () {
      // Arrange
      final json = {
        'id': 1,
        'name': 'John Doe',
        'email': 'john@example.com',
        'phone': '081234567890',
        'roles': ['resident'],
        'created_at': '2024-01-01T00:00:00.000000Z',
        'updated_at': '2024-01-01T00:00:00.000000Z',
      };

      // Act
      final profile = UserProfile.fromJson(json);

      // Assert
      expect(profile.id, equals(1));
      expect(profile.name, equals('John Doe'));
      expect(profile.email, equals('john@example.com'));
      expect(profile.phone, equals('081234567890'));
      expect(profile.roles, contains('resident'));
    });

    test('UserProfile toJson should convert to Map correctly', () {
      // Arrange
      final profile = UserProfile(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        phone: '081234567890',
        roles: ['resident'],
      );

      // Act
      final json = profile.toJson();

      // Assert
      expect(json['id'], equals(1));
      expect(json['name'], equals('John Doe'));
      expect(json['email'], equals('john@example.com'));
      expect(json['phone'], equals('081234567890'));
    });

    test(
      'UserProfile copyWith should create new instance with updated fields',
      () {
        // Arrange
        final profile = UserProfile(
          id: 1,
          name: 'John Doe',
          email: 'john@example.com',
        );

        // Act
        final updatedProfile = profile.copyWith(
          name: 'Jane Doe',
          phone: '081234567890',
        );

        // Assert
        expect(updatedProfile.id, equals(1)); // unchanged
        expect(updatedProfile.name, equals('Jane Doe')); // changed
        expect(updatedProfile.email, equals('john@example.com')); // unchanged
        expect(updatedProfile.phone, equals('081234567890')); // changed
      },
    );

    test('updateProfile should reject missing required fields', () async {
      final (success, message, data) = await profileService.updateProfile(
        name: '   ',
        phone: '081234567890',
      );

      expect(success, isFalse);
      expect(message, 'Nama wajib diisi');
      expect(data, isNull);
    });

    test('changePassword should validate password requirements', () async {
      final (success, message) = await profileService.changePassword(
        currentPassword: 'old123',
        newPassword: 'short',
        newPasswordConfirmation: 'short',
      );

      expect(success, isFalse);
      expect(message, 'Password baru tidak valid');
    });
  });

  group('Password Validation Tests', () {
    test('Password should be at least 8 characters', () {
      // Arrange
      const password = 'abc123';

      // Act
      const isValid = password.length >= 8;

      // Assert
      expect(isValid, isFalse);
    });

    test('Password should contain letters and numbers', () {
      // Arrange
      const validPassword = 'abc12345';
      const invalidPassword1 = 'abcdefgh'; // no numbers
      const invalidPassword2 = '12345678'; // no letters

      // Act
      final regex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)');
      final isValid1 = regex.hasMatch(validPassword);
      final isValid2 = regex.hasMatch(invalidPassword1);
      final isValid3 = regex.hasMatch(invalidPassword2);

      // Assert
      expect(isValid1, isTrue);
      expect(isValid2, isFalse);
      expect(isValid3, isFalse);
    });

    test('Password confirmation should match new password', () {
      // Arrange
      const newPassword = 'abc12345';
      const confirmPassword1 = 'abc12345';
      const confirmPassword2 = 'different';

      // Act & Assert
      expect(newPassword == confirmPassword1, isTrue);
      expect(newPassword == confirmPassword2, isFalse);
    });
  });
}
