import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../core/api/api_endpoints.dart';
import '../../models/document.dart';
import '../../models/document_share.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/shares_provider.dart';
import '../../theme/app_theme.dart';

class SharedScreen extends ConsumerStatefulWidget {
  const SharedScreen({super.key});

  @override
  ConsumerState<SharedScreen> createState() => _SharedScreenState();
}

class _SharedScreenState extends ConsumerState<SharedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _publicShares = [];
  bool _isLoadingPublic = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchPublicShares();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPublicShares() async {
    final client = ref.read(apiClientProvider);
    try {
      final res = await client.dio.get(ApiEndpoints.myShares);
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _publicShares = res.data as List;
          _isLoadingPublic = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPublic = false);
    }
  }

  Future<void> _revokePublicShare(String id) async {
    final client = ref.read(apiClientProvider);
    try {
      await client.dio.post(ApiEndpoints.revokeShare(id));
      _fetchPublicShares();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Secure share link revoked immediately'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _showCreateUserShareDialog() async {
    final docsAsync = ref.read(documentsListProvider);
    final docs = docsAsync.value ?? [];

    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No documents available in vault to share')),
      );
      return;
    }

    String selectedDocId = docs.first.id;
    final emailController = TextEditingController();
    final watermarkController = TextEditingController();
    int expiresInHours = 24;
    int maxViews = 5;
    bool allowDownload = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Share to DHA Vault User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Document:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                DropdownButton<String>(
                  value: selectedDocId,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceElevated,
                  items: docs.map((d) {
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text(d.title, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedDocId = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Recipient Email',
                    hintText: 'user@example.com',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Expiration Period:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                DropdownButton<int>(
                  value: expiresInHours,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceElevated,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 Hour')),
                    DropdownMenuItem(value: 24, child: Text('24 Hours (1 Day)')),
                    DropdownMenuItem(value: 72, child: Text('72 Hours (3 Days)')),
                    DropdownMenuItem(value: 168, child: Text('7 Days')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => expiresInHours = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Maximum Allowed Views:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                DropdownButton<int>(
                  value: maxViews,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceElevated,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 View (Single-Use)')),
                    DropdownMenuItem(value: 3, child: Text('3 Views')),
                    DropdownMenuItem(value: 5, child: Text('5 Views')),
                    DropdownMenuItem(value: 10, child: Text('10 Views')),
                    DropdownMenuItem(value: 100, child: Text('Unlimited (100)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => maxViews = val);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow Download', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Permit saving original decrypted file', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  value: allowDownload,
                  onChanged: (val) => setDialogState(() => allowDownload = val),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: watermarkController,
                  decoration: const InputDecoration(
                    labelText: 'Dynamic Watermark (Optional)',
                    hintText: 'e.g. CONFIDENTIAL - FOR REVIEW ONLY',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) return;
                Navigator.pop(ctx);

                final ok = await ref.read(sharesProvider.notifier).createUserShare(
                  documentId: selectedDocId,
                  recipientEmail: email,
                  permissions: allowDownload ? ['VIEW', 'DOWNLOAD'] : ['VIEW'],
                  expiresInHours: expiresInHours,
                  maxViews: maxViews,
                  allowDownload: allowDownload,
                  watermarkText: watermarkController.text.trim().isNotEmpty ? watermarkController.text.trim() : null,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Encrypted share sent to $email' : 'Failed to create share'),
                      backgroundColor: ok ? AppTheme.accentGreen : AppTheme.accentRed,
                    ),
                  );
                }
              },
              child: const Text('Send Encrypted Share'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sharesState = ref.watch(sharesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Secure Sharing Hub'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryLight,
          tabs: [
            Tab(
              text: 'Incoming (${sharesState.incomingShares.length})',
              icon: const Icon(Icons.call_received, size: 18),
            ),
            Tab(
              text: 'Outgoing (${sharesState.outgoingShares.length})',
              icon: const Icon(Icons.call_made, size: 18),
            ),
            Tab(
              text: 'Public Links (${_publicShares.length})',
              icon: const Icon(Icons.link, size: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              ref.read(sharesProvider.notifier).fetchShares();
              _fetchPublicShares();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Incoming Shares
          sharesState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : sharesState.incomingShares.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceElevated,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Incoming Shared Documents',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'When other DHA Vault users share documents directly with you, they will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: sharesState.incomingShares.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final share = sharesState.incomingShares[index];
                        return _buildIncomingShareCard(context, share);
                      },
                    ),

          // Tab 2: Outgoing Shares
          sharesState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : sharesState.outgoingShares.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceElevated,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send_outlined, size: 48, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Outgoing Shares',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Share any vault document securely with another DHA Vault account.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _showCreateUserShareDialog,
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('Share Document to User'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: sharesState.outgoingShares.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final share = sharesState.outgoingShares[index];
                        return _buildOutgoingShareCard(context, share);
                      },
                    ),

          // Tab 3: Public Links
          _isLoadingPublic
              ? const Center(child: CircularProgressIndicator())
              : _publicShares.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No public web links created.\nUse the document details screen to generate token links.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _publicShares.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final share = _publicShares[index];
                        return _buildPublicLinkCard(context, share);
                      },
                    ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserShareDialog,
        backgroundColor: AppTheme.primaryLight,
        icon: const Icon(Icons.add_moderator, color: Colors.white),
        label: const Text('Share to User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildIncomingShareCard(BuildContext context, DocumentShareModel share) {
    final df = DateFormat('dd MMM, HH:mm');
    Color statusColor = share.status == 'ACTIVE' ? AppTheme.accentGreen : AppTheme.accentRed;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  share.documentTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(share.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'From: ${share.ownerEmail ?? "Vault User"} • ${share.documentCategory}',
            style: const TextStyle(color: AppTheme.primaryLight, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Permissions: ${share.permissions.join(", ")} • Views: ${share.viewCount} / ${share.maxViews ?? "∞"}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (share.expiresAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Expires: ${df.format(share.expiresAt!)}',
              style: TextStyle(
                color: share.isExpired ? AppTheme.accentRed : AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
          if (share.watermarkText != null) ...[
            const SizedBox(height: 4),
            Text(
              'Watermark: "${share.watermarkText}"',
              style: const TextStyle(color: AppTheme.accentAmber, fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                label: const Text('Open Document'),
                onPressed: share.status != 'ACTIVE'
                    ? null
                    : () async {
                        final data = await ref.read(sharesProvider.notifier).openShare(share.id);
                        if (context.mounted) {
                          final doc = share.document ??
                              (data != null && data['document'] != null
                                  ? DocumentModel.fromJson(data['document'] as Map<String, dynamic>)
                                  : null);
                          if (doc != null) {
                            context.push('/document-viewer/${doc.id}', extra: doc);
                          }
                        }
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingShareCard(BuildContext context, DocumentShareModel share) {
    final df = DateFormat('dd MMM, HH:mm');
    Color statusColor = share.status == 'ACTIVE' ? AppTheme.accentGreen : AppTheme.accentRed;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  share.documentTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(share.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Recipient: ${share.recipientEmail ?? "User"}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Permissions: ${share.permissions.join(", ")} • Views: ${share.viewCount} / ${share.maxViews ?? "∞"}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (share.expiresAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Expires: ${df.format(share.expiresAt!)}',
              style: TextStyle(
                color: share.isExpired ? AppTheme.accentRed : AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (share.status == 'ACTIVE')
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentRed,
                    side: const BorderSide(color: AppTheme.accentRed),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 14),
                  label: const Text('Revoke Share', style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        title: const Text('Revoke Document Access?'),
                        content: Text('The recipient will immediately lose the ability to view or download "${share.documentTitle}".'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Revoke Now'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref.read(sharesProvider.notifier).revokeShare(share.id);
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPublicLinkCard(BuildContext context, dynamic share) {
    final dateFormat = DateFormat('dd MMM, HH:mm');
    final isRevoked = share['isRevoked'] == true;
    final docTitle = share['document']?['title'] ?? 'Shared File';
    final token = share['token'] as String;
    final useCount = share['useCount'] ?? 0;
    final maxUses = share['maxUses'];
    final expiresAt = share['expiresAt'] != null ? DateTime.tryParse(share['expiresAt']) : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final publicUrl = '${AppConfig.apiBaseUrl}${ApiEndpoints.publicShare(token)}';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  docTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    decoration: isRevoked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              _buildPublicStatusBadge(isRevoked, isExpired),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Token: ${token.substring(0, 8)}... • Views: $useCount / ${maxUses ?? "Unlimited"}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (expiresAt != null)
            Text(
              'Expires: ${dateFormat.format(expiresAt)}',
              style: TextStyle(
                color: isExpired ? AppTheme.accentRed : AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          const SizedBox(height: 10),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: publicUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share URL copied to clipboard')),
                  );
                },
              ),
              if (!isRevoked && !isExpired) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentRed,
                    side: const BorderSide(color: AppTheme.accentRed),
                  ),
                  onPressed: () => _revokePublicShare(share['id']),
                  child: const Text('Revoke', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPublicStatusBadge(bool isRevoked, bool isExpired) {
    if (isRevoked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('REVOKED', style: TextStyle(color: AppTheme.accentRed, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    } else if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentAmber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('EXPIRED', style: TextStyle(color: AppTheme.accentAmber, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('ACTIVE', style: TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }
  }
}
