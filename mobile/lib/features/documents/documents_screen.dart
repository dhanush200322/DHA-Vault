import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/document.dart';
import '../../providers/category_provider.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';
import 'upload_document_sheet.dart';

enum DocumentViewFilter {
  all,
  recent,
  favorites,
  expiring,
  archived,
}

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  DocumentViewFilter _activeFilter = DocumentViewFilter.all;
  int _expiryFilterDays = 30; // 30, 15, 7, 0 (expired)

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      ref.read(documentFilterProvider.notifier).update(
            (s) => s.copyWith(searchQuery: val.trim()),
          );
    });
  }

  void _selectFilter(DocumentViewFilter filter) {
    setState(() => _activeFilter = filter);
    final notifier = ref.read(documentFilterProvider.notifier);

    switch (filter) {
      case DocumentViewFilter.all:
        notifier.update((s) => s.copyWith(
              isFavorite: false,
              isExpiringSoon: false,
              isExpired: false,
              isArchived: false,
              clearExpiry: true,
            ));
        break;
      case DocumentViewFilter.recent:
        notifier.update((s) => s.copyWith(
              isFavorite: false,
              isExpiringSoon: false,
              isExpired: false,
              isArchived: false,
              clearExpiry: true,
            ));
        break;
      case DocumentViewFilter.favorites:
        notifier.update((s) => s.copyWith(
              isFavorite: true,
              isExpiringSoon: false,
              isExpired: false,
              isArchived: false,
              clearExpiry: true,
            ));
        break;
      case DocumentViewFilter.expiring:
        _applyExpiryDaysFilter(_expiryFilterDays);
        break;
      case DocumentViewFilter.archived:
        notifier.update((s) => s.copyWith(
              isFavorite: false,
              isExpiringSoon: false,
              isExpired: false,
              isArchived: true,
              clearExpiry: true,
            ));
        break;
    }
  }

  void _applyExpiryDaysFilter(int days) {
    setState(() => _expiryFilterDays = days);
    final notifier = ref.read(documentFilterProvider.notifier);
    if (days == 0) {
      notifier.update((s) => s.copyWith(
            isFavorite: false,
            isExpiringSoon: false,
            isExpired: true,
            isArchived: false,
            expiryDays: null,
          ));
    } else {
      notifier.update((s) => s.copyWith(
            isFavorite: false,
            isExpiringSoon: true,
            isExpired: false,
            isArchived: false,
            expiryDays: days,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsListProvider);
    final recentAsync = ref.watch(recentlyViewedDocumentsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final filterState = ref.watch(documentFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('DHA Vault Locker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 24, color: AppTheme.primaryLight),
            onPressed: () => UploadDocumentSheet.showOptions(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              ref.invalidate(documentsListProvider);
              ref.invalidate(recentlyViewedDocumentsProvider);
              ref.invalidate(vaultStatsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Box with Debouncing
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search filename, title, tags, or OCR...',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Primary Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildStatusChip('All', DocumentViewFilter.all),
                const SizedBox(width: 8),
                _buildStatusChip('Recent', DocumentViewFilter.recent),
                const SizedBox(width: 8),
                _buildStatusChip('Favorites', DocumentViewFilter.favorites),
                const SizedBox(width: 8),
                _buildStatusChip('Expiring', DocumentViewFilter.expiring),
                const SizedBox(width: 8),
                _buildStatusChip('Archived', DocumentViewFilter.archived),
              ],
            ),
          ),

          // Expiry sub-filter pills (if Expiring is selected)
          if (_activeFilter == DocumentViewFilter.expiring)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  const Text('Window: ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  _buildExpirySubChip('30 Days', 30),
                  const SizedBox(width: 6),
                  _buildExpirySubChip('15 Days', 15),
                  const SizedBox(width: 6),
                  _buildExpirySubChip('7 Days', 7),
                  const SizedBox(width: 6),
                  _buildExpirySubChip('Expired', 0),
                ],
              ),
            ),

          // Category Filter Pills
          categoriesAsync.when(
            data: (cats) {
              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    FilterChip(
                      selected: filterState.categoryId == null,
                      label: const Text('All Categories', style: TextStyle(fontSize: 12)),
                      onSelected: (_) {
                        ref.read(documentFilterProvider.notifier).update(
                              (s) => s.copyWith(clearCategory: true),
                            );
                      },
                    ),
                    const SizedBox(width: 8),
                    for (var cat in cats) ...[
                      FilterChip(
                        selected: filterState.categoryId == cat.id,
                        label: Text(cat.name, style: const TextStyle(fontSize: 12)),
                        onSelected: (selected) {
                          ref.read(documentFilterProvider.notifier).update(
                                (s) => s.copyWith(
                                  categoryId: selected ? cat.id : null,
                                  clearCategory: !selected,
                                ),
                              );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              );
            },
            loading: () => const SizedBox(height: 40),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 8),

          // Document List Content
          Expanded(
            child: _activeFilter == DocumentViewFilter.recent
                ? recentAsync.when(
                    data: (docs) => _buildDocumentListView(docs),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  )
                : documentsAsync.when(
                    data: (docs) => _buildDocumentListView(docs),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => UploadDocumentSheet.showOptions(context),
        icon: const Icon(Icons.add_moderator, color: Colors.white, size: 20),
        label: const Text('Add Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatusChip(String label, DocumentViewFilter filter) {
    final isSelected = _activeFilter == filter;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onSelected: (_) => _selectFilter(filter),
    );
  }

  Widget _buildExpirySubChip(String label, int days) {
    final isSelected = _expiryFilterDays == days;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onSelected: (_) => _applyExpiryDaysFilter(days),
    );
  }

  Widget _buildDocumentListView(List<DocumentModel> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open, size: 44, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'No documents found',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Scan or upload your official documents to secure them in DHA Vault.',
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

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final doc = docs[index];
        return _buildDocumentTile(context, doc);
      },
    );
  }

  Widget _buildDocumentTile(BuildContext context, DocumentModel doc) {
    final isPdf = doc.fileType == 'PDF' || doc.mimeType.contains('pdf');

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
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
            if (doc.isOcrCompleted) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('AI ✓', style: TextStyle(color: AppTheme.accentGreen, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ] else if (doc.isOcrProcessing) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('◌ Reading', style: TextStyle(color: AppTheme.primaryLight, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${doc.formattedFileSize} • ${doc.category?.name ?? doc.documentType}',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (doc.isExpired)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('EXPIRED', style: TextStyle(color: AppTheme.accentRed, fontSize: 9, fontWeight: FontWeight.bold)),
              )
            else if (doc.isExpiringSoon)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('EXPIRING (${doc.daysUntilExpiry ?? 0}d)', style: const TextStyle(color: AppTheme.accentAmber, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            if (doc.isFavorite)
              const Icon(Icons.star, color: AppTheme.accentAmber, size: 18)
            else
              const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
