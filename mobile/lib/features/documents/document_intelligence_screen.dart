import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/document.dart';
import '../../providers/category_provider.dart';
import '../../providers/document_provider.dart';
import '../../theme/app_theme.dart';

class DocumentIntelligenceScreen extends ConsumerStatefulWidget {
  final DocumentModel document;

  const DocumentIntelligenceScreen({
    super.key,
    required this.document,
  });

  @override
  ConsumerState<DocumentIntelligenceScreen> createState() =>
      _DocumentIntelligenceScreenState();
}

class _DocumentIntelligenceScreenState
    extends ConsumerState<DocumentIntelligenceScreen> {
  late TextEditingController _titleController;
  late String _selectedType;
  String? _selectedCategoryId;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  final Map<String, TextEditingController> _fieldControllers = {};
  final List<String> _tags = [];
  bool _isSaving = false;
  bool _isRetrying = false;
  late DocumentModel _currentDoc;

  final List<String> _supportedTypes = [
    'AADHAAR',
    'PAN',
    'PASSPORT',
    'DRIVING_LICENCE',
    'VEHICLE',
    'INSURANCE',
    'EDUCATION_CERTIFICATE',
    'MARKSHEET',
    'EMPLOYMENT',
    'BANK',
    'MEDICAL',
    'PROPERTY',
    'RECEIPT',
    'CONTRACT',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _currentDoc = widget.document;
    _titleController = TextEditingController(text: _currentDoc.title);
    _selectedType = _currentDoc.documentType;
    _selectedCategoryId = _currentDoc.categoryId;
    _issueDate = _currentDoc.issueDate;
    _expiryDate = _currentDoc.expiryDate;
    _tags.addAll(_currentDoc.tags);

    _initFieldControllers();
  }

  void _initFieldControllers() {
    _fieldControllers.clear();
    final fields = _currentDoc.extractedFields ?? {};
    fields.forEach((key, value) {
      if (value != null && value is! Map && value is! List) {
        _fieldControllers[key] = TextEditingController(text: value.toString());
      }
    });

    if (!_fieldControllers.containsKey('name')) {
      final nameVal = fields['holderName'] ?? fields['ownerName'];
      if (nameVal != null) {
        _fieldControllers['name'] = TextEditingController(text: nameVal.toString());
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleRetryOcr() async {
    setState(() => _isRetrying = true);
    final updated = await ref
        .read(documentServiceProvider)
        .triggerOcr(_currentDoc.id);
    if (mounted) {
      if (updated != null) {
        setState(() {
          _currentDoc = updated;
          _selectedType = updated.documentType;
          _issueDate = updated.issueDate;
          _expiryDate = updated.expiryDate;
          _initFieldControllers();
          _isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OCR re-processed successfully!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      } else {
        setState(() => _isRetrying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OCR scan could not read additional text.'),
            backgroundColor: AppTheme.accentAmber,
          ),
        );
      }
    }
  }

  Future<void> _handleConfirm() async {
    setState(() => _isSaving = true);

    final fields = <String, dynamic>{};
    _fieldControllers.forEach((key, ctrl) {
      if (ctrl.text.trim().isNotEmpty) {
        fields[key] = ctrl.text.trim();
      }
    });

    final updated = await ref.read(documentServiceProvider).confirmIntelligence(
          _currentDoc.id,
          title: _titleController.text.trim(),
          documentType: _selectedType,
          extractedFields: fields,
          issueDate: _issueDate,
          expiryDate: _expiryDate,
          categoryId: _selectedCategoryId,
          tags: _tags,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      if (updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document intelligence confirmed & saved!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        context.pop(updated);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save document updates.'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(
          'Document Intelligence',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: _isRetrying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, color: AppTheme.primaryLight),
            tooltip: 'Retry Scan / OCR',
            onPressed: _isRetrying ? null : _handleRetryOcr,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Card
            _buildStatusHeaderCard(),
            const SizedBox(height: 20),

            // Document Detection & Confidence
            _buildDetectionHeader(),
            const SizedBox(height: 24),

            // Extracted Fields Section (Editable)
            Text(
              'DETECTED INFORMATION',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            _buildExtractedFieldsCard(),
            const SizedBox(height: 24),

            // Dates & Expiry
            Text(
              'VALIDITY & EXPIRY',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            _buildDatesCard(),
            const SizedBox(height: 24),

            // Category & Tags
            Text(
              'ORGANIZATION',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            _buildOrganizationCard(categoriesAsync),
            const SizedBox(height: 36),

            // Action Buttons
            _buildActionButtons(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeaderCard() {
    final status = _currentDoc.ocrStatus;
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    if (status == 'COMPLETED') {
      statusColor = AppTheme.accentGreen;
      statusIcon = Icons.check_circle_rounded;
      statusTitle = 'Document Read Successfully';
      statusSubtitle =
          'Extracted via ${_currentDoc.ocrProvider ?? 'local OCR'} with ${_currentDoc.ocrConfidencePercentage} confidence.';
    } else if (status == 'PROCESSING') {
      statusColor = AppTheme.primaryLight;
      statusIcon = Icons.sync_rounded;
      statusTitle = 'Reading Document...';
      statusSubtitle = 'AI is extracting structured text and dates.';
    } else if (status == 'FAILED') {
      statusColor = AppTheme.accentRed;
      statusIcon = Icons.error_outline_rounded;
      statusTitle = 'Partial Read / Retry Recommended';
      statusSubtitle = 'Document saved safely. Tap retry to re-scan.';
    } else {
      statusColor = AppTheme.accentAmber;
      statusIcon = Icons.hourglass_top_rounded;
      statusTitle = 'OCR Queued';
      statusSubtitle = 'Analyzing document in background.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Document Title',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              if (_currentDoc.ocrConfidence != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.accentGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${_currentDoc.ocrConfidencePercentage} Match',
                    style: const TextStyle(
                      color: AppTheme.accentGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppTheme.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Detected Document Type',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _supportedTypes.contains(_selectedType) ? _selectedType : 'OTHER',
            dropdownColor: AppTheme.surfaceElevated,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppTheme.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            items: _supportedTypes
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.replaceAll('_', ' ')),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedType = val);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedFieldsCard() {
    if (_fieldControllers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.text_snippet_outlined,
                  color: AppTheme.textMuted, size: 36),
              SizedBox(height: 8),
              Text(
                'No structured fields parsed yet.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'Tap "Retry Scan" to parse text lines again.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: _fieldControllers.entries.map((entry) {
          final label = _formatFieldLabel(entry.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: entry.value,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDatesCard() {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // Issue Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Issue Date',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _issueDate ?? DateTime.now(),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _issueDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _issueDate != null
                              ? dateFormat.format(_issueDate!)
                              : 'Not set',
                          style: TextStyle(
                            color: _issueDate != null
                                ? AppTheme.textPrimary
                                : AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const Icon(Icons.calendar_today_rounded,
                            size: 16, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Expiry Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expiry Date',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expiryDate ??
                          DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime(1980),
                      lastDate: DateTime(2060),
                    );
                    if (picked != null) {
                      setState(() => _expiryDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _expiryDate != null
                              ? dateFormat.format(_expiryDate!)
                              : 'No expiry',
                          style: TextStyle(
                            color: _expiryDate != null
                                ? AppTheme.accentGreen
                                : AppTheme.textMuted,
                            fontSize: 13,
                            fontWeight: _expiryDate != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const Icon(Icons.event_available_rounded,
                            size: 16, color: AppTheme.accentGreen),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationCard(AsyncValue categoriesAsync) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggested Category',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          categoriesAsync.when(
            data: (cats) => DropdownButtonFormField<String?>(
              initialValue: _selectedCategoryId,
              dropdownColor: AppTheme.surfaceElevated,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppTheme.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No Category'),
                ),
                ...cats.map((c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name),
                    )),
              ],
              onChanged: (val) {
                setState(() => _selectedCategoryId = val);
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 18),
          const Text(
            'Tags',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._tags.map((tag) => Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() => _tags.remove(tag));
                    },
                  )),
              ActionChip(
                avatar: const Icon(Icons.add, size: 14),
                label: const Text('Add Tag', style: TextStyle(fontSize: 12)),
                backgroundColor: AppTheme.surfaceElevated,
                onPressed: _showAddTagDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddTagDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Add Tag'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'e.g. #travel, #vehicle',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                final formatted = val.startsWith('#') ? val : '#$val';
                setState(() => _tags.add(formatted));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Confirm & Save Document',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isRetrying ? null : _handleRetryOcr,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry OCR Scan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: AppTheme.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatFieldLabel(String key) {
    switch (key) {
      case 'documentNumber':
        return 'Document Number';
      case 'licenseNumber':
        return 'Licence Number';
      case 'panNumber':
        return 'PAN Number';
      case 'passportNumber':
        return 'Passport Number';
      case 'policyNumber':
        return 'Policy Number';
      case 'registrationNumber':
        return 'Registration Number';
      case 'dateOfBirth':
        return 'Date of Birth';
      case 'vehicleClasses':
        return 'Authorized Vehicle Classes';
      case 'holderName':
        return 'Policy Holder Name';
      case 'name':
        return 'Full Name';
      default:
        return key.replaceAllMapped(
            RegExp(r'([A-Z])'), (m) => ' ${m[1]}').trim().toUpperCase();
    }
  }
}
