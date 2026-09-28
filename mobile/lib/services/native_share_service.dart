import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/document.dart';
import '../providers/document_provider.dart';
import '../theme/app_theme.dart';

/// Service providing native Android/iOS sharing via the OS Share Sheet.
/// All documents are decrypted in RAM and shared strictly via temporary,
/// read-only Content URIs using Android's FileProvider. Decrypted files
/// are sanitized and cleaned up immediately after sharing.
class NativeShareService {
  /// Sanitize a title for safe filesystem representation
  static String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  /// Resolve appropriate file extension and MIME type
  static (String ext, String mime) _resolveMimeAndExt(DocumentModel doc) {
    final mime = doc.mimeType.toLowerCase();
    final fileType = doc.fileType.toUpperCase();

    if (mime.contains('pdf') || fileType == 'PDF') {
      return ('pdf', 'application/pdf');
    } else if (mime.contains('png') || fileType == 'PNG') {
      return ('png', 'image/png');
    } else if (mime.contains('webp') || fileType == 'WEBP') {
      return ('webp', 'image/webp');
    } else if (mime.contains('jpeg') || mime.contains('jpg') || fileType == 'JPG' || fileType == 'JPEG') {
      return ('jpg', 'image/jpeg');
    }
    return ('bin', 'application/octet-stream');
  }

  /// Securely prepare a temporary share directory and clean up any stale share files (>3 minutes old)
  static Future<Directory> _getSecureShareDirectory() async {
    final cacheDir = await getTemporaryDirectory();
    final shareDir = Directory('${cacheDir.path}/dha_vault_shares');
    if (!await shareDir.exists()) {
      await shareDir.create(recursive: true);
    } else {
      // Clean up files older than 3 minutes to prevent storage accumulation
      try {
        final now = DateTime.now();
        final entities = shareDir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            final stat = entity.statSync();
            if (now.difference(stat.modified).inMinutes >= 3) {
              entity.deleteSync();
            }
          }
        }
      } catch (_) {}
    }
    return shareDir;
  }

  /// Clean up temporary share files
  static Future<void> cleanupShareFiles() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final shareDir = Directory('${cacheDir.path}/dha_vault_shares');
      if (await shareDir.exists()) {
        await shareDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Generate a unique file path if file already exists in share directory
  static File _resolveUniqueFile(Directory dir, String baseFilename) {
    File file = File('${dir.path}/$baseFilename');
    if (!file.existsSync()) return file;

    final dotIndex = baseFilename.lastIndexOf('.');
    final name = dotIndex != -1 ? baseFilename.substring(0, dotIndex) : baseFilename;
    final ext = dotIndex != -1 ? baseFilename.substring(dotIndex) : '';

    int counter = 1;
    while (file.existsSync()) {
      file = File('${dir.path}/${name}_$counter$ext');
      counter++;
    }
    return file;
  }

  /// Share a single document via Android native Share Sheet
  static Future<void> shareDocument(
    BuildContext context,
    WidgetRef ref,
    DocumentModel document,
  ) async {
    // Capture origin synchronously before async operations
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;

    try {
      // 1. Decrypt/fetch document bytes into memory
      final bytes = await ref.read(documentServiceProvider).fetchPreviewBytes(document.id);
      if (bytes == null || bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to prepare document for sharing'),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
        return;
      }

      // 2. Prepare safe temporary file
      final shareDir = await _getSecureShareDirectory();
      final (ext, mime) = _resolveMimeAndExt(document);
      final safeTitle = _sanitizeFilename(document.title);
      final baseFilename = safeTitle.endsWith('.$ext') ? safeTitle : '$safeTitle.$ext';
      final tempFile = _resolveUniqueFile(shareDir, baseFilename);
      await tempFile.writeAsBytes(bytes, flush: true);

      // 3. Open Android Native Share Sheet using content URI
      final filename = tempFile.uri.pathSegments.last;
      final xFile = XFile(
        tempFile.path,
        mimeType: mime,
        name: filename,
      );

      await Share.shareXFiles(
        [xFile],
        text: document.title,
        subject: document.title,
        sharePositionOrigin: shareOrigin,
      );

      // 4. Clean up temporary share directory asynchronously after sharing returns (60s grace period)
      Future.delayed(const Duration(seconds: 60), () => cleanupShareFiles());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening Share Sheet: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  /// Share multiple documents together via Android native Share Sheet
  static Future<void> shareMultipleDocuments(
    BuildContext context,
    WidgetRef ref,
    List<DocumentModel> documents,
  ) async {
    // Capture origin synchronously before async operations
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;

    if (documents.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one document to share')),
        );
      }
      return;
    }

    try {
      final shareDir = await _getSecureShareDirectory();
      final xFiles = <XFile>[];

      for (final doc in documents) {
        final bytes = await ref.read(documentServiceProvider).fetchPreviewBytes(doc.id);
        if (bytes != null && bytes.isNotEmpty) {
          final (ext, mime) = _resolveMimeAndExt(doc);
          final safeTitle = _sanitizeFilename(doc.title);
          final baseFilename = safeTitle.endsWith('.$ext') ? safeTitle : '$safeTitle.$ext';
          final tempFile = _resolveUniqueFile(shareDir, baseFilename);
          await tempFile.writeAsBytes(bytes, flush: true);

          final filename = tempFile.uri.pathSegments.last;
          xFiles.add(XFile(
            tempFile.path,
            mimeType: mime,
            name: filename,
          ));
        }
      }

      if (xFiles.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not prepare selected documents for sharing'),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
        return;
      }

      await Share.shareXFiles(
        xFiles,
        text: 'Sharing ${xFiles.length} documents from DHA Vault',
        sharePositionOrigin: shareOrigin,
      );

      // Clean up temporary share directory asynchronously
      Future.delayed(const Duration(seconds: 60), () => cleanupShareFiles());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing documents: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  /// Share all documents within a folder / category via Android native Share Sheet
  static Future<void> shareFolder(
    BuildContext context,
    WidgetRef ref,
    String categoryName,
    List<DocumentModel> documentsInFolder,
  ) async {
    // Capture origin synchronously before async operations
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;

    if (documentsInFolder.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No documents in "$categoryName" to share'),
            backgroundColor: AppTheme.accentAmber,
          ),
        );
      }
      return;
    }

    try {
      final shareDir = await _getSecureShareDirectory();
      final xFiles = <XFile>[];

      for (final doc in documentsInFolder) {
        final bytes = await ref.read(documentServiceProvider).fetchPreviewBytes(doc.id);
        if (bytes != null && bytes.isNotEmpty) {
          final (ext, mime) = _resolveMimeAndExt(doc);
          final safeTitle = _sanitizeFilename(doc.title);
          final baseFilename = safeTitle.endsWith('.$ext') ? safeTitle : '$safeTitle.$ext';
          final tempFile = _resolveUniqueFile(shareDir, baseFilename);
          await tempFile.writeAsBytes(bytes, flush: true);

          final filename = tempFile.uri.pathSegments.last;
          xFiles.add(XFile(
            tempFile.path,
            mimeType: mime,
            name: filename,
          ));
        }
      }

      if (xFiles.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to load documents from "$categoryName"'),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
        return;
      }

      await Share.shareXFiles(
        xFiles,
        text: 'Folder "$categoryName": ${xFiles.length} file(s) from DHA Vault',
        sharePositionOrigin: shareOrigin,
      );

      // Clean up temporary share files
      Future.delayed(const Duration(seconds: 60), () => cleanupShareFiles());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing folder: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }
}
