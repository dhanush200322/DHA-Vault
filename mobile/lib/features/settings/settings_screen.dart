import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_endpoints.dart';
import '../../providers/auth_provider.dart';
import '../../providers/security_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dha_vault_logo.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _dbStatus = 'Checking...';

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Widget _buildAvatarFallback(dynamic user) {
    final name = user?.fullName ?? user?.email ?? 'DHA';
    final initial = (name is String && name.isNotEmpty) ? name[0].toUpperCase() : 'D';
    return Container(
      width: 56,
      height: 56,
      color: AppTheme.surfaceElevated,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppTheme.primaryLight,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _checkHealth() async {
    final client = ref.read(apiClientProvider);
    try {
      final res = await client.dio.get(ApiEndpoints.health);
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _dbStatus = res.data['database'] == 'connected' ? 'Connected (PostgreSQL)' : 'Disconnected';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dbStatus = 'Offline');
    }
  }

  Future<void> _setPinDialog() async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Set 4-Digit Vault PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          style: const TextStyle(letterSpacing: 8, fontSize: 20),
          decoration: const InputDecoration(hintText: '••••'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );

    if (pin != null && pin.length == 4) {
      await ref.read(securityProvider.notifier).setPin(pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault PIN configured!'), backgroundColor: AppTheme.accentGreen),
        );
      }
    }
  }

  Future<void> _changeAutoLockDialog() async {
    final current = ref.read(securityProvider).autoLockSeconds;
    final options = [
      {'label': '30 Seconds', 'value': 30},
      {'label': '1 Minute (Default)', 'value': 60},
      {'label': '5 Minutes', 'value': 300},
      {'label': '15 Minutes', 'value': 900},
      {'label': 'Never', 'value': -1},
    ];

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Auto-Lock Timeout'),
        children: options.map((opt) {
          final isSelected = opt['value'] == current;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, opt['value'] as int),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  opt['label'] as String,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryLight : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isSelected) const Icon(Icons.check, color: AppTheme.primaryLight, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected != null) {
      await ref.read(securityProvider.notifier).setAutoLockSeconds(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-lock timeout updated'), backgroundColor: AppTheme.accentGreen),
        );
      }
    }
  }

  Future<void> _setPatternDialog() async {
    final controller = TextEditingController();
    final pattern = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Configure Pattern Lock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter sequence of nodes (e.g. 1-2-3-6-9 or custom identifier):',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'e.g. 1-2-5-8'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save Pattern'),
          ),
        ],
      ),
    );

    if (pattern != null && pattern.isNotEmpty) {
      await ref.read(securityProvider.notifier).setPattern(pattern);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault Pattern Lock configured!'), backgroundColor: AppTheme.accentGreen),
        );
      }
    }
  }

  String _formatAutoLock(int seconds) {
    if (seconds <= 0) return 'Never';
    if (seconds < 60) return '${seconds}s';
    return '${(seconds / 60).round()}m';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final secState = ref.watch(securityProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings & Security'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: (authState.user?.avatarUrl != null &&
                              authState.user!.avatarUrl!.trim().isNotEmpty)
                          ? Image.network(
                              authState.user!.avatarUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildAvatarFallback(authState.user),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: AppTheme.surfaceElevated,
                                  alignment: Alignment.center,
                                  child: const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryLight,
                                    ),
                                  ),
                                );
                              },
                            )
                          : _buildAvatarFallback(authState.user),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.user?.fullName ?? 'DHA Vault Owner',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authState.user?.email ?? '',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Hardware Security Section
            Text('SECURITY & LOCK', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Material(
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.pin, color: AppTheme.primaryLight),
                    title: const Text('4-Digit Vault PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      secState.hasPinConfigured ? 'Armed & Salted SHA-256' : 'Not configured',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    trailing: OutlinedButton(
                      onPressed: _setPinDialog,
                      child: Text(secState.hasPinConfigured ? 'Change' : 'Set PIN', style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                  const Divider(color: AppTheme.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.grid_3x3, color: AppTheme.accentPurple),
                    title: const Text('Pattern Lock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      secState.hasPatternConfigured ? 'Armed & Salted Verifier' : 'Disabled (Fallback to PIN)',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    trailing: OutlinedButton(
                      onPressed: _setPatternDialog,
                      child: Text(secState.hasPatternConfigured ? 'Change' : 'Set Pattern', style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                  const Divider(color: AppTheme.border, height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint, color: AppTheme.accentGreen),
                    title: const Text('Biometric Authentication', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Fingerprint / Face ID instant unlock', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    value: secState.isBiometricEnabled,
                    activeThumbColor: AppTheme.accentGreen,
                    onChanged: (val) {
                      ref.read(securityProvider.notifier).setBiometrics(val);
                    },
                  ),
                  const Divider(color: AppTheme.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_clock, color: AppTheme.accentAmber),
                    title: const Text('Auto-Lock Timeout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('Locks after ${_formatAutoLock(secState.autoLockSeconds)} in background', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    trailing: OutlinedButton(
                      onPressed: _changeAutoLockDialog,
                      child: Text(_formatAutoLock(secState.autoLockSeconds), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Family Vault & Delegation Section
            Text('FAMILY VAULT & SECURE DELEGATION', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Material(
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.family_restroom, color: AppTheme.accentGreen),
                    title: const Text('Family Vault', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Shared vaults, role-based access, and family invitations', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                    onTap: () => context.push('/family'),
                  ),
                  const Divider(color: AppTheme.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.health_and_safety_outlined, color: AppTheme.accentAmber),
                    title: const Text('Emergency Access & Recovery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Trusted delegates, delayed access activation, and guardian recovery', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                    onTap: () => context.push('/emergency-access'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cloud Sync & Devices Section
            Text('CLOUD SYNC & MULTI-DEVICE', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Material(
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cloud_sync_outlined, color: AppTheme.primaryLight),
                    title: const Text('Backup & Cloud Sync', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Encrypted cloud backup, sync status, and storage quota', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                    onTap: () => context.push('/backup-sync'),
                  ),
                  const Divider(color: AppTheme.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.devices_outlined, color: AppTheme.accentPurple),
                    title: const Text('Trusted Devices & Sessions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Manage enrolled phones, tablets, and remote lock', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                    onTap: () => context.push('/devices'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // System Status
            Text('VAULT SYSTEM STATUS', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Material(
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dns_outlined, color: AppTheme.primaryLight),
                    title: const Text('Database Connection', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: Text(
                      _dbStatus,
                      style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const Divider(color: AppTheme.border, height: 1),
                  const ListTile(
                    leading: Icon(Icons.security, color: AppTheme.accentGreen),
                    title: Text('Storage Encryption', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: Text(
                      'Isolated Local / S3 Ready',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Official DHA Vault Branding / About
            Center(
              child: Column(
                children: [
                  const DhaVaultLogo(size: 64),
                  const SizedBox(height: 12),
                  const Text(
                    'DHA Vault',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your Documents. Secured. Organized.\nInstantly Accessible.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Text(
                      'v1.0.0 • Military Grade AES-256-GCM',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Sign out
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentRed,
                side: const BorderSide(color: AppTheme.accentRed),
              ),
              onPressed: () async {
                final router = GoRouter.of(context);
                await ref.read(authProvider.notifier).logout();
                router.go('/welcome');
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Lock & Sign Out'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
