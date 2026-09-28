import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureVaultStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _salt = 'dha_vault_hardware_salt_v2_secure';
  static const _keyAccessToken = 'dha_jwt_access_token';
  static const _keyRefreshToken = 'dha_jwt_refresh_token';
  static const _keyVaultPinVerifier = 'dha_vault_pin_verifier';
  static const _keyVaultPatternVerifier = 'dha_vault_pattern_verifier';
  static const _keyBiometricEnabled = 'dha_biometric_enabled';
  static const _keyLastActiveTime = 'dha_last_active_time';
  static const _keyFailedAttempts = 'dha_failed_attempts';
  static const _keyLockoutUntil = 'dha_lockout_until';
  static const _keyAutoLockSeconds = 'dha_auto_lock_seconds';

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    try {
      await _storage.write(key: _keyAccessToken, value: accessToken);
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    } catch (_) {}
  }

  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _keyAccessToken);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearTokens() async {
    try {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
    } catch (_) {}
  }

  String _hashSecret(String secret) {
    final bytes = utf8.encode('$_salt:$secret:dha_secure_token');
    return sha256.convert(bytes).toString();
  }

  // PIN Verifier
  Future<void> savePin(String pin) async {
    try {
      final verifier = _hashSecret(pin);
      await _storage.write(key: _keyVaultPinVerifier, value: verifier);
    } catch (_) {}
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final storedVerifier = await _storage.read(key: _keyVaultPinVerifier);
      if (storedVerifier == null) return false;
      return storedVerifier == _hashSecret(pin);
    } catch (_) {
      return false;
    }
  }

  Future<void> removePin() async {
    try {
      await _storage.delete(key: _keyVaultPinVerifier);
    } catch (_) {}
  }

  Future<bool> hasPin() async {
    try {
      final verifier = await _storage.read(key: _keyVaultPinVerifier);
      return verifier != null && verifier.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Pattern Verifier (e.g. sequence string "0,1,2,5,8")
  Future<void> savePattern(String pattern) async {
    try {
      final verifier = _hashSecret('pattern:$pattern');
      await _storage.write(key: _keyVaultPatternVerifier, value: verifier);
    } catch (_) {}
  }

  Future<bool> verifyPattern(String pattern) async {
    try {
      final storedVerifier = await _storage.read(key: _keyVaultPatternVerifier);
      if (storedVerifier == null) return false;
      return storedVerifier == _hashSecret('pattern:$pattern');
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPattern() async {
    try {
      final verifier = await _storage.read(key: _keyVaultPatternVerifier);
      return verifier != null && verifier.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> removePattern() async {
    try {
      await _storage.delete(key: _keyVaultPatternVerifier);
    } catch (_) {}
  }

  // Biometrics
  Future<void> setBiometricsEnabled(bool enabled) async {
    try {
      await _storage.write(key: _keyBiometricEnabled, value: enabled.toString());
    } catch (_) {}
  }

  Future<bool> isBiometricsEnabled() async {
    try {
      final val = await _storage.read(key: _keyBiometricEnabled);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  // Rate Limiting & Cooldowns
  Future<int> getFailedAttempts() async {
    try {
      final val = await _storage.read(key: _keyFailedAttempts);
      return val != null ? int.tryParse(val) ?? 0 : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> incrementFailedAttempts() async {
    try {
      final current = await getFailedAttempts();
      final next = current + 1;
      await _storage.write(key: _keyFailedAttempts, value: next.toString());

      // Introduce increasing lockout delay
      if (next >= 5) {
        // 60-second lockout
        final lockoutTime = DateTime.now().add(const Duration(seconds: 60)).millisecondsSinceEpoch;
        await _storage.write(key: _keyLockoutUntil, value: lockoutTime.toString());
      } else if (next >= 3) {
        // 30-second lockout
        final lockoutTime = DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch;
        await _storage.write(key: _keyLockoutUntil, value: lockoutTime.toString());
      }
    } catch (_) {}
  }

  Future<void> resetFailedAttempts() async {
    try {
      await _storage.delete(key: _keyFailedAttempts);
      await _storage.delete(key: _keyLockoutUntil);
    } catch (_) {}
  }

  Future<int> getRemainingLockoutSeconds() async {
    try {
      final val = await _storage.read(key: _keyLockoutUntil);
      if (val == null) return 0;
      final lockoutMillis = int.tryParse(val) ?? 0;
      final diff = lockoutMillis - DateTime.now().millisecondsSinceEpoch;
      return diff > 0 ? (diff / 1000).ceil() : 0;
    } catch (_) {
      return 0;
    }
  }

  // Auto-lock Settings
  Future<int> getAutoLockSeconds() async {
    try {
      final val = await _storage.read(key: _keyAutoLockSeconds);
      return val != null ? (int.tryParse(val) ?? 60) : 60; // Default 1 minute (60s)
    } catch (_) {
      return 60;
    }
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    try {
      await _storage.write(key: _keyAutoLockSeconds, value: seconds.toString());
    } catch (_) {}
  }

  // Activity tracking for background auto-lock
  Future<void> updateLastActive() async {
    try {
      await _storage.write(
        key: _keyLastActiveTime,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {}
  }

  Future<int?> getLastActive() async {
    try {
      final val = await _storage.read(key: _keyLastActiveTime);
      return val != null ? int.tryParse(val) : null;
    } catch (_) {
      return null;
    }
  }

  // First-time Home Coach Marks persistence
  static const _keyCoachMarksCompletedPrefix = 'dha_vault_home_coach_marks_completed_';

  Future<void> setCoachMarksCompleted(String userId) async {
    try {
      final key = '$_keyCoachMarksCompletedPrefix${userId.isNotEmpty ? userId : "default"}';
      await _storage.write(key: key, value: 'true');
    } catch (_) {}
  }

  Future<bool> isCoachMarksCompleted(String userId) async {
    try {
      final key = '$_keyCoachMarksCompletedPrefix${userId.isNotEmpty ? userId : "default"}';
      final val = await _storage.read(key: key);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> resetCoachMarks(String userId) async {
    try {
      final key = '$_keyCoachMarksCompletedPrefix${userId.isNotEmpty ? userId : "default"}';
      await _storage.delete(key: key);
    } catch (_) {}
  }
}
