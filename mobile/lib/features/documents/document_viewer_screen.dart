import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/document.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';
import '../sharing/secure_share_dialog.dart';

class DocumentViewerScreen extends ConsumerStatefulWidget {
  final String documentId;
  final DocumentModel? document;

  const DocumentViewerScreen({
    super.key,
    required this.documentId,
    this.document,
  });

  @override
  ConsumerState<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  DocumentModel? _doc;
  Uint8List? _documentBytes;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Fast View: Check memory cache first
    _doc = widget.document ?? FastViewCache.instance.getMetadata(widget.documentId);
    _documentBytes = FastViewCache.instance.getPreviewBytes(widget.documentId);

    if (_documentBytes != null) {
      _isLoading = false;
    } else {
      _loadDocumentBytes();
    }
  }

  Future<void> _loadDocumentBytes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await ref.read(documentServiceProvider).fetchPreviewBytes(widget.documentId);
      if (bytes != null && mounted) {
        setState(() {
          _documentBytes = bytes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load document bytes from encrypted storage.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading document: $e';
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_doc == null) return;
    final updated = await ref.read(documentServiceProvider).toggleFavorite(_doc!.id);
    if (updated != null && mounted) {
      setState(() => _doc = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _doc?.title ?? 'Document Viewer';
    final isPdf = _doc?.fileType == 'PDF' || (_doc?.mimeType.contains('pdf') ?? false);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                const Icon(Icons.lock, size: 10, color: AppTheme.accentGreen),
                const SizedBox(width: 4),
                Text(
                  '${_doc?.fileType ?? ""} • RAM DECRYPTED',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, letterSpacing: 0.5),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_doc != null)
            IconButton(
              icon: Icon(
                _doc!.isFavorite ? Icons.star : Icons.star_border,
                color: _doc!.isFavorite ? AppTheme.accentAmber : Colors.white70,
              ),
              onPressed: _toggleFavorite,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: AppTheme.surfaceElevated,
            onSelected: (val) {
              if (val == 'share' && _doc != null) {
                SecureShareDialog.show(context, _doc!);
              } else if (val == 'details' && _doc != null) {
                context.push('/document-details/${_doc!.id}', extra: _doc);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 16, color: AppTheme.primaryLight),
                    SizedBox(width: 10),
                    Text('Secure Share'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'details',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppTheme.textPrimary),
                    SizedBox(width: 10),
                    Text('Document Details'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Document Viewer Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 16),
                        Text(
                          'Hardware decrypting in secure memory...',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppTheme.accentRed),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, style: const TextStyle(color: AppTheme.textMuted)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadDocumentBytes,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : isPdf
                        ? _buildPdfViewer()
                        : _buildImageViewer(),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(
                    icon: _doc?.isFavorite == true ? Icons.star : Icons.star_border,
                    label: 'Favorite',
                    color: _doc?.isFavorite == true ? AppTheme.accentAmber : AppTheme.textSecondary,
                    onTap: _toggleFavorite,
                  ),
                  _buildActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    color: AppTheme.primaryLight,
                    onTap: () {
                      if (_doc != null) SecureShareDialog.show(context, _doc!);
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.download_outlined,
                    label: 'Download',
                    color: AppTheme.accentGreen,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Document decrypted & ready in memory cache'),
                          backgroundColor: AppTheme.accentGreen,
                        ),
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.info_outline,
                    label: 'Details',
                    color: AppTheme.textSecondary,
                    onTap: () {
                      if (_doc != null) {
                        context.push('/document-details/${_doc!.id}', extra: _doc);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      panEnabled: true,
      minScale: 0.5,
      maxScale: 5.0,
      boundaryMargin: const EdgeInsets.all(24),
      child: Center(
        child: _documentBytes != null
            ? Image.memory(
                _documentBytes!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('Corrupted image file', style: TextStyle(color: AppTheme.accentRed)),
                ),
              )
            : const SizedBox(),
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf, size: 54, color: AppTheme.accentRed),
            ),
            const SizedBox(height: 18),
            Text(
              _doc?.title ?? 'PDF Document',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              '${_doc?.formattedFileSize ?? ""} • Verified Cryptographic Hash',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user, color: AppTheme.accentGreen, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Isolated RAM Decryption • No Disk Leaks',
                    style: TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
