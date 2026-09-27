import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../core/storage/secure_vault_storage.dart';

final secureStorageProvider = Provider<SecureVaultStorage>((ref) {
  return SecureVaultStorage();
});

class SecurityState {
  final bool isUnlocked;
  final bool hasPinConfigured;
  final bool hasPatternConfigured;
  final bool isBiometricEnabled;
  final bool canCheckBiometrics;
  final int lockoutSeconds;
  final int autoLockSeconds;
  final String? errorMessage;

  SecurityState({
    required this.isUnlocked,
    required this.hasPinConfigured,
    required this.hasPatternConfigured,
    required this.isBiometricEnabled,
    required this.canCheckBiometrics,
    this.lockoutSeconds = 0,
    this.autoLockSeconds = 60,
    this.errorMessage,
  });

  SecurityState copyWith({
    bool? isUnlocked,
    bool? hasPinConfigured,
    bool? hasPatternConfigured,
    bool? isBiometricEnabled,
    bool? canCheckBiometrics,
    int? lockoutSeconds,
    int? autoLockSeconds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SecurityState(
      isUnlocked: isUnlocked ?? this.isUnlocked,
      hasPinConfigured: hasPinConfigured ?? this.hasPinConfigured,
      hasPatternConfigured: hasPatternConfigured ?? this.hasPatternConfigured,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      canCheckBiometrics: canCheckBiometrics ?? this.canCheckBiometrics,
      lockoutSeconds: lockoutSeconds ?? this.lockoutSeconds,
      autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  final SecureVaultStorage _storage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  SecurityNotifier(this._storage)
      : super(
          SecurityState(
            isUnlocked: false,
            hasPinConfigured: false,
            hasPatternConfigured: false,
            isBiometricEnabled: false,
            canCheckBiometrics: false,
          ),
        ) {
    initialize();
  }

  Future<void> initialize() async {
    final hasPin = await _storage.hasPin();
    final hasPattern = await _storage.hasPattern();
    final bioEnabled = await _storage.isBiometricsEnabled();
    final autoLockSec = await _storage.getAutoLockSeconds();
    final lockout = await _storage.getRemainingLockoutSeconds();

    bool canCheckBio = false;
    try {
      canCheckBio = await _localAuth.canCheckBiometrics;
    } catch (_) {}

    // If no PIN and no Pattern configured yet, default to unlocked
    final isUnlocked = !hasPin && !hasPattern && !bioEnabled;

    state = state.copyWith(
      isUnlocked: isUnlocked,
      hasPinConfigured: hasPin,
      hasPatternConfigured: hasPattern,
      isBiometricEnabled: bioEnabled,
      canCheckBiometrics: canCheckBio,
      autoLockSeconds: autoLockSec,
      lockoutSeconds: lockout,
    );
  }

  Future<void> refreshLockout() async {
    final lockout = await _storage.getRemainingLockoutSeconds();
    if (lockout != state.lockoutSeconds) {
      state = state.copyWith(lockoutSeconds: lockout);
    }
  }

  Future<bool> unlockWithBiometrics() async {
    final lockout = await _storage.getRemainingLockoutSeconds();
    if (lockout > 0) {
      state = state.copyWith(
        lockoutSeconds: lockout,
        errorMessage: 'Vault locked. Try again in $lockout seconds.',
      );
      return false;
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock DHA Vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        await _storage.resetFailedAttempts();
        await _storage.updateLastActive();
        state = state.copyWith(
          isUnlocked: true,
          clearError: true,
          lockoutSeconds: 0,
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Biometric verification failed');
    }
    return false;
  }

  Future<bool> unlockWithPin(String pin) async {
    final lockout = await _storage.getRemainingLockoutSeconds();
    if (lockout > 0) {
      state = state.copyWith(
        lockoutSeconds: lockout,
        errorMessage: 'Too many attempts. Locked for $lockout seconds.',
      );
      return false;
    }

    final isValid = await _storage.verifyPin(pin);
    if (isValid) {
      await _storage.resetFailedAttempts();
      await _storage.updateLastActive();
      state = state.copyWith(
        isUnlocked: true,
        clearError: true,
        lockoutSeconds: 0,
      );
      return true;
    } else {
      await _storage.incrementFailedAttempts();
      final newLockout = await _storage.getRemainingLockoutSeconds();
      state = state.copyWith(
        lockoutSeconds: newLockout,
        errorMessage: newLockout > 0
            ? 'Too many failed attempts. Vault locked for $newLockout seconds.'
            : 'Invalid vault PIN.',
      );
      return false;
    }
  }

  Future<bool> unlockWithPattern(String pattern) async {
    final lockout = await _storage.getRemainingLockoutSeconds();
    if (lockout > 0) {
      state = state.copyWith(
        lockoutSeconds: lockout,
        errorMessage: 'Too many attempts. Locked for $lockout seconds.',
      );
      return false;
    }

    final isValid = await _storage.verifyPattern(pattern);
    if (isValid) {
      await _storage.resetFailedAttempts();
      await _storage.updateLastActive();
      state = state.copyWith(
        isUnlocked: true,
        clearError: true,
        lockoutSeconds: 0,
      );
      return true;
    } else {
      await _storage.incrementFailedAttempts();
      final newLockout = await _storage.getRemainingLockoutSeconds();
      state = state.copyWith(
        lockoutSeconds: newLockout,
        errorMessage: newLockout > 0
            ? 'Too many failed attempts. Vault locked for $newLockout seconds.'
            : 'Incorrect pattern.',
      );
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    await _storage.savePin(pin);
    state = state.copyWith(hasPinConfigured: true);
  }

  Future<void> removePin() async {
    await _storage.removePin();
    state = state.copyWith(hasPinConfigured: false);
  }

  Future<void> setPattern(String pattern) async {
    await _storage.savePattern(pattern);
    state = state.copyWith(hasPatternConfigured: true);
  }

  Future<void> removePattern() async {
    await _storage.removePattern();
    state = state.copyWith(hasPatternConfigured: false);
  }

  Future<void> setBiometrics(bool enabled) async {
    await _storage.setBiometricsEnabled(enabled);
    state = state.copyWith(isBiometricEnabled: enabled);
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    await _storage.setAutoLockSeconds(seconds);
    state = state.copyWith(autoLockSeconds: seconds);
  }

  Future<void> onAppResumed() async {
    if (state.autoLockSeconds <= 0) return; // -1 means never

    final lastActive = await _storage.getLastActive();
    if (lastActive != null && (state.hasPinConfigured || state.hasPatternConfigured)) {
      final elapsedSeconds = (DateTime.now().millisecondsSinceEpoch - lastActive) / 1000;
      if (elapsedSeconds >= state.autoLockSeconds) {
        lockVault();
      }
    }
  }

  Future<void> onAppPaused() async {
    await _storage.updateLastActive();
  }

  void lockVault() {
    state = state.copyWith(isUnlocked: false);
  }
}

final securityProvider = StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return SecurityNotifier(storage);
});
