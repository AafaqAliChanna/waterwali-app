import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Tracks which onboarding tours have already been seen or skipped, so each
// one only ever shows once per install. Reuses the same secure storage
// already used for the JWT instead of adding a second storage package.
class OnboardingService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<bool> hasSeen(String key) async {
    final value = await _storage.read(key: 'onboarding_$key');
    return value == 'true';
  }

  static Future<void> markSeen(String key) async {
    await _storage.write(key: 'onboarding_$key', value: 'true');
  }
}