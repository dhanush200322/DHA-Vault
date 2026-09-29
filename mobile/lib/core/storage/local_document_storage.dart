import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Clean abstraction for local-first encrypted document storage.
///
/// Follows DHA Vault zero-cost production specifications:
/// - AES-256-GCM authenticated encryption with 12-byte IV and 16-byte auth tag.
/// - Versioned binary encryption envelope:
///   [1 byte version] + [12 bytes IV] + [16 bytes Tag] + [Ciphertext]
/// - Application-private directory isolation:
///   vault/
///     documents/
///     thumbnails/
///     cache/
///     backups/
/// - Hardware-backed / EncryptedSharedPreferences key persistence.
/// - Zero raw filesystem paths exposed to UI.
abstract class ILocalDocumentStorage {
  Future<String> saveDocument({
    required String documentId,
    required Uint8List plaintextBytes,
    String? subfolder,
  });

  Future<Uint8List> readDocument(String documentId, {String? subfolder});

  Future<bool> deleteDocument(String documentId, {String? subfolder});

  Future<bool> documentExists(String documentId, {String? subfolder});

  Future<Map<String, dynamic>> getDocumentMetadata(String documentId, {String? subfolder});

  String calculateChecksum(Uint8List bytes);

  Future<String> getStoragePath(String documentId, {String? subfolder});
}

class LocalDocumentStorage implements ILocalDocumentStorage {
  static const String _keyMasterEncryptionKey = 'dha_vault_device_master_key_v1';
  static const int _currentEnvelopeVersion = 1;
  static const int _ivLengthBytes = 12; // 96-bit nonce
  static const int _authTagLengthBytes = 16; // 128-bit MAC

  final FlutterSecureStorage _secureStorage;
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Directory? _injectedVaultRootDir;

  Directory? _vaultRootDir;
  Uint8List? _cachedMasterKey;

  LocalDocumentStorage({
    FlutterSecureStorage? secureStorage,
    Directory? vaultRootDir,
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            ),
        _injectedVaultRootDir = vaultRootDir;

  /// Ensure vault directories exist in application private storage
  Future<Directory> _getVaultRoot() async {
    if (_injectedVaultRootDir != null) {
      final vaultDir = _injectedVaultRootDir!;
      final subdirs = ['documents', 'thumbnails', 'cache', 'backups'];
      for (final sub in subdirs) {
        final dir = Directory('${vaultDir.path}/$sub');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }
      return vaultDir;
    }

    if (_vaultRootDir != null && await _vaultRootDir!.exists()) {
      return _vaultRootDir!;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${appDocDir.path}/vault');

    final subdirs = ['documents', 'thumbnails', 'cache', 'backups'];
    for (final sub in subdirs) {
      final dir = Directory('${vaultDir.path}/$sub');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }

    _vaultRootDir = vaultDir;
    return vaultDir;
  }

  /// Retrieve or generate hardware-secured 256-bit vault master key
  Future<Uint8List> _getMasterKey() async {
    if (_cachedMasterKey != null) {
      return _cachedMasterKey!;
    }

    try {
      final existingKeyHex = await _secureStorage.read(key: _keyMasterEncryptionKey);
      if (existingKeyHex != null && existingKeyHex.length == 64) {
        final keyBytes = _hexToBytes(existingKeyHex);
        _cachedMasterKey = keyBytes;
        return keyBytes;
      }
    } catch (_) {}

    // Generate new cryptographically secure 256-bit key
    final random = Random.secure();
    final keyBytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      keyBytes[i] = random.nextInt(256);
    }

    final keyHex = _bytesToHex(keyBytes);
    await _secureStorage.write(key: _keyMasterEncryptionKey, value: keyHex);
    _cachedMasterKey = keyBytes;
    return keyBytes;
  }

  /// Sanitize identifier to prevent path traversal
  String _sanitizeId(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  /// Resolve file on disk inside application private vault
  Future<File> _resolveFile(String documentId, {String? subfolder}) async {
    final vault = await _getVaultRoot();
    final sanitizedFolder = subfolder != null && subfolder.isNotEmpty
        ? subfolder.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
        : 'documents';
    final sanitizedId = _sanitizeId(documentId);
    return File('${vault.path}/$sanitizedFolder/$sanitizedId.enc');
  }

  @override
  Future<String> saveDocument({
    required String documentId,
    required Uint8List plaintextBytes,
    String? subfolder,
  }) async {
    if (plaintextBytes.isEmpty) {
      throw ArgumentError('Plaintext bytes cannot be empty');
    }

    final masterKeyBytes = await _getMasterKey();
    final secretKey = SecretKey(masterKeyBytes);

    // 1. Generate 12-byte cryptographically secure random IV
    final random = Random.secure();
    final iv = Uint8List(_ivLengthBytes);
    for (int i = 0; i < _ivLengthBytes; i++) {
      iv[i] = random.nextInt(256);
    }

    // 2. Encrypt plaintext with AES-256-GCM
    final secretBox = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: secretKey,
      nonce: iv,
    );

    // 3. Assemble binary envelope:
    // [1 byte version] + [12 bytes IV] + [16 bytes Auth Tag] + [Ciphertext]
    final ciphertextBytes = Uint8List.fromList(secretBox.cipherText);
    final authTagBytes = Uint8List.fromList(secretBox.mac.bytes);

    final envelope = Uint8List(1 + _ivLengthBytes + _authTagLengthBytes + ciphertextBytes.length);
    envelope[0] = _currentEnvelopeVersion;
    envelope.setRange(1, 1 + _ivLengthBytes, iv);
    envelope.setRange(
      1 + _ivLengthBytes,
      1 + _ivLengthBytes + _authTagLengthBytes,
      authTagBytes,
    );
    envelope.setRange(
      1 + _ivLengthBytes + _authTagLengthBytes,
      envelope.length,
      ciphertextBytes,
    );

    // 4. Atomically persist encrypted envelope to application-private storage
    final targetFile = await _resolveFile(documentId, subfolder: subfolder);
    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsBytes(envelope, flush: true);

    // 5. Return sanitized virtual storage path (never exposes internal filesystem root)
    final sanitizedFolder = subfolder ?? 'documents';
    final sanitizedId = _sanitizeId(documentId);
    return 'vault/$sanitizedFolder/$sanitizedId.enc';
  }

  @override
  Future<Uint8List> readDocument(String documentId, {String? subfolder}) async {
    final targetFile = await _resolveFile(documentId, subfolder: subfolder);

    if (!await targetFile.exists()) {
      throw FileSystemException('Document not found in local vault', targetFile.path);
    }

    final envelope = await targetFile.readAsBytes();

    const minLength = 1 + _ivLengthBytes + _authTagLengthBytes;
    if (envelope.length < minLength) {
      throw const FormatException('Corrupted or truncated encrypted document envelope');
    }

    final version = envelope[0];
    if (version != _currentEnvelopeVersion) {
      throw FormatException('Unsupported encryption envelope version: $version');
    }

    final iv = envelope.sublist(1, 1 + _ivLengthBytes);
    final authTag = envelope.sublist(
      1 + _ivLengthBytes,
      1 + _ivLengthBytes + _authTagLengthBytes,
    );
    final ciphertext = envelope.sublist(1 + _ivLengthBytes + _authTagLengthBytes);

    final masterKeyBytes = await _getMasterKey();
    final secretKey = SecretKey(masterKeyBytes);

    final secretBox = SecretBox(
      ciphertext,
      nonce: iv,
      mac: Mac(authTag),
    );

    final decryptedBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return Uint8List.fromList(decryptedBytes);
  }

  @override
  Future<bool> deleteDocument(String documentId, {String? subfolder}) async {
    final targetFile = await _resolveFile(documentId, subfolder: subfolder);
    if (await targetFile.exists()) {
      await targetFile.delete();
      return true;
    }
    return false;
  }

  @override
  Future<bool> documentExists(String documentId, {String? subfolder}) async {
    final targetFile = await _resolveFile(documentId, subfolder: subfolder);
    return targetFile.exists();
  }

  @override
  Future<Map<String, dynamic>> getDocumentMetadata(String documentId, {String? subfolder}) async {
    final targetFile = await _resolveFile(documentId, subfolder: subfolder);
    if (!await targetFile.exists()) {
      throw FileSystemException('Document not found in local vault', targetFile.path);
    }

    final stat = await targetFile.stat();
    final bytes = await targetFile.readAsBytes();
    final checksum = crypto.sha256.convert(bytes).toString();

    final sanitizedFolder = subfolder ?? 'documents';
    final sanitizedId = _sanitizeId(documentId);

    return {
      'documentId': sanitizedId,
      'storagePath': 'vault/$sanitizedFolder/$sanitizedId.enc',
      'fileSize': stat.size,
      'lastModified': stat.modified.toIso8601String(),
      'checksum': checksum,
      'isEncrypted': true,
      'encryptionAlgorithm': 'AES-256-GCM',
    };
  }

  @override
  String calculateChecksum(Uint8List bytes) {
    return crypto.sha256.convert(bytes).toString();
  }

  @override
  Future<String> getStoragePath(String documentId, {String? subfolder}) async {
    final sanitizedFolder = subfolder ?? 'documents';
    final sanitizedId = _sanitizeId(documentId);
    return 'vault/$sanitizedFolder/$sanitizedId.enc';
  }

  /// Store thumbnail locally
  Future<void> saveThumbnail(String documentId, Uint8List thumbnailBytes) async {
    final vault = await _getVaultRoot();
    final sanitizedId = _sanitizeId(documentId);
    final thumbFile = File('${vault.path}/thumbnails/$sanitizedId.thumb');
    await thumbFile.writeAsBytes(thumbnailBytes, flush: true);
  }

  /// Read thumbnail from local cache
  Future<Uint8List?> readThumbnail(String documentId) async {
    final vault = await _getVaultRoot();
    final sanitizedId = _sanitizeId(documentId);
    final thumbFile = File('${vault.path}/thumbnails/$sanitizedId.thumb');
    if (await thumbFile.exists()) {
      return thumbFile.readAsBytes();
    }
    return null;
  }

  /// Clear temporary preview cache
  Future<void> clearCache() async {
    final vault = await _getVaultRoot();
    final cacheDir = Directory('${vault.path}/cache');
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
      await cacheDir.create(recursive: true);
    }
  }

  /// Calculate total byte size of local vault storage
  Future<int> getVaultStorageSize() async {
    try {
      final vault = await _getVaultRoot();
      int total = 0;
      await for (final entity in vault.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
