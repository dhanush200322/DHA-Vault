import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/emergency_access.dart';

class EmergencyAccessScreen extends ConsumerStatefulWidget {
  const EmergencyAccessScreen({super.key});

  @override
  ConsumerState<EmergencyAccessScreen> createState() => _EmergencyAccessScreenState();
}

class _EmergencyAccessScreenState extends ConsumerState<EmergencyAccessScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showAddDelegateDialog() async {
    final emailController = TextEditingController();
    final notesController = TextEditingController();
    int delayHours = 48;
    String scope = 'ALL_DOCUMENTS';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Add Emergency Delegate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A trusted delegate receives access to your vault ONLY after a security waiting period.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Delegate Email',
                    hintText: 'trusted.contact@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Activation Delay (Waiting Period):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                DropdownButton<int>(
                  value: delayHours,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceElevated,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Immediate (Testing/Urgent)')),
                    DropdownMenuItem(value: 24, child: Text('24 Hours')),
                    DropdownMenuItem(value: 48, child: Text('48 Hours (Recommended)')),
                    DropdownMenuItem(value: 72, child: Text('72 Hours')),
                    DropdownMenuItem(value: 168, child: Text('7 Days')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => delayHours = val);
                  },
                ),
                const SizedBox(height: 10),
                const Text('Access Scope:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                DropdownButton<String>(
                  value: scope,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceElevated,
                  items: const [
                    DropdownMenuItem(value: 'ALL_DOCUMENTS', child: Text('Full Vault Access')),
                    DropdownMenuItem(value: 'EMERGENCY_ONLY', child: Text('Emergency Identity Docs Only')),
                    DropdownMenuItem(value: 'SELECTED_DOCUMENTS', child: Text('Selected Documents')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => scope = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Instructions / Notes',
                    hintText: 'e.g. In case of medical emergency',
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
                if (emailController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final success = await ref.read(emergencyProvider.notifier).createEmergencyDelegate(
                  delegateEmail: emailController.text.trim(),
                  activationDelayHours: delayHours,
                  scope: scope,
                  notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Emergency delegate registered successfully' : 'Failed to add delegate'),
                      backgroundColor: success ? AppTheme.accentGreen : AppTheme.accentRed,
                    ),
                  );
                }
              },
              child: const Text('Authorize'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddRecoveryDialog() async {
    final emailController = TextEditingController();
    int expiresInDays = 30;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Setup Recovery Delegation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recovery delegates can assist in cryptographic vault recovery without gaining access to your master keys or password.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Delegate Email',
                  hintText: 'recovery.partner@example.com',
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Validity Duration:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              DropdownButton<int>(
                value: expiresInDays,
                isExpanded: true,
                dropdownColor: AppTheme.surfaceElevated,
                items: const [
                  DropdownMenuItem(value: 7, child: Text('7 Days')),
                  DropdownMenuItem(value: 30, child: Text('30 Days (Recommended)')),
                  DropdownMenuItem(value: 90, child: Text('90 Days')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => expiresInDays = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final success = await ref.read(emergencyProvider.notifier).createRecoveryDelegation(
                  delegateEmail: emailController.text.trim(),
                  expiresInDays: expiresInDays,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Recovery delegation request initiated' : 'Failed to setup recovery'),
                      backgroundColor: success ? AppTheme.accentGreen : AppTheme.accentRed,
                    ),
                  );
                }
              },
              child: const Text('Delegate'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emergencyProvider);
    final authState = ref.watch(authProvider);
    final myEmail = authState.user?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Emergency & Recovery'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryLight,
          tabs: const [
            Tab(text: 'Emergency Access', icon: Icon(Icons.health_and_safety_outlined)),
            Tab(text: 'Recovery Delegation', icon: Icon(Icons.shield_outlined)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              ref.read(emergencyProvider.notifier).fetchEmergencyDelegations();
              ref.read(emergencyProvider.notifier).fetchRecoveryDelegations();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Emergency Access
          state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.delegations.isEmpty
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
                              child: const Icon(Icons.medical_services_outlined, size: 48, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Emergency Contacts Configured',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Nominate a trusted individual to receive emergency vault access with a mandatory safety countdown.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _showAddDelegateDialog,
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Add Emergency Delegate'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.delegations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = state.delegations[index];
                        final isOwner = item.ownerEmail == myEmail;
                        return _buildEmergencyCard(context, item, isOwner);
                      },
                    ),

          // Tab 2: Recovery Delegation
          state.recoveryDelegations.isEmpty
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
                          child: const Icon(Icons.vpn_key_outlined, size: 48, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Recovery Delegations',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Setup a trusted recovery guardian who can co-sign account recovery without exposing your encryption keys.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _showAddRecoveryDialog,
                          icon: const Icon(Icons.shield_outlined),
                          label: const Text('Configure Guardian'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.recoveryDelegations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = state.recoveryDelegations[index];
                    final isOwner = item.ownerEmail == myEmail;
                    return _buildRecoveryCard(context, item, isOwner);
                  },
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddDelegateDialog();
          } else {
            _showAddRecoveryDialog();
          }
        },
        backgroundColor: AppTheme.primaryLight,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'New Delegate' : 'New Guardian',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmergencyCard(BuildContext context, EmergencyAccessModel item, bool isOwner) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    Color statusColor;
    switch (item.status) {
      case 'ACTIVE':
        statusColor = AppTheme.accentGreen;
        break;
      case 'TRIGGERED':
        statusColor = AppTheme.accentAmber;
        break;
      case 'REVOKED':
        statusColor = AppTheme.accentRed;
        break;
      default:
        statusColor = AppTheme.primaryLight;
    }

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
              Row(
                children: [
                  Icon(
                    item.status == 'ACTIVE' ? Icons.check_circle_outline : Icons.alarm,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOwner ? 'Delegate: ${item.delegateEmail}' : 'From Owner: ${item.ownerEmail}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Safety Delay: ${item.activationDelayHours} Hours • Scope: ${item.scope}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (item.triggeredAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Triggered: ${df.format(item.triggeredAt!)}',
              style: const TextStyle(color: AppTheme.accentAmber, fontSize: 12),
            ),
          ],
          if (item.activatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Activated: ${df.format(item.activatedAt!)}',
              style: const TextStyle(color: AppTheme.accentGreen, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // If triggered and user is the owner, they can CANCEL the activation during waiting period
              if (isOwner && item.status == 'TRIGGERED')
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel Activation'),
                  onPressed: () async {
                    final ok = await ref.read(emergencyProvider.notifier).cancelActivation(item.id);
                    if (context.mounted && ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Emergency activation cancelled'), backgroundColor: AppTheme.accentGreen),
                      );
                    }
                  },
                ),

              // If pending or active, and delegate wants to trigger emergency
              if (!isOwner && (item.status == 'PENDING' || item.status == 'ACTIVE'))
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentAmber),
                  icon: const Icon(Icons.emergency_outlined, size: 16),
                  label: const Text('Trigger Emergency Access'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        title: const Text('Trigger Emergency Access?'),
                        content: Text(
                          'The owner will be alerted immediately. If not cancelled within ${item.activationDelayHours} hours, you will gain access.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abort')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Confirm Trigger'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref.read(emergencyProvider.notifier).triggerActivation(item.id);
                    }
                  },
                ),

              // If fully activated, view scoped documents
              if (item.status == 'ACTIVE') ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.folder_shared_outlined, size: 16),
                  label: const Text('View Documents'),
                  onPressed: () async {
                    final docs = await ref.read(emergencyProvider.notifier).fetchScopedDocuments(item.id);
                    if (context.mounted) {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppTheme.surface,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (ctx) => Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Emergency Access Documents (${docs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              if (docs.isEmpty)
                                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No documents currently in emergency scope')))
                              else
                                ...docs.map((d) => ListTile(
                                      leading: const Icon(Icons.description, color: AppTheme.primaryLight),
                                      title: Text(d.title),
                                      subtitle: Text(d.category?.name ?? d.documentType),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        context.push('/document-viewer/${d.id}', extra: d);
                                      },
                                    )),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],

              // Owner Revocation option
              if (isOwner && item.status != 'REVOKED') ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    await ref.read(emergencyProvider.notifier).revokeEmergency(item.id);
                  },
                  child: const Text('Revoke', style: TextStyle(color: AppTheme.accentRed, fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryCard(BuildContext context, RecoveryDelegationModel item, bool isOwner) {
    final df = DateFormat('dd MMM yyyy');
    Color statusColor = item.status == 'ACCEPTED'
        ? AppTheme.accentGreen
        : item.status == 'REVOKED'
            ? AppTheme.accentRed
            : AppTheme.accentAmber;

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
              Text(
                isOwner ? 'Guardian: ${item.delegateEmail}' : 'Owner: ${item.ownerEmail}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.expiresAt != null ? 'Expires: ${df.format(item.expiresAt!)}' : 'No Expiration Set',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isOwner && item.status == 'PENDING')
                ElevatedButton(
                  onPressed: () async {
                    final ok = await ref.read(emergencyProvider.notifier).acceptRecovery(item.id);
                    if (context.mounted && ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Accepted recovery guardianship'), backgroundColor: AppTheme.accentGreen),
                      );
                    }
                  },
                  child: const Text('Accept Delegation'),
                ),
              if (isOwner && item.status != 'REVOKED') ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    await ref.read(emergencyProvider.notifier).revokeRecovery(item.id);
                  },
                  child: const Text('Revoke Guardian', style: TextStyle(color: AppTheme.accentRed, fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
