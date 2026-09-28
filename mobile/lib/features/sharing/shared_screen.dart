import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/category.dart';
import '../../models/document.dart';
import '../../providers/category_provider.dart';
import '../../providers/document_provider.dart';
import '../../services/native_share_service.dart';
import '../../theme/app_theme.dart';

class SharedScreen extends ConsumerStatefulWidget {
  const SharedScreen({super.key});

  @override
  ConsumerState<SharedScreen> createState() => _SharedScreenState();
}

class _SharedScreenState extends ConsumerState<SharedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedDocIds = {};

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

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedDocIds.contains(id)) {
        _selectedDocIds.remove(id);
      } else {
        _selectedDocIds.add(id);
      }
    });
  }

  void _selectAll(List<DocumentModel> docs) {
    setState(() {
      if (_selectedDocIds.length == docs.length) {
        _selectedDocIds.clear();
      } else {
        _selectedDocIds.addAll(docs.map((d) => d.id));
      }
    });
  }

  void _shareSelected(List<DocumentModel> allDocs) {
    final toShare = allDocs.where((d) => _selectedDocIds.contains(d.id)).toList();
    if (toShare.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one document to share')),
      );
      return;
    }
    NativeShareService.shareMultipleDocuments(context, ref, toShare);
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsListProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Share Documents'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryLight,
          tabs: const [
            Tab(
              text: 'Documents',
              icon: Icon(Icons.description_outlined, size: 18),
            ),
            Tab(
              text: 'Folders',
              icon: Icon(Icons.folder_outlined, size: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              ref.invalidate(documentsListProvider);
              ref.invalidate(categoriesProvider);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Single & Multi-document native sharing
          documentsAsync.when(
            data: (docs) => _buildDocumentsTab(docs),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),

          // Tab 2: Folder native sharing
          categoriesAsync.when(
            data: (cats) {
              final docs = documentsAsync.value ?? [];
              return _buildFoldersTab(cats, docs);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
      bottomNavigationBar: _selectedDocIds.isNotEmpty && _tabController.index == 0
          ? documentsAsync.when(
              data: (docs) => SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    border: Border(top: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedDocIds.length} selected',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _selectedDocIds.clear()),
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.share, size: 18),
                        label: Text('Share (${_selectedDocIds.length})'),
                        onPressed: () => _shareSelected(docs),
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            )
          : null,
    );
  }

  Widget _buildDocumentsTab(List<DocumentModel> docs) {
    if (docs.isEmpty) {
      return Center(
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
                child: const Icon(Icons.share_outlined, size: 48, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Documents in Vault',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload or scan documents to your vault first to share them securely.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Security info banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security, size: 18, color: AppTheme.primaryLight),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Share documents securely via Android Share Sheet. Vault credentials, keys, and internal storage paths are never exposed.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                ),
              ),
            ],
          ),
        ),

        // Quick multi-select header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${docs.length} Vault Documents',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
              ),
              const Spacer(),
              TextButton.icon(
                icon: Icon(_selectedDocIds.length == docs.length ? Icons.deselect : Icons.select_all, size: 16),
                label: Text(_selectedDocIds.length == docs.length ? 'Deselect All' : 'Select All'),
                onPressed: () => _selectAll(docs),
              ),
            ],
          ),
        ),

        // Document list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final isPdf = doc.fileType == 'PDF' || doc.mimeType.contains('pdf');
              final isSelected = _selectedDocIds.contains(doc.id);

              return Material(
                color: isSelected ? AppTheme.primaryLight.withValues(alpha: 0.1) : AppTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isSelected ? AppTheme.primaryLight : AppTheme.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _toggleSelect(doc.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          activeColor: AppTheme.primaryLight,
                          onChanged: (_) => _toggleSelect(doc.id),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isPdf
                                ? AppTheme.accentRed.withValues(alpha: 0.15)
                                : AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.image,
                            color: isPdf ? AppTheme.accentRed : AppTheme.primaryLight,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${doc.formattedFileSize} • ${doc.category?.name ?? doc.documentType}',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: AppTheme.surfaceElevated,
                            foregroundColor: AppTheme.primaryLight,
                            elevation: 0,
                            side: const BorderSide(color: AppTheme.border),
                          ),
                          icon: const Icon(Icons.share, size: 15),
                          label: const Text('Share', style: TextStyle(fontSize: 12)),
                          onPressed: () => NativeShareService.shareDocument(context, ref, doc),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFoldersTab(List<CategoryModel> categories, List<DocumentModel> allDocs) {
    if (categories.isEmpty) {
      return const Center(child: Text('No folders available', style: TextStyle(color: AppTheme.textMuted)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final catDocs = allDocs.where((d) => d.categoryId == cat.id || d.category?.id == cat.id).toList();

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_shared, color: AppTheme.accentGreen, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${catDocs.length} document${catDocs.length == 1 ? "" : "s"} inside',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: catDocs.isEmpty ? AppTheme.surfaceElevated : AppTheme.primary,
                  foregroundColor: catDocs.isEmpty ? AppTheme.textMuted : Colors.white,
                ),
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share Folder'),
                onPressed: catDocs.isEmpty
                    ? null
                    : () => NativeShareService.shareFolder(context, ref, cat.name, catDocs),
              ),
            ],
          ),
        );
      },
    );
  }
}
