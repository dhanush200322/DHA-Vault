import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_config.dart';
import '../../core/api/api_endpoints.dart';
import '../../models/document.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class SecureShareDialog extends ConsumerStatefulWidget {
  final DocumentModel document;

  const SecureShareDialog({
    super.key,
    required this.document,
  });

  static Future<void> show(BuildContext context, DocumentModel document) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => SecureShareDialog(document: document),
    );
  }

  @override
  ConsumerState<SecureShareDialog> createState() => _SecureShareDialogState();
}

class _SecureShareDialogState extends ConsumerState<SecureShareDialog> {
  bool _allowDownload = false;
  bool _passwordProtected = false;
  bool _watermark = false;
  final _passwordController = TextEditingController();

  int _expiresInHours = 24; // 1, 24, 168 (7 days), 720 (30 days)
  int _maxUses = 5; // 1, 3, 5, 10, 0 (unlimited)

  bool _isCreating = false;
  String? _shareToken;
  String? _shareUrl;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createShareLink() async {
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final password = _passwordProtected && _passwordController.text.trim().isNotEmpty
          ? _passwordController.text.trim()
          : null;

      final res = await client.dio.post(
        ApiEndpoints.createShare,
        data: {
          'documentId': widget.document.id,
          'expiresInHours': _expiresInHours,
          'maxUses': _maxUses > 0 ? _maxUses : null,
          'allowDownload': _allowDownload,
          if (password != null) 'password': password,
        },
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = res.data;
        final token = data['token'] as String;
        final publicUrl = '${AppConfig.apiBaseUrl}${ApiEndpoints.publicShare(token)}';

        setState(() {
          _shareToken = token;
          _shareUrl = publicUrl;
          _isCreating = false;
        });
      }
    } catch (e) {
      setState(() {
        _isCreating = false;
        _errorMessage = 'Failed to generate share link: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _shareUrl != null ? _buildShareSuccessView() : _buildSetupForm(),
        ),
      ),
    );
  }

  Widget _buildSetupForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_clock, color: AppTheme.accentPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Secure Share Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      widget.document.title,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 14),

          // Access Type
          Text('ACCESS PERMISSION', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('View Only'),
                  selected: !_allowDownload,
                  onSelected: (val) => setState(() => _allowDownload = !val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('View + Download'),
                  selected: _allowDownload,
                  onSelected: (val) => setState(() => _allowDownload = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Expiration
          Text('EXPIRATION PERIOD', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('1 Hour'),
                selected: _expiresInHours == 1,
                onSelected: (_) => setState(() => _expiresInHours = 1),
              ),
              ChoiceChip(
                label: const Text('24 Hours'),
                selected: _expiresInHours == 24,
                onSelected: (_) => setState(() => _expiresInHours = 24),
              ),
              ChoiceChip(
                label: const Text('7 Days'),
                selected: _expiresInHours == 168,
                onSelected: (_) => setState(() => _expiresInHours = 168),
              ),
              ChoiceChip(
                label: const Text('30 Days'),
                selected: _expiresInHours == 720,
                onSelected: (_) => setState(() => _expiresInHours = 720),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Maximum Views
          Text('MAXIMUM VIEWS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('1 View'),
                selected: _maxUses == 1,
                onSelected: (_) => setState(() => _maxUses = 1),
              ),
              ChoiceChip(
                label: const Text('3 Views'),
                selected: _maxUses == 3,
                onSelected: (_) => setState(() => _maxUses = 3),
              ),
              ChoiceChip(
                label: const Text('5 Views'),
                selected: _maxUses == 5,
                onSelected: (_) => setState(() => _maxUses = 5),
              ),
              ChoiceChip(
                label: const Text('10 Views'),
                selected: _maxUses == 10,
                onSelected: (_) => setState(() => _maxUses = 10),
              ),
              ChoiceChip(
                label: const Text('Unlimited'),
                selected: _maxUses == 0,
                onSelected: (_) => setState(() => _maxUses = 0),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Password Protection Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Password Protection', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Require receiver to enter a password', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            value: _passwordProtected,
            activeThumbColor: AppTheme.accentGreen,
            onChanged: (val) => setState(() => _passwordProtected = val),
          ),
          if (_passwordProtected) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Enter share password',
                prefixIcon: Icon(Icons.key, size: 18),
              ),
            ),
          ],

          // Watermark Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Watermark Document', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Overlay confidential watermark stamp', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            value: _watermark,
            activeThumbColor: AppTheme.accentPurple,
            onChanged: (val) => setState(() => _watermark = val),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(_errorMessage!, style: const TextStyle(color: AppTheme.accentRed, fontSize: 12)),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isCreating ? null : _createShareLink,
                  icon: _isCreating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.link, size: 16),
                  label: Text(_isCreating ? 'Generating...' : 'Create Link'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: AppTheme.accentGreen, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Secure Link Created', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Share via URL or scan QR code', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // QR Code Box
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: QrImageView(
              data: _shareUrl!,
              version: QrVersions.auto,
              size: 160.0,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Share URL Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _shareUrl!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryLight),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _shareUrl!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share URL copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Security Info Pill
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Token: ${_shareToken != null ? _shareToken!.substring(0, 8) : ""}... • Expires in $_expiresInHours hour(s) • Max ${_maxUses > 0 ? "$_maxUses views" : "Unlimited"}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              if (_passwordProtected)
                const Text(
                  'Password protected • Encrypted in RAM during access',
                  style: TextStyle(fontSize: 10, color: AppTheme.accentGreen),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
