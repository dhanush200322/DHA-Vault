import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dha_vault_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              const Center(
                child: DhaVaultLogo(
                  size: 96,
                  useHero: true,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'DHA Vault',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Your Documents. Secured. Organized.\nInstantly Accessible.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 40),
              // Security indicators
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    _buildFeatureItem(
                      icon: Icons.fingerprint,
                      title: 'Biometric & Hardware Lock',
                      desc: 'Protected by Android Keystore / iOS Keychain',
                    ),
                    const Divider(color: AppTheme.border, height: 24),
                    _buildFeatureItem(
                      icon: Icons.speed,
                      title: 'Instant Fast View Engine',
                      desc: 'Tap and preview documents with zero lag',
                    ),
                    const Divider(color: AppTheme.border, height: 24),
                    _buildFeatureItem(
                      icon: Icons.verified_user_outlined,
                      title: 'Immutable Audit Trail',
                      desc: 'End-to-end security tracking for every file',
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                child: const Text('Sign In to Vault'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/register'),
                child: const Text('Create Secure Account'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryLight, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}
