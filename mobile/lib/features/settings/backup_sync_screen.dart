import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/backup_provider.dart';
import '../../providers/sync_provider.dart';
import '../../theme/app_theme.dart';

class BackupSyncScreen extends ConsumerWidget {
  const BackupSyncScreen({super.key});

  void _confirmRestore(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Restore Cloud Vault?'),
        content: const Text(
          'This will download your latest AES-256-GCM encrypted cloud backup, verify the cryptographic manifest, and rebuild your local vault index. Existing local files will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(backupProvider.notifier).restoreVault();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Vault index restored successfully!' : 'Restore failed'),
                    backgroundColor: success ? AppTheme.accentGreen : AppTheme.accentRed,
                  ),
                );
              }
            },
            child: const Text('Restore Now'),
          ),
        ],
      ),
    );
  }

  void _clearLocalCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Clear Local Fast View Cache?'),
        content: const Text(
          'This clears temporarily cached preview images and decrypted in-memory buffers to free space on this device.\n\nNOTE: Your original encrypted documents remain safe in the vault.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Local Fast View cache cleared'), backgroundColor: AppTheme.accentGreen),
              );
            },
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final backupState = ref.watch(backupProvider);
    final storage = backupState.storage;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Backup & Cloud Sync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(syncProvider.notifier).fetchSyncStatus();
              ref.read(backupProvider.notifier).fetchStatus();
              ref.read(backupProvider.notifier).fetchStorage();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sync Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            syncState.status?.status == 'SYNCED'
                                ? Icons.cloud_done
                                : syncState.status?.status == 'CONFLICT'
                                    ? Icons.warning_amber
                                    : Icons.sync,
                            color: syncState.status?.status == 'SYNCED'
                                ? AppTheme.accentGreen
                                : syncState.status?.status == 'CONFLICT'
                                    ? AppTheme.accentRed
                                    : AppTheme.accentAmber,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            syncState.status?.status == 'SYNCED'
                                ? 'Vault Synchronized'
                                : syncState.status?.status == 'CONFLICT'
                                    ? 'Sync Conflict Detected'
                                    : 'Sync In Progress',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      if (syncState.isSyncing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${syncState.status?.syncedDocuments ?? 0} of ${syncState.status?.totalDocuments ?? 0} documents in sync • ${syncState.status?.pendingCount ?? 0} pending',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: syncState.isSyncing
                          ? null
                          : () => ref.read(syncProvider.notifier).startSync(),
                      icon: const Icon(Icons.sync, size: 16),
                      label: Text(syncState.isSyncing ? 'Syncing...' : 'Sync Now'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Cloud Backup Preferences
            Text('BACKUP SETTINGS', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.cloud_upload_outlined, color: AppTheme.primaryLight),
                    title: const Text('Cloud Backup Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      backupState.isCloudBackupEnabled
                          ? 'Encrypted copies stored in private cloud'
                          : 'Local-only mode (documents stay on device)',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    value: backupState.isCloudBackupEnabled,
                    activeThumbColor: AppTheme.accentGreen,
                    onChanged: (val) {
                      ref.read(backupProvider.notifier).toggleCloudBackup(val);
                    },
                  ),
                  const Divider(color: AppTheme.border, height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.wifi, color: AppTheme.accentPurple),
                    title: const Text('Back Up on Wi-Fi Only', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Avoid mobile data usage for large backups', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    value: backupState.isWifiOnly,
                    activeThumbColor: AppTheme.accentPurple,
                    onChanged: (val) {
                      ref.read(backupProvider.notifier).toggleWifiOnly(val);
                    },
                  ),
                  const Divider(color: AppTheme.border, height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.autorenew, color: AppTheme.accentAmber),
                    title: const Text('Auto Backup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Automatically back up new scans and changes', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    value: backupState.isAutoBackup,
                    activeThumbColor: AppTheme.accentAmber,
                    onChanged: (val) {
                      ref.read(backupProvider.notifier).toggleAutoBackup(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Storage Breakdown
            Text('VAULT STORAGE USAGE', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${storage?.formattedUsed ?? "0 MB"} of ${storage?.formattedQuota ?? "10 GB"} used',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '${((storage?.usedPercentage ?? 0) * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: storage?.usedPercentage ?? 0.05,
                      backgroundColor: AppTheme.surfaceElevated,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryLight),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _storageStat('Documents', '${(storage?.documents.bytes ?? 0) ~/ (1024 * 1024)} MB', AppTheme.primaryLight),
                      _storageStat('Versions', '${(storage?.versions.bytes ?? 0) ~/ (1024 * 1024)} MB', AppTheme.accentPurple),
                      _storageStat('Backups', '${(storage?.backups.bytes ?? 0) ~/ (1024 * 1024)} MB', AppTheme.accentGreen),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.border, height: 1),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => _clearLocalCacheDialog(context),
                    icon: const Icon(Icons.cleaning_services_outlined, size: 16, color: AppTheme.textMuted),
                    label: const Text('Clear local Fast View cache (Keep cloud originals)', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions & Cloud Restore
            Text('ACTIONS & RESTORE', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cloud_download_outlined, color: AppTheme.accentGreen),
                    title: const Text('Restore Vault from Backup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Recover documents from your latest encrypted cloud backup', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                    onTap: () => _confirmRestore(context, ref),
                  ),
                  const Divider(color: AppTheme.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.backup_outlined, color: AppTheme.primaryLight),
                    title: const Text('Create Immediate Backup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Manually encrypt and archive all documents right now', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    trailing: ElevatedButton(
                      onPressed: backupState.isBackingUp
                          ? null
                          : () async {
                              final ok = await ref.read(backupProvider.notifier).startBackup();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok ? 'Backup completed!' : 'Backup failed'),
                                    backgroundColor: ok ? AppTheme.accentGreen : AppTheme.accentRed,
                                  ),
                                );
                              }
                            },
                      child: Text(backupState.isBackingUp ? 'Archiving...' : 'Back Up'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Privacy Guarantee Notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock, color: AppTheme.accentGreen, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your documents are encrypted before cloud backup using AES-256-GCM. DHA Vault does not expose your cloud storage credentials to any client device.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _storageStat(String label, String value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
