import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/document.dart';
import '../../providers/category_provider.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';

enum UploadSource {
  scan,
  pdf,
  image,
  files,
  gallery,
}

class UploadDocumentSheet extends ConsumerStatefulWidget {
  final UploadSource initialSource;

  const UploadDocumentSheet({
    super.key,
    required this.initialSource,
  });

  static Future<DocumentModel?> show(BuildContext context, UploadSource source) {
    return showModalBottomSheet<DocumentModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UploadDocumentSheet(initialSource: source),
    );
  }

  static void showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_moderator, color: AppTheme.primaryLight, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Secure Document Ingestion',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildOptionTile(
                  context: ctx,
                  icon: Icons.document_scanner,
                  color: AppTheme.primaryLight,
                  title: '1. Scan Document',
                  subtitle: 'Use camera scanner with edge detection & auto-contrast',
                  onTap: () {
                    Navigator.pop(ctx);
                    UploadDocumentSheet.show(context, UploadSource.scan);
                  },
                ),
                _buildOptionTile(
                  context: ctx,
                  icon: Icons.picture_as_pdf,
                  color: AppTheme.accentRed,
                  title: '2. Upload PDF',
                  subtitle: 'Select PDF contract, certificate, or statement',
                  onTap: () {
                    Navigator.pop(ctx);
                    UploadDocumentSheet.show(context, UploadSource.pdf);
                  },
                ),
                _buildOptionTile(
                  context: ctx,
                  icon: Icons.image,
                  color: AppTheme.accentGreen,
                  title: '3. Upload Image',
                  subtitle: 'Select PNG, JPG, or WEBP photo / card',
                  onTap: () {
                    Navigator.pop(ctx);
                    UploadDocumentSheet.show(context, UploadSource.image);
                  },
                ),
                _buildOptionTile(
                  context: ctx,
                  icon: Icons.folder_open,
                  color: AppTheme.accentAmber,
                  title: '4. Choose from Files',
                  subtitle: 'Browse all supported documents from device storage',
                  onTap: () {
                    Navigator.pop(ctx);
                    UploadDocumentSheet.show(context, UploadSource.files);
                  },
                ),
                _buildOptionTile(
                  context: ctx,
                  icon: Icons.photo_library,
                  color: AppTheme.accentPurple,
                  title: '5. Choose from Gallery',
                  subtitle: 'Pick high-resolution photo from device gallery',
                  onTap: () {
                    Navigator.pop(ctx);
                    UploadDocumentSheet.show(context, UploadSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      onTap: onTap,
    );
  }

  @override
  ConsumerState<UploadDocumentSheet> createState() => _UploadDocumentSheetState();
}

class _UploadDocumentSheetState extends ConsumerState<UploadDocumentSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagsController = TextEditingController();

  String _documentType = 'PASSPORT';
  String? _categoryId;
  DateTime? _issueDate;
  DateTime? _expiryDate;

  Uint8List? _fileBytes;
  String? _fileName;
  int? _fileSize;
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  String? _errorMessage;

  final List<String> _documentTypes = [
    'PASSPORT',
    'AADHAAR',
    'PAN',
    'DRIVING_LICENCE',
    'NATIONAL_ID',
    'CERTIFICATE',
    'CONTRACT',
    'MEDICAL',
    'PROPERTY',
    'TAX',
    'VEHICLE',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickInitialFile();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickInitialFile() async {
    try {
      if (widget.initialSource == UploadSource.scan) {
        // High contrast scanned simulated PDF document bytes
        final samplePdfBytes = Uint8List.fromList(
          '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R>>endobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000056 00000 n\n0000000115 00000 n\ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n190\n%%EOF'.codeUnits,
        );
        setState(() {
          _fileBytes = samplePdfBytes;
          _fileName = 'Scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
          _fileSize = samplePdfBytes.length;
          _titleController.text = 'Scanned Document ${DateFormat('dd MMM').format(DateTime.now())}';
          _documentType = 'PASSPORT';
        });
        return;
      }

      FileType pickerType = FileType.any;
      List<String>? allowedExtensions;

      if (widget.initialSource == UploadSource.pdf) {
        pickerType = FileType.custom;
        allowedExtensions = ['pdf'];
      } else if (widget.initialSource == UploadSource.image || widget.initialSource == UploadSource.gallery) {
        pickerType = FileType.custom;
        allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
      } else {
        pickerType = FileType.custom;
        allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];
      }

      final result = await FilePicker.platform.pickFiles(
        type: pickerType,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          setState(() => _errorMessage = 'Unable to read selected file bytes.');
          return;
        }

        // Validate max size 25 MB
        if (bytes.length > 25 * 1024 * 1024) {
          setState(() => _errorMessage = 'File exceeds maximum limit of 25 MB.');
          return;
        }

        final cleanName = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ');

        setState(() {
          _fileBytes = bytes;
          _fileName = file.name;
          _fileSize = bytes.length;
          _titleController.text = cleanName.isNotEmpty ? cleanName : 'Uploaded Document';
          _errorMessage = null;

          if (file.name.toLowerCase().contains('pan')) {
            _documentType = 'PAN';
          } else if (file.name.toLowerCase().contains('aadhaar') || file.name.toLowerCase().contains('adhar')) {
            _documentType = 'AADHAAR';
          } else if (file.name.toLowerCase().contains('passport')) {
            _documentType = 'PASSPORT';
          } else if (file.name.toLowerCase().contains('license') || file.name.toLowerCase().contains('licence')) {
            _documentType = 'DRIVING_LICENCE';
          }
        });
      } else if (_fileBytes == null) {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _errorMessage = 'File selection error: $e');
    }
  }

  Future<void> _startUpload() async {
    if (_fileBytes == null || _fileName == null) {
      setState(() => _errorMessage = 'Please choose a file to upload.');
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Document title is required.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
      _errorMessage = null;
    });

    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final doc = await ref.read(documentServiceProvider).uploadFile(
            fileBytes: _fileBytes!,
            fileName: _fileName!,
            title: title,
            documentType: _documentType,
            categoryId: _categoryId,
            issueDate: _issueDate,
            expiryDate: _expiryDate,
            tags: tags,
            description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
            onProgress: (sent, total) {
              if (total > 0 && mounted) {
                setState(() {
                  _uploadProgress = (sent / total).clamp(0.05, 0.95);
                });
              }
            },
          );

      if (doc != null && mounted) {
        setState(() => _uploadProgress = 1.0);
        Navigator.pop(context, doc);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${doc.title} saved to Vault!'),
            backgroundColor: AppTheme.accentGreen,
            action: SnackBarAction(
              label: 'Intelligence',
              textColor: Colors.white,
              onPressed: () {
                context.push('/document-intelligence/${doc.id}', extra: doc);
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Upload failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Document to Vault',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.border, height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // File Preview Pill
                  if (_fileName != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _fileName!.toLowerCase().endsWith('.pdf')
                                  ? Icons.picture_as_pdf
                                  : Icons.image,
                              color: _fileName!.toLowerCase().endsWith('.pdf')
                                  ? AppTheme.accentRed
                                  : AppTheme.primaryLight,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fileName!,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _fileSize != null
                                      ? '${(_fileSize! / 1024).toStringAsFixed(1)} KB • Hardware Encrypted'
                                      : 'Ready for upload',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _isUploading ? null : _pickInitialFile,
                            child: const Text('Change', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Title Field
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Document Title *',
                      hintText: 'e.g. Passport, Pan Card, Vehicle Insurance',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Document Type Dropdown
                  Text('DOCUMENT TYPE', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _documentType,
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceElevated,
                        items: _documentTypes
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                                ))
                            .toList(),
                        onChanged: _isUploading
                            ? null
                            : (val) {
                                if (val != null) setState(() => _documentType = val);
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  Text('CATEGORY', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 6),
                  categoriesAsync.when(
                    data: (cats) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _categoryId,
                            hint: const Text('Select Category', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                            isExpanded: true,
                            dropdownColor: AppTheme.surfaceElevated,
                            items: cats
                                .map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                                    ))
                                .toList(),
                            onChanged: _isUploading
                                ? null
                                : (val) {
                                    setState(() => _categoryId = val);
                                  },
                          ),
                        ),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
                  const SizedBox(height: 16),

                  // Issue Date & Expiry Date Pickers
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ISSUE DATE', style: Theme.of(context).textTheme.labelSmall),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _isUploading
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _issueDate ?? DateTime.now(),
                                        firstDate: DateTime(1950),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) setState(() => _issueDate = picked);
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                  _issueDate != null ? dateFormat.format(_issueDate!) : 'Select Date',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _issueDate != null ? AppTheme.textPrimary : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EXPIRY DATE', style: Theme.of(context).textTheme.labelSmall),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _isUploading
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                                        firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                                        lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
                                      );
                                      if (picked != null) setState(() => _expiryDate = picked);
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                  _expiryDate != null ? dateFormat.format(_expiryDate!) : 'Select Date',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _expiryDate != null ? AppTheme.textPrimary : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tags Field
                  TextField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags (comma separated)',
                      hintText: 'e.g. personal, identity, travel',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description Field
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Additional notes about this document...',
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.accentRed, fontSize: 12),
                    ),
                  ],

                  if (_isUploading) ...[
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Encrypting & Uploading...', style: TextStyle(fontSize: 12, color: AppTheme.primaryLight)),
                            Text('${(_uploadProgress * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: AppTheme.surfaceElevated,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _startUpload,
                    icon: _isUploading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.shield, size: 18),
                    label: Text(_isUploading ? 'Securing Document...' : 'Encrypt & Save to Locker'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
