import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/security_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dha_vault_logo.dart';
import '../../widgets/google_sign_in_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  int _calculateStrength(String pass) {
    if (pass.isEmpty) return 0;
    int score = 0;
    if (pass.length >= 8) score++;
    if (pass.length >= 10) score++;
    if (RegExp(r'[0-9]').hasMatch(pass)) score++;
    if (RegExp(r'[A-Z]').hasMatch(pass) && RegExp(r'[a-z]').hasMatch(pass)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass)) score++;
    return score; // 0 to 5
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.isNotEmpty ? _nameController.text.trim() : null,
        );

    if (success && mounted) {
      ref.read(securityProvider.notifier).initialize();
      context.go('/home');
    }
  }

  Future<void> _handleGoogleSignInFlow() async {
    final nativeSuccess = await ref.read(authProvider.notifier).signInWithNativeGoogle();
    if (nativeSuccess && mounted) {
      await _proceedToBiometricAndVault();
    }
  }

  Future<void> _proceedToBiometricAndVault() async {
    final secNotifier = ref.read(securityProvider.notifier);
    await secNotifier.initialize();
    final canBio = await secNotifier.canAuthenticateWithBiometrics();
    if (canBio) {
      final bioSuccess = await secNotifier.unlockWithBiometrics();
      if (bioSuccess && mounted) {
        context.go('/home');
      } else if (mounted) {
        context.go('/unlock');
      }
    } else {
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: DhaVaultLogo(
                    size: 72,
                    showWordmark: true,
                    wordmarkText: 'DHA Vault',
                    subtitle: 'NEW ACCOUNT ENROLLMENT',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Create Digital Vault',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Set up your secure, encrypted document repository',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                if (authState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: AppTheme.accentRed, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Email is required';
                    if (!val.contains('@')) return 'Enter a valid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password (min 8 characters)',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textMuted, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final strength = _calculateStrength(_passwordController.text);
                      Color color;
                      String label;
                      if (strength <= 1) {
                        color = AppTheme.accentRed;
                        label = 'Weak';
                      } else if (strength <= 2) {
                        color = AppTheme.accentAmber;
                        label = 'Fair';
                      } else if (strength <= 3) {
                        color = AppTheme.primaryLight;
                        label = 'Good';
                      } else {
                        color = AppTheme.accentGreen;
                        label = 'Banking Grade (Strong)';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(4, (index) {
                              final filled = index < (strength == 0 ? 0 : (strength > 4 ? 4 : strength));
                              return Expanded(
                                child: Container(
                                  height: 3,
                                  margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                                  decoration: BoxDecoration(
                                    color: filled ? color : AppTheme.border,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Security: $label',
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textMuted, size: 20),
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleRegister,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Initialize Vault'),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'OR ENROLL WITH',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppTheme.border)),
                  ],
                ),
                const SizedBox(height: 20),
                GoogleSignInButton(
                  text: 'Continue with Google',
                  onPressed: _handleGoogleSignInFlow,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have a vault?', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    TextButton(
                      onPressed: () => context.pushReplacement('/login'),
                      child: const Text('Sign In', style: TextStyle(color: AppTheme.primaryLight, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
