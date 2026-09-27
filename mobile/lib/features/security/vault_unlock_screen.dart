import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/dha_vault_logo.dart';
import '../../providers/security_provider.dart';
import '../../theme/app_theme.dart';

class VaultUnlockScreen extends ConsumerStatefulWidget {
  const VaultUnlockScreen({super.key});

  @override
  ConsumerState<VaultUnlockScreen> createState() => _VaultUnlockScreenState();
}

class _VaultUnlockScreenState extends ConsumerState<VaultUnlockScreen> {
  String _enteredPin = '';
  static const int _pinLength = 4;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricUnlock();
      _startLockoutCountdownIfNeeded();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startLockoutCountdownIfNeeded() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final sec = ref.read(securityProvider);
      if (sec.lockoutSeconds > 0) {
        ref.read(securityProvider.notifier).refreshLockout();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _tryBiometricUnlock() async {
    final sec = ref.read(securityProvider);
    if (sec.lockoutSeconds > 0) return;

    if (sec.isBiometricEnabled && sec.canCheckBiometrics) {
      final success = await ref.read(securityProvider.notifier).unlockWithBiometrics();
      if (success && mounted) {
        context.go('/home');
      }
    }
  }

  void _onDigitPressed(String digit) async {
    final sec = ref.read(securityProvider);
    if (sec.lockoutSeconds > 0) return;

    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == _pinLength) {
        final success = await ref.read(securityProvider.notifier).unlockWithPin(_enteredPin);
        if (success && mounted) {
          context.go('/home');
        } else {
          setState(() {
            _enteredPin = '';
          });
          _startLockoutCountdownIfNeeded();
        }
      }
    }
  }

  void _onDeletePressed() {
    final sec = ref.read(securityProvider);
    if (sec.lockoutSeconds > 0) return;

    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sec = ref.watch(securityProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const DhaVaultLogo(size: 68),
              const SizedBox(height: 18),
              Text(
                'Vault Locked',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter PIN or use biometrics to decrypt locker',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 28),
              // PIN Indicator dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (index) {
                  final isFilled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? AppTheme.primary : AppTheme.surfaceElevated,
                      border: Border.all(
                        color: isFilled ? AppTheme.primaryLight : AppTheme.border,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
              if (sec.lockoutSeconds > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, color: AppTheme.accentRed, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Locked out: Retry in ${sec.lockoutSeconds}s',
                        style: const TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ] else if (sec.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  sec.errorMessage!,
                  style: const TextStyle(color: AppTheme.accentRed, fontSize: 12),
                ),
              ],
              const Spacer(),
              // Keypad
              Opacity(
                opacity: sec.lockoutSeconds > 0 ? 0.4 : 1.0,
                child: AbsorbPointer(
                  absorbing: sec.lockoutSeconds > 0,
                  child: _buildKeypad(sec),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(SecurityState sec) {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((d) => _buildKeyButton(d, () => _onDigitPressed(d))).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Biometric or empty
              sec.canCheckBiometrics
                  ? _buildIconButton(Icons.fingerprint, _tryBiometricUnlock)
                  : const SizedBox(width: 72, height: 72),
              _buildKeyButton('0', () => _onDigitPressed('0')),
              _buildIconButton(Icons.backspace_outlined, _onDeletePressed),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeyButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(36),
          side: const BorderSide(color: AppTheme.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: onTap,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: onTap,
          child: Center(
            child: Icon(icon, color: AppTheme.textPrimary, size: 26),
          ),
        ),
      ),
    );
  }
}
