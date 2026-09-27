import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/device.dart';
import '../../providers/device_provider.dart';
import '../../theme/app_theme.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      case 'windows':
        return Icons.laptop_windows;
      case 'macos':
        return Icons.laptop_mac;
      default:
        return Icons.devices;
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showDeviceActions(DeviceModel device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(_getPlatformIcon(device.platform), color: AppTheme.primaryLight, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.deviceName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'ID: ${device.deviceId.substring(0, 8)}... • Active ${_formatTimeAgo(device.lastActiveAt)}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Icon(
                  device.isTrusted ? Icons.verified_user : Icons.gpp_bad,
                  color: device.isTrusted ? AppTheme.accentGreen : AppTheme.accentAmber,
                ),
                title: Text(device.isTrusted ? 'Mark as Untrusted' : 'Mark as Trusted'),
                subtitle: const Text('Untrusted devices require re-authentication for cloud sync', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(deviceProvider.notifier).toggleTrust(device.deviceId, !device.isTrusted);
                },
              ),
              const Divider(color: AppTheme.border),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: AppTheme.accentAmber),
                title: const Text('Remote Lock Device'),
                subtitle: const Text('Immediately locks the vault and rejects sessions on this device', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text('Remote Lock Device?'),
                      content: Text('Are you sure you want to lock "${device.deviceName}"? The app will close access immediately.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Lock Device'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(deviceProvider.notifier).remoteLockDevice(device.deviceId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Device locked remotely'), backgroundColor: AppTheme.accentAmber),
                      );
                    }
                  }
                },
              ),
              const Divider(color: AppTheme.border),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: AppTheme.accentRed),
                title: const Text('Revoke & Remove Device', style: TextStyle(color: AppTheme.accentRed)),
                subtitle: const Text('Permanently revokes all refresh tokens and access keys', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text('Revoke Device Access?'),
                      content: Text('Remove "${device.deviceName}"? It will no longer be able to sync or access your cloud vault.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Revoke Device'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(deviceProvider.notifier).revokeDevice(device.deviceId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Device access revoked'), backgroundColor: AppTheme.accentRed),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final devState = ref.watch(deviceProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Trusted Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(deviceProvider.notifier).fetchDevices(),
          ),
        ],
      ),
      body: devState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(deviceProvider.notifier).fetchDevices(),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                children: [
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined, color: AppTheme.primaryLight, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Multi-Device Vault Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              SizedBox(height: 2),
                              Text(
                                'Each enrolled device is isolated with its own authenticated session. Revoke any unrecognized device.',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('ENROLLED DEVICES (${devState.devices.length})', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  if (devState.devices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: const Text('No devices registered', style: TextStyle(color: AppTheme.textMuted)),
                    )
                  else
                    ...devState.devices.map((device) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: device.isLocked ? AppTheme.accentRed.withValues(alpha: 0.5) : AppTheme.border,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_getPlatformIcon(device.platform), color: AppTheme.primaryLight, size: 22),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  device.deviceName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (device.isLocked)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentRed.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'LOCKED',
                                    style: TextStyle(color: AppTheme.accentRed, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else if (device.isTrusted)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'TRUSTED',
                                    style: TextStyle(color: AppTheme.accentGreen, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            'Active ${_formatTimeAgo(device.lastActiveAt)} • Sync: ${device.syncStatus}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
                            onPressed: () => _showDeviceActions(device),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
