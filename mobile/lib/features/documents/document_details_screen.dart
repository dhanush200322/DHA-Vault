import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_endpoints.dart';
import '../../models/document.dart';
import '../../models/document_version.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';
import '../sharing/secure_share_dialog.dart';

class DocumentDetailsScreen extends ConsumerStatefulWidget {
  final String documentId;
  final DocumentModel? initialDocument;

  const DocumentDetailsScreen({
    super.key,
    required this.documentId,
    this.initialDocument,
  });

  @override
  ConsumerState<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends ConsumerState<DocumentDetailsScreen> {
  DocumentModel? _doc;
  Uint8List? _previewBytes;
  bool _isLoadingPreview = false;
  List<DocumentVersionModel> _versions = [];

  @override
  void initState() {
    super.initState();
    // Fast View: Use initial document or check memory cache first!
    _doc = widget.initialDocument ?? FastViewCache.instance.getMetadata(widget.documentId);
    _previewBytes = FastViewCache.instance.getPreviewBytes(widget.documentId);

    _fetchDocumentDetails();
    if (_previewBytes == null) {
      _loadPreviewBytes();
    }
  }

  Future<void> _fetchDocumentDetails() async {
    final client = ref.read(apiClientProvider);
    try {
      final res = await client.dio.get(ApiEndpoints.document(widget.documentId));
      if (res.statusCode == 200 && mounted) {
        final doc = DocumentModel.fromJson(res.data);
        FastViewCache.instance.putMetadata(doc);
        setState(() {
          _doc = doc;
        });
      }
    } catch (_) {}

    try {
      final versions = await ref.read(documentServiceProvider).fetchVersions(widget.documentId);
      if (mounted) {
        setState(() {
          _versions = versions;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPreviewBytes() async {
    setState(() => _isLoadingPreview = true);
    try {
      final bytes = await ref.read(documentServiceProvider).fetchPreviewBytes(widget.documentId);
      if (bytes != null && mounted) {
        setState(() {
          _previewBytes = bytes;
          _isLoadingPreview = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_doc == null) return;
    final updated = await ref.read(documentServiceProvider).toggleFavorite(_doc!.id);
    if (updated != null && mounted) {
      setState(() => _doc = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updated.isFavorite ? 'Added to Quick Access Favorites' : 'Removed from Favorites'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _toggleArchive() async {
    if (_doc == null) return;
    final updated = await ref.read(documentServiceProvider).toggleArchive(_doc!.id);
    if (updated != null && mounted) {
      setState(() => _doc = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updated.isArchived ? 'Document moved to Archive' : 'Document restored from Archive'),
        ),
      );
    }
  }

  Future<void> _deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Document?'),
        content: const Text('This will permanently delete this document and purge its encrypted storage file.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await ref.read(documentServiceProvider).deleteDocument(widget.documentId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted')),
        );
        context.pop();
      }
    }
  }

  Future<void> _showEditDialog() async {
    if (_doc == null) return;
    final doc = _doc!;

    final titleController = TextEditingController(text: doc.title);
    final descController = TextEditingController(text: doc.description ?? '');
    final tagsController = TextEditingController(text: doc.tags.join(', '));
    String? categoryId = doc.categoryId;
    DateTime? issueDate = doc.issueDate;
    DateTime? expiryDate = doc.expiryDate;

    final categories = ref.read(categoriesProvider).value ?? [];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final dateFormat = DateFormat('dd MMM yyyy');
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Edit Document Metadata'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    dropdownColor: AppTheme.surfaceElevated,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (val) => setModalState(() => categoryId = val),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: issueDate ?? DateTime.now(),
                              firstDate: DateTime(1950),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setModalState(() => issueDate = picked);
                          },
                          child: Text(issueDate != null ? dateFormat.format(issueDate!) : 'Issue Date'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
                            );
                            if (picked != null) setModalState(() => expiryDate = picked);
                          },
                          child: Text(expiryDate != null ? dateFormat.format(expiryDate!) : 'Expiry Date'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final tags = tagsController.text
                      .split(',')
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty)
                      .toList();

                  final updated = await ref.read(documentServiceProvider).updateDocument(
                        doc.id,
                        title: titleController.text.trim(),
                        categoryId: categoryId,
                        issueDate: issueDate,
                        expiryDate: expiryDate,
                        tags: tags,
                        description: descController.text.trim(),
                      );
                  if (updated != null && mounted) {
                    setState(() => _doc = updated);
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_doc == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final doc = _doc!;
    final dateFormat = DateFormat('dd MMM yyyy');
    final isPdf = doc.fileType == 'PDF' || doc.mimeType.contains('pdf');

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text('Document Details'),
        actions: [
          IconButton(
            icon: Icon(
              doc.isFavorite ? Icons.star : Icons.star_border,
              color: doc.isFavorite ? AppTheme.accentAmber : AppTheme.textPrimary,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppTheme.primaryLight),
            onPressed: () => SecureShareDialog.show(context, doc),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed),
            onPressed: _deleteDocument,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fast View Preview Card
            Container(
              height: 220,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Stack(
                children: [
                  Center(
                    child: _previewBytes != null && !isPdf
                        ? Image.memory(
                            _previewBytes!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isPdf
                                      ? AppTheme.accentRed.withValues(alpha: 0.15)
                                      : AppTheme.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPdf ? Icons.picture_as_pdf : Icons.image,
                                  size: 48,
                                  color: isPdf ? AppTheme.accentRed : AppTheme.primaryLight,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                doc.title,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${doc.fileType} • ${doc.formattedFileSize}',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                  ),
                  if (_isLoadingPreview)
                    const Positioned(
                      top: 10,
                      right: 10,
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  // Expiry Status Banner
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _buildExpiryBadge(doc),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Instant View Button
            ElevatedButton.icon(
              onPressed: () => context.push('/document-viewer/${doc.id}', extra: doc),
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('Open & View Document (Fast View)'),
            ),
            const SizedBox(height: 16),

            // Quick Actions Bar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => SecureShareDialog.show(context, doc),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showEditDialog,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleArchive,
                    icon: Icon(doc.isArchived ? Icons.unarchive : Icons.archive, size: 16),
                    label: Text(doc.isArchived ? 'Restore' : 'Archive'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Document Intelligence & OCR Card
            InkWell(
              onTap: () async {
                final updated = await context.push<DocumentModel>(
                  '/document-intelligence/${doc.id}',
                  extra: doc,
                );
                if (updated != null && mounted) {
                  setState(() => _doc = updated);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: doc.isOcrCompleted
                      ? AppTheme.accentGreen.withValues(alpha: 0.08)
                      : (doc.isOcrProcessing
                          ? AppTheme.primary.withValues(alpha: 0.08)
                          : AppTheme.accentAmber.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: doc.isOcrCompleted
                        ? AppTheme.accentGreen.withValues(alpha: 0.3)
                        : (doc.isOcrProcessing
                            ? AppTheme.primary.withValues(alpha: 0.3)
                            : AppTheme.accentAmber.withValues(alpha: 0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: doc.isOcrCompleted
                            ? AppTheme.accentGreen.withValues(alpha: 0.15)
                            : AppTheme.surfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: doc.isOcrCompleted
                            ? AppTheme.accentGreen
                            : AppTheme.primaryLight,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Document Intelligence',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (doc.isOcrCompleted)
                                Text(
                                  '• ${doc.ocrConfidencePercentage}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.accentGreen,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            doc.isOcrCompleted
                                ? 'Tap to view or edit detected fields & tags'
                                : (doc.isOcrProcessing
                                    ? 'Analyzing document contents...'
                                    : 'Tap to review extracted details'),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 14, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Metadata Card
            Text('METADATA & SPECIFICATIONS', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _buildMetaTile('Document Type', doc.documentType),
                  const Divider(color: AppTheme.border, height: 1),
                  _buildMetaTile('Category', doc.category?.name ?? 'Unassigned'),
                  const Divider(color: AppTheme.border, height: 1),
                  _buildMetaTile('Status', doc.expiryStatus, color: _statusColor(doc.expiryStatus)),
                  const Divider(color: AppTheme.border, height: 1),
                  _buildMetaTile('File Size', doc.formattedFileSize),
                  const Divider(color: AppTheme.border, height: 1),
                  _buildMetaTile('MIME Type', doc.mimeType),
                  const Divider(color: AppTheme.border, height: 1),
                  _buildMetaTile('Added On', dateFormat.format(doc.createdAt)),
                  const Divider(color: AppTheme.border, height: 1),
                  _buildMetaTile('Last Updated', dateFormat.format(doc.updatedAt)),
                  if (doc.issueDate != null) ...[
                    const Divider(color: AppTheme.border, height: 1),
                    _buildMetaTile('Issue Date', dateFormat.format(doc.issueDate!)),
                  ],
                  if (doc.expiryDate != null) ...[
                    const Divider(color: AppTheme.border, height: 1),
                    _buildMetaTile(
                      'Expiry Date',
                      '${dateFormat.format(doc.expiryDate!)} ${doc.daysUntilExpiry != null ? "(${doc.daysUntilExpiry! >= 0 ? '${doc.daysUntilExpiry!} days left' : 'Expired'})" : ''}',
                    ),
                  ],
                ],
              ),
            ),

            if (_versions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('VERSION HISTORY (${_versions.length})', style: Theme.of(context).textTheme.labelSmall),
                  if (doc.checksum != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        'SHA: ${doc.checksum!.substring(0, 8)}...',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontFamily: 'monospace'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: _versions.map((ver) {
                    final isLatest = ver.versionNumber == _versions.first.versionNumber;
                    final isLast = ver == _versions.last;
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isLatest
                                  ? AppTheme.accentGreen.withValues(alpha: 0.15)
                                  : AppTheme.surfaceElevated,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'v${ver.versionNumber}',
                              style: TextStyle(
                                color: isLatest ? AppTheme.accentGreen : AppTheme.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                'Version ${ver.versionNumber}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              if (isLatest) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Current', style: TextStyle(color: AppTheme.accentGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${dateFormat.format(ver.createdAt)} • ${(ver.fileSize / 1024).toStringAsFixed(1)} KB${ver.changeNotes != null ? " • ${ver.changeNotes}" : ""}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.download, color: AppTheme.textMuted, size: 18),
                        ),
                        if (!isLast) const Divider(color: AppTheme.border, height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],

            if (doc.tags.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('TAGS', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: doc.tags.map((tag) {
                  return Chip(
                    backgroundColor: AppTheme.surfaceElevated,
                    side: const BorderSide(color: AppTheme.border),
                    label: Text('#$tag', style: const TextStyle(fontSize: 11, color: AppTheme.primaryLight)),
                  );
                }).toList(),
              ),
            ],

            if (doc.description != null && doc.description!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('DESCRIPTION', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  doc.description!,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryBadge(DocumentModel doc) {
    Color bg;
    Color text;
    String label;

    if (doc.isExpired) {
      bg = AppTheme.accentRed.withValues(alpha: 0.15);
      text = AppTheme.accentRed;
      label = 'EXPIRED';
    } else if (doc.isExpiringSoon) {
      bg = AppTheme.accentAmber.withValues(alpha: 0.15);
      text = AppTheme.accentAmber;
      label = 'EXPIRING SOON (${doc.daysUntilExpiry ?? 0}d)';
    } else {
      bg = AppTheme.accentGreen.withValues(alpha: 0.15);
      text = AppTheme.accentGreen;
      label = 'VALID';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: text.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
      ),
    );
  }

  Color _statusColor(String status) {
    if (status == 'EXPIRED') return AppTheme.accentRed;
    if (status == 'EXPIRING SOON') return AppTheme.accentAmber;
    return AppTheme.accentGreen;
  }

  Widget _buildMetaTile(String title, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: color ?? AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
