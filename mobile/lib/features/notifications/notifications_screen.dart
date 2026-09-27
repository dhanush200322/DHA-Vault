import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/notification.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);

    final todayItems = state.items.where((n) => n.isToday).toList();
    final earlierItems = state.items.where((n) => !n.isToday).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(
          'Notifications',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              },
              icon: const Icon(Icons.done_all_rounded, size: 16, color: AppTheme.primaryLight),
              label: const Text(
                'Mark All Read',
                style: TextStyle(color: AppTheme.primaryLight, fontSize: 13),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).fetchNotifications(),
        color: AppTheme.primary,
        backgroundColor: AppTheme.surfaceElevated,
        child: state.items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Notifications Yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Expiry alerts, scan updates, and shares will appear here.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  if (todayItems.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Today', todayItems.length),
                    const SizedBox(height: 8),
                    ...todayItems.map((item) => _buildNotificationCard(context, ref, item)),
                    const SizedBox(height: 24),
                  ],
                  if (earlierItems.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Earlier', earlierItems.length),
                    const SizedBox(height: 8),
                    ...earlierItems.map((item) => _buildNotificationCard(context, ref, item)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notif,
  ) {
    final typeConfig = _getTypeConfig(notif.type);
    final timeStr = DateFormat('h:mm a').format(notif.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: notif.isRead ? AppTheme.surface : AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notif.isRead
              ? AppTheme.border
              : AppTheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (!notif.isRead) {
              ref.read(notificationsProvider.notifier).markAsRead(notif.id);
            }
            final docId = notif.metadata?['documentId'];
            if (docId != null) {
              context.push('/documents/$docId');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeConfig.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeConfig.icon, color: typeConfig.color, size: 20),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: notif.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.message,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Unread dot
                if (!notif.isRead) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  _TypeConfig _getTypeConfig(String type) {
    switch (type) {
      case 'DOCUMENT_EXPIRING':
        return _TypeConfig(
          icon: Icons.warning_amber_rounded,
          color: AppTheme.accentAmber,
        );
      case 'DOCUMENT_EXPIRED':
        return _TypeConfig(
          icon: Icons.error_outline_rounded,
          color: AppTheme.accentRed,
        );
      case 'OCR_COMPLETE':
      case 'DOCUMENT_CLASSIFIED':
        return _TypeConfig(
          icon: Icons.check_circle_outline_rounded,
          color: AppTheme.accentGreen,
        );
      case 'SECURITY':
        return _TypeConfig(
          icon: Icons.lock_outline_rounded,
          color: AppTheme.accentPurple,
        );
      default:
        return _TypeConfig(
          icon: Icons.info_outline_rounded,
          color: AppTheme.primaryLight,
        );
    }
  }
}

class _TypeConfig {
  final IconData icon;
  final Color color;

  _TypeConfig({required this.icon, required this.color});
}
