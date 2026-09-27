import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/family_provider.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';

class FamilyVaultScreen extends ConsumerStatefulWidget {
  const FamilyVaultScreen({super.key});

  @override
  ConsumerState<FamilyVaultScreen> createState() => _FamilyVaultScreenState();
}

class _FamilyVaultScreenState extends ConsumerState<FamilyVaultScreen>
    with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyProvider);
    final activeFamily = familyState.activeFamily;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.people_alt_rounded, color: AppTheme.accentAmber, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                activeFamily?.name ?? 'Family Vault',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_rounded, color: AppTheme.accentAmber),
            tooltip: 'Join Family',
            onPressed: () => _showAcceptInviteDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_business_rounded, color: Colors.white),
            tooltip: 'Create Family Vault',
            onPressed: () => _showCreateFamilyDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentAmber,
          labelColor: AppTheme.accentAmber,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.folder_shared_rounded), text: 'Documents'),
            Tab(icon: Icon(Icons.supervised_user_circle_rounded), text: 'Members'),
          ],
        ),
      ),
      body: familyState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentAmber))
          : activeFamily == null
              ? _buildEmptyFamilyState(context)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFamilyDocumentsTab(context, familyState),
                    _buildFamilyMembersTab(context, familyState),
                  ],
                ),
      floatingActionButton: activeFamily != null && activeFamily.canShare
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.accentAmber,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Share Document'),
              onPressed: () => _showShareDocumentDialog(context, activeFamily.id),
            )
          : null,
    );
  }

  Widget _buildEmptyFamilyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.family_restroom_rounded, size: 72, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No Family Vault Yet',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a Family Vault to securely share important identity, medical, and property records with trusted family members.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Create Family Vault', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showCreateFamilyDialog(context),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.key_rounded, color: AppTheme.accentAmber),
              label: const Text('Have an invitation token? Join here', style: TextStyle(color: AppTheme.accentAmber)),
              onPressed: () => _showAcceptInviteDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyDocumentsTab(BuildContext context, FamilyState state) {
    final docs = state.familyDocuments;

    if (docs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 64, color: Colors.white24),
            SizedBox(height: 12),
            Text('No documents shared with family yet', style: TextStyle(color: Colors.white60)),
            SizedBox(height: 4),
            Text('Tap "Share Document" below to share records', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final item = docs[index];
        final doc = item.document;

        return Card(
          color: AppTheme.surface,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              backgroundColor: AppTheme.accentAmber.withValues(alpha: 0.15),
              child: const Icon(Icons.description_rounded, color: AppTheme.accentAmber),
            ),
            title: Text(
              doc?.title ?? 'Document',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Shared by: ${item.sharedByEmail}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: item.permissions.map((p) => Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(p, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  )).toList(),
                ),
              ],
            ),
            trailing: state.activeFamily?.isOwner == true
                ? IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.accentRed),
                    tooltip: 'Revoke Access',
                    onPressed: () => _confirmRevokeDoc(context, state.activeFamily!.id, doc?.id ?? ''),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildFamilyMembersTab(BuildContext context, FamilyState state) {
    final members = state.members;
    final isOwner = state.activeFamily?.isOwner ?? false;

    return Column(
      children: [
        if (isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentAmber,
                  side: const BorderSide(color: AppTheme.accentAmber),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Invite Member by Email'),
                onPressed: () => _showInviteMemberDialog(context, state.activeFamily!.id),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return Card(
                color: AppTheme.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.border),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.white12,
                    child: Text(
                      member.email.isNotEmpty ? member.email[0].toUpperCase() : 'U',
                      style: const TextStyle(color: AppTheme.accentAmber, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    member.fullName ?? member.email,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    member.email,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: member.role == 'OWNER'
                              ? AppTheme.accentAmber.withValues(alpha: 0.2)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          member.role,
                          style: TextStyle(
                            color: member.role == 'OWNER' ? AppTheme.accentAmber : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isOwner && member.role != 'OWNER')
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white60),
                          onSelected: (val) {
                            if (val == 'remove') {
                              _confirmRemoveMember(context, state.activeFamily!.id, member.userId);
                            } else if (val == 'make_member') {
                              ref.read(familyProvider.notifier).updateMemberRole(state.activeFamily!.id, member.userId, 'MEMBER');
                            } else if (val == 'make_viewer') {
                              ref.read(familyProvider.notifier).updateMemberRole(state.activeFamily!.id, member.userId, 'VIEWER');
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'make_member', child: Text('Set Role: MEMBER')),
                            const PopupMenuItem(value: 'make_viewer', child: Text('Set Role: VIEWER')),
                            const PopupMenuItem(value: 'remove', child: Text('Remove from Family', style: TextStyle(color: AppTheme.accentRed))),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCreateFamilyDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Create Family Vault', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. My Family Vault',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentAmber)),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber, foregroundColor: Colors.black),
            child: const Text('Create'),
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                await ref.read(familyProvider.notifier).createFamily(controller.text.trim());
              }
            },
          ),
        ],
      ),
    );
  }

  void _showInviteMemberDialog(BuildContext context, String familyId) {
    final emailController = TextEditingController();
    String role = 'MEMBER';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          title: const Text('Invite Family Member', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: role,
                dropdownColor: AppTheme.surfaceElevated,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Role',
                  labelStyle: TextStyle(color: Colors.white60),
                ),
                items: const [
                  DropdownMenuItem(value: 'MEMBER', child: Text('Member (View & Share)')),
                  DropdownMenuItem(value: 'VIEWER', child: Text('Viewer (Read Only)')),
                ],
                onChanged: (val) => setDialogState(() => role = val ?? 'MEMBER'),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber, foregroundColor: Colors.black),
              child: const Text('Send Invitation'),
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  Navigator.pop(ctx);
                  final token = await ref.read(familyProvider.notifier).inviteMember(familyId, email, role);
                  if (token != null && context.mounted) {
                    _showTokenCopyDialog(context, token);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTokenCopyDialog(BuildContext context, String token) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Invitation Created', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Secure single-use token generated (valid for 7 days):',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
              child: SelectableText(
                token,
                style: const TextStyle(color: AppTheme.accentAmber, fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber, foregroundColor: Colors.black),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Token'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: token));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invitation token copied to clipboard')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAcceptInviteDialog(BuildContext context) {
    final tokenController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Join Family Vault', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: tokenController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Paste Invitation Token',
            labelStyle: TextStyle(color: Colors.white60),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber, foregroundColor: Colors.black),
            child: const Text('Join Vault'),
            onPressed: () async {
              if (tokenController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                final success = await ref.read(familyProvider.notifier).acceptInvitation(tokenController.text.trim());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Joined family vault successfully!' : 'Failed to join: Invalid or expired token'),
                      backgroundColor: success ? AppTheme.accentGreen : AppTheme.accentRed,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showShareDocumentDialog(BuildContext context, String familyId) {
    final docsAsync = ref.read(documentsListProvider);
    final userDocs = docsAsync.value ?? [];

    if (userDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload documents to your personal vault first.')),
      );
      return;
    }

    String selectedDocId = userDocs.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          title: const Text('Share to Family Vault', style: TextStyle(color: Colors.white)),
          content: DropdownButtonFormField<String>(
            initialValue: selectedDocId,
            dropdownColor: AppTheme.surfaceElevated,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Select Document', labelStyle: TextStyle(color: Colors.white60)),
            items: userDocs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.title))).toList(),
            onChanged: (val) => setDialogState(() => selectedDocId = val ?? selectedDocId),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber, foregroundColor: Colors.black),
              child: const Text('Share'),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(familyProvider.notifier).shareDocumentToFamily(familyId, selectedDocId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRevokeDoc(BuildContext context, String familyId, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Revoke Document Access?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove access to this document for all family members. The original document remains safe in your personal vault.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(child: const Text('Cancel', style: TextStyle(color: Colors.white60)), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: Colors.white),
            child: const Text('Revoke Access'),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(familyProvider.notifier).revokeFamilyDocument(familyId, docId);
            },
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMember(BuildContext context, String familyId, String memberUserId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Remove Family Member?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This member will lose access to all documents shared in this Family Vault.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(child: const Text('Cancel', style: TextStyle(color: Colors.white60)), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: Colors.white),
            child: const Text('Remove Member'),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(familyProvider.notifier).removeMember(familyId, memberUserId);
            },
          ),
        ],
      ),
    );
  }
}
