import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/category.dart';
import '../../models/document.dart';
import '../../providers/category_provider.dart';
import '../../providers/document_provider.dart';
import '../../services/native_share_service.dart';
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
  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = {};

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

  void _toggleSelectDocument(String docId) {
    setState(() {
      if (_selectedDocIds.contains(docId)) {
        _selectedDocIds.remove(docId);
        if (_selectedDocIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedDocIds.add(docId);
        _isSelectionMode = true;
      }
    });
  }

  void _shareSelected(List<DocumentModel> allDocs) {
    final selectedDocs = allDocs.where((d) => _selectedDocIds.contains(d.id)).toList();
    if (selectedDocs.isEmpty) return;
    NativeShareService.shareMultipleDocuments(context, ref, selectedDocs);
    setState(() {
      _isSelectionMode = false;
      _selectedDocIds.clear();
    });
  }

  void _shareFolder(String categoryName, List<DocumentModel> docs) {
    NativeShareService.shareFolder(context, ref, categoryName, docs);
  }

  void _showFolderSharePicker(List<DocumentModel> allDocs, List<CategoryModel> categories) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Select Folder to Share',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    'All documents in the selected folder will be shared via Android Share Sheet.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: categories.length,
                    itemBuilder: (ctx, i) {
                      final cat = categories[i];
                      final catDocs = allDocs.where((d) => d.categoryId == cat.id || d.category?.id == cat.id).toList();
                      return ListTile(
                        leading: const Icon(Icons.folder_shared, color: AppTheme.primaryLight),
                        title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${catDocs.length} document${catDocs.length == 1 ? "" : "s"}'),
                        trailing: const Icon(Icons.share, size: 20, color: AppTheme.primaryLight),
                        onTap: () {
                          Navigator.pop(ctx);
                          _shareFolder(cat.name, catDocs);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsListProvider);
    final recentAsync = ref.watch(recentlyViewedDocumentsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final filterState = ref.watch(documentFilterProvider);
    final currentDocs = _activeFilter == DocumentViewFilter.recent
        ? (recentAsync.value ?? [])
        : (documentsAsync.value ?? []);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: AppTheme.surfaceElevated,
              elevation: 2,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedDocIds.clear();
                }),
              ),
              title: Text('${_selectedDocIds.length} Selected'),
              actions: [
                IconButton(
                  icon: Icon(_selectedDocIds.length == currentDocs.length ? Icons.deselect : Icons.select_all),
                  tooltip: _selectedDocIds.length == currentDocs.length ? 'Deselect All' : 'Select All',
                  onPressed: () {
                    setState(() {
                      if (_selectedDocIds.length == currentDocs.length) {
                        _selectedDocIds.clear();
                        _isSelectionMode = false;
                      } else {
                        _selectedDocIds.addAll(currentDocs.map((d) => d.id));
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: AppTheme.primaryLight),
                  tooltip: 'Share',
                  onPressed: () => _shareSelected(currentDocs),
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('DHA Vault Locker'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist, size: 22, color: AppTheme.primaryLight),
                  tooltip: 'Select Multiple to Share',
                  onPressed: () => setState(() => _isSelectionMode = true),
                ),
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
                    ActionChip(
                      avatar: const Icon(Icons.folder_shared, size: 16, color: AppTheme.accentGreen),
                      label: Text(
                        filterState.categoryId != null ? 'Share Folder' : 'Share Folder...',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accentGreen),
                      ),
                      backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.12),
                      side: const BorderSide(color: AppTheme.accentGreen, width: 0.8),
                      onPressed: () {
                        final allDocs = documentsAsync.value ?? [];
                        if (filterState.categoryId != null) {
                          final selectedCat = cats.firstWhere((c) => c.id == filterState.categoryId, orElse: () => cats.first);
                          final catDocs = allDocs.where((d) => d.categoryId == selectedCat.id || d.category?.id == selectedCat.id).toList();
                          _shareFolder(selectedCat.name, catDocs);
                        } else {
                          _showFolderSharePicker(allDocs, cats);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
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
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
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
    final isSelected = _selectedDocIds.contains(doc.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? AppTheme.primaryLight.withValues(alpha: 0.1) : AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: isSelected ? AppTheme.primaryLight : AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelectDocument(doc.id);
            } else {
              context.push('/document-details/${doc.id}', extra: doc);
            }
          },
          onLongPress: () {
            _toggleSelectDocument(doc.id);
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: _isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  activeColor: AppTheme.primaryLight,
                  onChanged: (_) => _toggleSelectDocument(doc.id),
                )
              : Container(
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isSelected ? AppTheme.primaryLight : null,
                  ),
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
          trailing: _isSelectionMode
              ? null
              : Row(
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
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.star, color: AppTheme.accentAmber, size: 18),
                      ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20, color: AppTheme.primaryLight),
                      tooltip: 'Share',
                      onPressed: () => NativeShareService.shareDocument(context, ref, doc),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
