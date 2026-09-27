import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureVaultStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
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
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _keyRefreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  String _hashSecret(String secret) {
    final bytes = utf8.encode('$_salt:$secret:dha_secure_token');
    return sha256.convert(bytes).toString();
  }

  // PIN Verifier
  Future<void> savePin(String pin) async {
    final verifier = _hashSecret(pin);
    await _storage.write(key: _keyVaultPinVerifier, value: verifier);
  }

  Future<bool> verifyPin(String pin) async {
    final storedVerifier = await _storage.read(key: _keyVaultPinVerifier);
    if (storedVerifier == null) return false;
    return storedVerifier == _hashSecret(pin);
  }

  Future<void> removePin() async {
    await _storage.delete(key: _keyVaultPinVerifier);
  }

  Future<bool> hasPin() async {
    final verifier = await _storage.read(key: _keyVaultPinVerifier);
    return verifier != null && verifier.isNotEmpty;
  }

  // Pattern Verifier (e.g. sequence string "0,1,2,5,8")
  Future<void> savePattern(String pattern) async {
    final verifier = _hashSecret('pattern:$pattern');
    await _storage.write(key: _keyVaultPatternVerifier, value: verifier);
  }

  Future<bool> verifyPattern(String pattern) async {
    final storedVerifier = await _storage.read(key: _keyVaultPatternVerifier);
    if (storedVerifier == null) return false;
    return storedVerifier == _hashSecret('pattern:$pattern');
  }

  Future<bool> hasPattern() async {
    final verifier = await _storage.read(key: _keyVaultPatternVerifier);
    return verifier != null && verifier.isNotEmpty;
  }

  Future<void> removePattern() async {
    await _storage.delete(key: _keyVaultPatternVerifier);
  }

  // Biometrics
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled.toString());
  }

  Future<bool> isBiometricsEnabled() async {
    final val = await _storage.read(key: _keyBiometricEnabled);
    return val == 'true';
  }

  // Rate Limiting & Cooldowns
  Future<int> getFailedAttempts() async {
    final val = await _storage.read(key: _keyFailedAttempts);
    return val != null ? int.tryParse(val) ?? 0 : 0;
  }

  Future<void> incrementFailedAttempts() async {
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
  }

  Future<void> resetFailedAttempts() async {
    await _storage.delete(key: _keyFailedAttempts);
    await _storage.delete(key: _keyLockoutUntil);
  }

  Future<int> getRemainingLockoutSeconds() async {
    final val = await _storage.read(key: _keyLockoutUntil);
    if (val == null) return 0;
    final lockoutMillis = int.tryParse(val) ?? 0;
    final diff = lockoutMillis - DateTime.now().millisecondsSinceEpoch;
    return diff > 0 ? (diff / 1000).ceil() : 0;
  }

  // Auto-lock Settings
  Future<int> getAutoLockSeconds() async {
    final val = await _storage.read(key: _keyAutoLockSeconds);
    return val != null ? (int.tryParse(val) ?? 60) : 60; // Default 1 minute (60s)
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    await _storage.write(key: _keyAutoLockSeconds, value: seconds.toString());
  }

  // Activity tracking for background auto-lock
  Future<void> updateLastActive() async {
    await _storage.write(
      key: _keyLastActiveTime,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Future<int?> getLastActive() async {
    final val = await _storage.read(key: _keyLastActiveTime);
    return val != null ? int.tryParse(val) : null;
  }
}
