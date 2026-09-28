import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/document.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/sync_provider.dart';
import '../../core/storage/secure_vault_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coach_marks/coach_mark_model.dart';
import '../../widgets/coach_marks/coach_mark_overlay.dart';
import '../../widgets/dha_vault_logo.dart';
import '../documents/upload_document_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _storage = SecureVaultStorage();
  final _scrollController = ScrollController();

  final _addFileKey = GlobalKey();
  final _scanKey = GlobalKey();
  final _shareKey = GlobalKey();
  final _searchKey = GlobalKey();
  final _recentDocsKey = GlobalKey();

  OverlayEntry? _coachMarkOverlay;
  bool _tourChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTimeTour();
    });
  }

  @override
  void dispose() {
    _hideCoachMarks();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkFirstTimeTour() async {
    if (!mounted || _tourChecked) return;
    _tourChecked = true;

    final userId = ref.read(authProvider).user?.id ?? 'default';
    final completed = await _storage.isCoachMarksCompleted(userId);

    if (!completed && mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        _startCoachMarks(userId);
      }
    }
  }

  void _startCoachMarks(String userId) {
    _hideCoachMarks();

    final steps = [
      CoachMarkStep(
        title: 'Add File',
        description: 'Upload PDFs, images, or documents to your secure vault.',
        targetKey: _addFileKey,
        position: CoachMarkPosition.below,
        targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        borderRadius: 14,
      ),
      CoachMarkStep(
        title: 'Scan Document',
        description: 'Scan physical documents with your camera and save them directly to your vault.',
        targetKey: _scanKey,
        position: CoachMarkPosition.below,
        targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        borderRadius: 14,
      ),
      CoachMarkStep(
        title: 'Share',
        description: 'Share your documents directly through apps installed on your phone.',
        targetKey: _shareKey,
        position: CoachMarkPosition.below,
        targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        borderRadius: 14,
      ),
      CoachMarkStep(
        title: 'Search',
        description: 'Find your documents quickly using names, details, and document information.',
        targetKey: _searchKey,
        position: CoachMarkPosition.below,
        targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        borderRadius: 14,
      ),
      CoachMarkStep(
        title: 'Your Documents',
        description: 'Quickly access your recently added documents from your vault.',
        targetKey: _recentDocsKey,
        position: CoachMarkPosition.below,
        targetPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        borderRadius: 14,
      ),
    ];

    _coachMarkOverlay = OverlayEntry(
      builder: (context) => CoachMarkOverlay(
        steps: steps,
        onFinish: () async {
          _hideCoachMarks();
          await _storage.setCoachMarksCompleted(userId);
        },
        onSkip: () async {
          _hideCoachMarks();
          await _storage.setCoachMarksCompleted(userId);
        },
      ),
    );

    Overlay.of(context).insert(_coachMarkOverlay!);
  }

  void _hideCoachMarks() {
    _coachMarkOverlay?.remove();
    _coachMarkOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final statsAsync = ref.watch(vaultStatsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final recentAsync = ref.watch(recentlyViewedDocumentsProvider);
    final allDocsAsync = ref.watch(documentsListProvider);
    final notifsState = ref.watch(notificationsProvider);
    final syncState = ref.watch(syncProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const DhaVaultLogo(size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DHA Vault',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          fontSize: 17,
                        ),
                  ),
                  Text(
                    authState.user?.fullName != null
                        ? 'Welcome back, ${authState.user!.fullName}'
                        : 'Encrypted Digital Locker',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Subtle Sync Status Pill
          GestureDetector(
            onTap: () => context.push('/backup-sync'),
            child: Container(
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: syncState.status?.status == 'SYNCED'
                    ? AppTheme.accentGreen.withValues(alpha: 0.15)
                    : syncState.status?.status == 'CONFLICT'
                        ? AppTheme.accentRed.withValues(alpha: 0.15)
                        : AppTheme.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: syncState.status?.status == 'SYNCED'
                      ? AppTheme.accentGreen.withValues(alpha: 0.4)
                      : syncState.status?.status == 'CONFLICT'
                          ? AppTheme.accentRed.withValues(alpha: 0.4)
                          : AppTheme.accentAmber.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    syncState.status?.status == 'SYNCED'
                        ? 'SYNCED'
                        : syncState.status?.status == 'CONFLICT'
                            ? 'CONFLICT'
                            : 'SYNCING',
                    style: TextStyle(
                      color: syncState.status?.status == 'SYNCED'
                          ? AppTheme.accentGreen
                          : syncState.status?.status == 'CONFLICT'
                              ? AppTheme.accentRed
                              : AppTheme.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Notification Center Icon with Unread Badge
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary, size: 22),
                if (notifsState.unreadCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.accentRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '${notifsState.unreadCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vaultStatsProvider);
          ref.invalidate(categoriesProvider);
          ref.invalidate(documentsListProvider);
          ref.invalidate(recentlyViewedDocumentsProvider);
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input -> navigates to DocumentsScreen with search
              Container(
                key: _searchKey,
                child: TextField(
                  onSubmitted: (val) {
                    ref.read(documentFilterProvider.notifier).update(
                          (state) => state.copyWith(searchQuery: val),
                        );
                    context.go('/documents');
                  },
                  decoration: InputDecoration(
                    hintText: 'Search documents, types, or categories...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.tune, color: AppTheme.textMuted, size: 18),
                      onPressed: () => context.go('/documents'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Vault Statistics Card (Total, Valid, Expiring Soon, Expired, Favorites)
              statsAsync.when(
                data: (stats) => Column(
                  children: [
                    _buildStatsCard(context, ref, stats),
                    if (stats.attentionRequired.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildAttentionRequiredCard(context, stats.attentionRequired),
                    ],
                  ],
                ),
                loading: () => const LinearProgressIndicator(color: AppTheme.primary),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 24),

              // Quick Action Buttons
              _buildQuickActions(context, ref),
              const SizedBox(height: 24),

              // Quick Access (Pinned Favorites) Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppTheme.accentAmber, size: 18),
                      const SizedBox(width: 6),
                      Text('Quick Access', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(documentFilterProvider.notifier).update(
                            (s) => s.copyWith(isFavorite: true),
                          );
                      context.go('/documents');
                    },
                    child: const Text('View All', style: TextStyle(color: AppTheme.primaryLight, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              allDocsAsync.when(
                data: (docs) {
                  final favorites = docs.where((d) => d.isFavorite).toList();
                  if (favorites.isEmpty) {
                    return _buildEmptyFavoritesCard(context);
                  }
                  return _buildQuickAccessGrid(context, favorites);
                },
                loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 24),

              // Categories Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Categories', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => context.go('/documents'),
                    child: const Text('View All', style: TextStyle(color: AppTheme.primaryLight, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (cats) => _buildCategoriesGrid(context, ref, cats),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // Recently Viewed Documents Section
              Container(
                key: _recentDocsKey,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, color: AppTheme.primaryLight, size: 18),
                        const SizedBox(width: 6),
                        Text('Recently Viewed', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.go('/documents'),
                      child: const Text('See All', style: TextStyle(color: AppTheme.primaryLight, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              recentAsync.when(
                data: (docs) {
                  if (docs.isEmpty) {
                    // Fall back to first few documents from list if recent audit log is empty
                    return allDocsAsync.when(
                      data: (all) {
                        if (all.isEmpty) return _buildEmptyDocuments(context);
                        return Column(
                          children: all.take(5).map((doc) => _buildDocumentCard(context, doc)).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Error loading documents: $e'),
                    );
                  }
                  return Column(
                    children: docs.map((doc) => _buildDocumentCard(context, doc)).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading documents: $e'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => UploadDocumentSheet.showOptions(context),
        icon: const Icon(Icons.add_moderator, color: Colors.white, size: 20),
        label: const Text('Add Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, WidgetRef ref, VaultStats stats) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('TOTAL', '${stats.totalDocuments}', Icons.folder_outlined, AppTheme.primaryLight, () {
                ref.read(documentFilterProvider.notifier).state = DocumentFilterState();
                context.go('/documents');
              }),
              Container(height: 36, width: 1, color: AppTheme.border),
              _buildStatItem('VALID', '${stats.validDocuments}', Icons.check_circle_outline, AppTheme.accentGreen, () {
                ref.read(documentFilterProvider.notifier).state = DocumentFilterState();
                context.go('/documents');
              }),
              Container(height: 36, width: 1, color: AppTheme.border),
              _buildStatItem(
                'EXPIRING',
                '${stats.expiringSoonDocuments}',
                Icons.event_outlined,
                stats.expiringSoonDocuments > 0 ? AppTheme.accentAmber : AppTheme.textMuted,
                () {
                  ref.read(documentFilterProvider.notifier).update((s) => s.copyWith(isExpiringSoon: true, expiryDays: 30));
                  context.go('/documents');
                },
              ),
              Container(height: 36, width: 1, color: AppTheme.border),
              _buildStatItem(
                'EXPIRED',
                '${stats.expiredDocuments}',
                Icons.warning_amber_rounded,
                stats.expiredDocuments > 0 ? AppTheme.accentRed : AppTheme.textMuted,
                () {
                  ref.read(documentFilterProvider.notifier).update((s) => s.copyWith(isExpired: true));
                  context.go('/documents');
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_done_outlined, size: 14, color: AppTheme.accentGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Storage Encrypted: ${stats.formattedStorage}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
              Text(
                '${stats.favoriteDocuments} Pinned Favorites',
                style: const TextStyle(fontSize: 11, color: AppTheme.accentAmber, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _buildActionChip(
          key: _addFileKey,
          icon: Icons.add_photo_alternate_outlined,
          label: 'Add File',
          color: AppTheme.primary,
          onTap: () => UploadDocumentSheet.showOptions(context),
        ),
        const SizedBox(width: 10),
        _buildActionChip(
          key: _scanKey,
          icon: Icons.document_scanner,
          label: 'Scan Document',
          color: AppTheme.accentGreen,
          onTap: () => UploadDocumentSheet.show(context, UploadSource.scan),
        ),
        const SizedBox(width: 10),
        _buildActionChip(
          key: _shareKey,
          icon: Icons.share_outlined,
          label: 'Share',
          color: AppTheme.accentPurple,
          onTap: () => context.go('/shared'),
        ),
      ],
    );
  }

  Widget _buildActionChip({
    Key? key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Container(
        key: key,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context, List<DocumentModel> favorites) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: favorites.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final doc = favorites[index];
          final isPdf = doc.fileType == 'PDF' || doc.mimeType.contains('pdf');
          return InkWell(
            onTap: () => context.push('/document-details/${doc.id}', extra: doc),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 130,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        isPdf ? Icons.picture_as_pdf : Icons.image,
                        color: isPdf ? AppTheme.accentRed : AppTheme.primaryLight,
                        size: 20,
                      ),
                      const Icon(Icons.star, color: AppTheme.accentAmber, size: 14),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      Text(
                        doc.formattedFileSize,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyFavoritesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.star_border, color: AppTheme.accentAmber, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pin your Aadhaar, PAN, Passport, or License to Quick Access for instant 1-tap view.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid(BuildContext context, WidgetRef ref, List categories) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return InkWell(
            onTap: () {
              ref.read(documentFilterProvider.notifier).update(
                    (state) => state.copyWith(categoryId: cat.id),
                  );
              context.go('/documents');
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 110,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder, color: AppTheme.primaryLight, size: 16),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      Text(
                        '${cat.documentCount} items',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttentionRequiredCard(
      BuildContext context, List<Map<String, dynamic>> urgentDocs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.accentAmber, size: 18),
              const SizedBox(width: 8),
              Text(
                'ATTENTION REQUIRED',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.accentAmber,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${urgentDocs.length} urgent',
                  style: const TextStyle(
                    color: AppTheme.accentAmber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...urgentDocs.map((doc) {
            final isExpired = doc['status'] == 'EXPIRED';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(
                    isExpired ? Icons.cancel_outlined : Icons.timer_outlined,
                    color: isExpired ? AppTheme.accentRed : AppTheme.accentAmber,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      doc['title'] ?? 'Document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      final id = doc['id'];
                      if (id != null) {
                        context.push('/document-details/$id');
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isExpired ? 'Renew' : 'Review',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isExpired
                              ? AppTheme.accentRed
                              : AppTheme.accentAmber,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, DocumentModel doc) {
    final isPdf = doc.fileType == 'PDF' || doc.mimeType.contains('pdf');

    Widget? ocrBadge;
    if (doc.isOcrCompleted) {
      ocrBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 10, color: AppTheme.accentGreen),
            const SizedBox(width: 3),
            Text(
              doc.ocrConfidencePercentage.isNotEmpty ? doc.ocrConfidencePercentage : 'Ready',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGreen,
              ),
            ),
          ],
        ),
      );
    } else if (doc.isOcrProcessing) {
      ocrBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '◌ Reading',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryLight,
          ),
        ),
      );
    } else if (doc.isOcrFailed) {
      ocrBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentAmber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '⚠ Review',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.accentAmber,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => context.push('/document-details/${doc.id}', extra: doc),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPdf
                  ? AppTheme.accentRed.withValues(alpha: 0.15)
                  : AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf : Icons.image,
              color: isPdf ? AppTheme.accentRed : AppTheme.primaryLight,
              size: 22,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  doc.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              if (ocrBadge != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => context.push('/document-intelligence/${doc.id}', extra: doc),
                  child: ocrBadge,
                ),
              ],
            ],
          ),
          subtitle: Text(
            '${doc.formattedFileSize} • ${doc.category?.name ?? doc.documentType}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          trailing: doc.isFavorite
              ? const Icon(Icons.star, color: AppTheme.accentAmber, size: 18)
              : const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
        ),
      ),
    );
  }

  Widget _buildEmptyDocuments(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.shield_outlined, size: 40, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          const Text('Your Vault is Empty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 6),
          const Text(
            'Upload your official identity, certificates, or vehicle documents to lock them securely.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => UploadDocumentSheet.showOptions(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Document'),
          ),
        ],
      ),
    );
  }
}
