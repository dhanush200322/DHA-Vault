import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_endpoints.dart';
import '../core/storage/local_document_storage.dart';
import '../models/document.dart';
import '../models/document_version.dart';
import 'auth_provider.dart';

class VaultStats {
  final int totalDocuments;
  final int validDocuments;
  final int favoriteDocuments;
  final int archivedDocuments;
  final int expiringSoonDocuments;
  final int expiredDocuments;
  final int noExpiryDocuments;
  final int ocrProcessingCount;
  final int ocrCompletedCount;
  final int totalStorageBytes;
  final List<Map<String, dynamic>> attentionRequired;

  VaultStats({
    required this.totalDocuments,
    this.validDocuments = 0,
    required this.favoriteDocuments,
    required this.archivedDocuments,
    required this.expiringSoonDocuments,
    this.expiredDocuments = 0,
    this.noExpiryDocuments = 0,
    this.ocrProcessingCount = 0,
    this.ocrCompletedCount = 0,
    required this.totalStorageBytes,
    this.attentionRequired = const [],
  });

  String get formattedStorage {
    if (totalStorageBytes < 1024) return '$totalStorageBytes B';
    if (totalStorageBytes < 1024 * 1024) return '${(totalStorageBytes / 1024).toStringAsFixed(1)} KB';
    return '${(totalStorageBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory VaultStats.empty() {
    return VaultStats(
      totalDocuments: 0,
      validDocuments: 0,
      favoriteDocuments: 0,
      archivedDocuments: 0,
      expiringSoonDocuments: 0,
      expiredDocuments: 0,
      noExpiryDocuments: 0,
      ocrProcessingCount: 0,
      ocrCompletedCount: 0,
      totalStorageBytes: 0,
      attentionRequired: [],
    );
  }

  factory VaultStats.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> attentionList = [];
    if (json['attentionRequired'] is List) {
      attentionList = (json['attentionRequired'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return VaultStats(
      totalDocuments: json['totalDocuments'] ?? 0,
      validDocuments: json['validDocuments'] ?? 0,
      favoriteDocuments: json['favoriteDocuments'] ?? 0,
      archivedDocuments: json['archivedDocuments'] ?? 0,
      expiringSoonDocuments: json['expiringSoonDocuments'] ?? 0,
      expiredDocuments: json['expiredDocuments'] ?? 0,
      noExpiryDocuments: json['noExpiryDocuments'] ?? 0,
      ocrProcessingCount: json['ocrProcessingCount'] ?? 0,
      ocrCompletedCount: json['ocrCompletedCount'] ?? 0,
      totalStorageBytes: json['totalStorageBytes'] ?? 0,
      attentionRequired: attentionList,
    );
  }
}

final vaultStatsProvider = FutureProvider<VaultStats>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final auth = ref.watch(authProvider);

  if (!auth.isAuthenticated) {
    return VaultStats.empty();
  }

  try {
    final response = await apiClient.dio.get(ApiEndpoints.documentStats);
    if (response.statusCode == 200) {
      return VaultStats.fromJson(response.data);
    }
  } catch (_) {}
  return VaultStats.empty();
});

class DocumentFilterState {
  final String? searchQuery;
  final String? categoryId;
  final bool? isFavorite;
  final bool? isExpiringSoon;
  final bool? isExpired;
  final bool? isArchived;
  final int? expiryDays;

  DocumentFilterState({
    this.searchQuery,
    this.categoryId,
    this.isFavorite,
    this.isExpiringSoon,
    this.isExpired,
    this.isArchived,
    this.expiryDays,
  });

  DocumentFilterState copyWith({
    String? searchQuery,
    String? categoryId,
    bool? isFavorite,
    bool? isExpiringSoon,
    bool? isExpired,
    bool? isArchived,
    int? expiryDays,
    bool clearCategory = false,
    bool clearExpiry = false,
  }) {
    return DocumentFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      isFavorite: isFavorite ?? this.isFavorite,
      isExpiringSoon: clearExpiry ? null : (isExpiringSoon ?? this.isExpiringSoon),
      isExpired: clearExpiry ? null : (isExpired ?? this.isExpired),
      isArchived: isArchived ?? this.isArchived,
      expiryDays: clearExpiry ? null : (expiryDays ?? this.expiryDays),
    );
  }
}

final documentFilterProvider = StateProvider<DocumentFilterState>((ref) {
  return DocumentFilterState();
});

final documentsListProvider = FutureProvider<List<DocumentModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final auth = ref.watch(authProvider);
  final filter = ref.watch(documentFilterProvider);

  if (!auth.isAuthenticated) {
    return [];
  }

  final queryParams = <String, dynamic>{};
  if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
    queryParams['search'] = filter.searchQuery;
  }
  if (filter.categoryId != null) {
    queryParams['categoryId'] = filter.categoryId;
  }
  if (filter.isFavorite == true) {
    queryParams['isFavorite'] = true;
  }
  if (filter.isExpiringSoon == true) {
    queryParams['isExpiringSoon'] = true;
  }
  if (filter.isExpired == true) {
    queryParams['isExpired'] = true;
  }
  if (filter.isArchived == true) {
    queryParams['isArchived'] = true;
  }
  if (filter.expiryDays != null) {
    queryParams['expiryDays'] = filter.expiryDays;
  }

  try {
    final response = await apiClient.dio.get(
      ApiEndpoints.documents,
      queryParameters: queryParams,
    );
    if (response.statusCode == 200) {
      final data = response.data['data'] as List;
      final docs = data.map((item) => DocumentModel.fromJson(item)).toList();
      // Cache metadata in FastViewCache
      for (var d in docs) {
        FastViewCache.instance.putMetadata(d);
      }
      return docs;
    }
  } catch (_) {}
  return [];
});

final recentlyViewedDocumentsProvider = FutureProvider<List<DocumentModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final auth = ref.watch(authProvider);

  if (!auth.isAuthenticated) return [];

  try {
    final response = await apiClient.dio.get(
      '${ApiEndpoints.documents}/recent',
      queryParameters: {'limit': 5},
    );
    if (response.statusCode == 200) {
      final data = response.data as List;
      final docs = data.map((item) => DocumentModel.fromJson(item)).toList();
      for (var d in docs) {
        FastViewCache.instance.putMetadata(d);
      }
      return docs;
    }
  } catch (_) {}
  return [];
});

/// Fast View Caching Engine
/// Maintains in-memory cache for document metadata, preview bytes, and quick access.
class FastViewCache {
  static final FastViewCache instance = FastViewCache._internal();
  FastViewCache._internal();

  final Map<String, DocumentModel> _metadataCache = {};
  final Map<String, Uint8List> _previewBytesCache = {};

  void putMetadata(DocumentModel doc) {
    _metadataCache[doc.id] = doc;
  }

  DocumentModel? getMetadata(String id) {
    return _metadataCache[id];
  }

  void putPreviewBytes(String id, Uint8List bytes) {
    _previewBytesCache[id] = bytes;
  }

  Uint8List? getPreviewBytes(String id) {
    return _previewBytesCache[id];
  }

  void clear() {
    _metadataCache.clear();
    _previewBytesCache.clear();
  }
}

/// Document Service for mutations (upload, edit, favorite, archive, delete)
class DocumentService {
  final Ref ref;

  DocumentService(this.ref);

  Future<DocumentModel?> uploadFile({
    required List<int> fileBytes,
    required String fileName,
    required String title,
    required String documentType,
    String? categoryId,
    DateTime? issueDate,
    DateTime? expiryDate,
    List<String>? tags,
    String? description,
    void Function(int sent, int total)? onProgress,
  }) async {
    final apiClient = ref.read(apiClientProvider);

    // 1. Upload binary file
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
      ),
    });

    final uploadRes = await apiClient.dio.post(
      ApiEndpoints.documentUpload,
      data: formData,
      onSendProgress: onProgress,
    );

    if (uploadRes.statusCode != 200) {
      throw Exception('File upload failed with status ${uploadRes.statusCode}');
    }

    final uploadedData = uploadRes.data;

    // 2. Create document record with metadata
    final createRes = await apiClient.dio.post(
      ApiEndpoints.documents,
      data: {
        'title': title,
        'documentType': documentType,
        'fileType': uploadedData['fileType'],
        'mimeType': uploadedData['mimeType'],
        'fileSize': uploadedData['fileSize'],
        'storagePath': uploadedData['storagePath'],
        if (categoryId != null) 'categoryId': categoryId,
        if (issueDate != null) 'issueDate': issueDate.toIso8601String(),
        if (expiryDate != null) 'expiryDate': expiryDate.toIso8601String(),
        if (tags != null && tags.isNotEmpty) 'tags': tags,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );

    if (createRes.statusCode == 201) {
      final doc = DocumentModel.fromJson(createRes.data);
      FastViewCache.instance.putMetadata(doc);
      // Cache the uploaded bytes directly for instant preview!
      final bytes = Uint8List.fromList(fileBytes);
      FastViewCache.instance.putPreviewBytes(doc.id, bytes);

      // Persist AES-256-GCM encrypted document into device-local private storage
      try {
        final localStorage = ref.read(localDocumentStorageProvider);
        await localStorage.saveDocument(
          documentId: doc.id,
          plaintextBytes: bytes,
        );
      } catch (_) {}

      ref.invalidate(documentsListProvider);
      ref.invalidate(vaultStatsProvider);
      ref.invalidate(recentlyViewedDocumentsProvider);
      return doc;
    }
    return null;
  }

  Future<DocumentModel?> toggleFavorite(String documentId) async {
    final apiClient = ref.read(apiClientProvider);
    final res = await apiClient.dio.post(ApiEndpoints.documentFavorite(documentId));
    if (res.statusCode == 200) {
      final doc = DocumentModel.fromJson(res.data);
      FastViewCache.instance.putMetadata(doc);
      ref.invalidate(documentsListProvider);
      ref.invalidate(vaultStatsProvider);
      ref.invalidate(recentlyViewedDocumentsProvider);
      return doc;
    }
    return null;
  }

  Future<DocumentModel?> toggleArchive(String documentId) async {
    final apiClient = ref.read(apiClientProvider);
    final res = await apiClient.dio.post(ApiEndpoints.documentArchive(documentId));
    if (res.statusCode == 200) {
      final doc = DocumentModel.fromJson(res.data);
      FastViewCache.instance.putMetadata(doc);
      ref.invalidate(documentsListProvider);
      ref.invalidate(vaultStatsProvider);
      return doc;
    }
    return null;
  }

  Future<DocumentModel?> updateDocument(
    String documentId, {
    String? title,
    String? categoryId,
    String? documentType,
    DateTime? issueDate,
    DateTime? expiryDate,
    List<String>? tags,
    String? description,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    final res = await apiClient.dio.patch(
      ApiEndpoints.document(documentId),
      data: {
        if (title != null) 'title': title,
        if (categoryId != null) 'categoryId': categoryId,
        if (documentType != null) 'documentType': documentType,
        if (issueDate != null) 'issueDate': issueDate.toIso8601String(),
        if (expiryDate != null) 'expiryDate': expiryDate.toIso8601String(),
        if (tags != null) 'tags': tags,
        if (description != null) 'description': description,
      },
    );

    if (res.statusCode == 200) {
      final doc = DocumentModel.fromJson(res.data);
      FastViewCache.instance.putMetadata(doc);
      ref.invalidate(documentsListProvider);
      ref.invalidate(vaultStatsProvider);
      ref.invalidate(recentlyViewedDocumentsProvider);
      return doc;
    }
    return null;
  }

  Future<bool> deleteDocument(String documentId) async {
    final apiClient = ref.read(apiClientProvider);
    final res = await apiClient.dio.delete(ApiEndpoints.document(documentId));
    if (res.statusCode == 200) {
      try {
        final localStorage = ref.read(localDocumentStorageProvider);
        await localStorage.deleteDocument(documentId);
      } catch (_) {}
      ref.invalidate(documentsListProvider);
      ref.invalidate(vaultStatsProvider);
      ref.invalidate(recentlyViewedDocumentsProvider);
      return true;
    }
    return false;
  }

  Future<Uint8List?> fetchPreviewBytes(String documentId) async {
    // 1. Check Fast View cache (RAM)
    final cached = FastViewCache.instance.getPreviewBytes(documentId);
    if (cached != null) return cached;

    // 2. Check Local-First Encrypted Vault Storage on device (Zero-Cost Local-First!)
    final localStorage = ref.read(localDocumentStorageProvider);
    try {
      if (await localStorage.documentExists(documentId)) {
        final decryptedBytes = await localStorage.readDocument(documentId);
        FastViewCache.instance.putPreviewBytes(documentId, decryptedBytes);
        return decryptedBytes;
      }
    } catch (_) {}

    // 3. Fallback to authenticated stream from preview endpoint (if available)
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.get<List<int>>(
        ApiEndpoints.documentPreview(documentId),
        options: Options(responseType: ResponseType.bytes),
      );
      if (res.statusCode == 200 && res.data != null) {
        final bytes = Uint8List.fromList(res.data!);
        FastViewCache.instance.putPreviewBytes(documentId, bytes);
        // Persist locally for instant offline Fast View next time
        try {
          await localStorage.saveDocument(
            documentId: documentId,
            plaintextBytes: bytes,
          );
        } catch (_) {}
        return bytes;
      }
    } catch (_) {}
    return null;
  }

  Future<DocumentModel?> triggerOcr(String documentId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.post(ApiEndpoints.documentOcr(documentId));
      if (res.statusCode == 200) {
        final doc = DocumentModel.fromJson(res.data);
        FastViewCache.instance.putMetadata(doc);
        ref.invalidate(documentsListProvider);
        ref.invalidate(vaultStatsProvider);
        return doc;
      }
    } catch (_) {}
    return null;
  }

  Future<DocumentModel?> confirmIntelligence(
    String documentId, {
    String? title,
    String? documentType,
    Map<String, dynamic>? extractedFields,
    DateTime? issueDate,
    DateTime? expiryDate,
    String? categoryId,
    List<String>? tags,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.patch(
        ApiEndpoints.documentIntelligence(documentId),
        data: {
          if (title != null) 'title': title,
          if (documentType != null) 'documentType': documentType,
          if (extractedFields != null) 'extractedFields': extractedFields,
          if (issueDate != null) 'issueDate': issueDate.toIso8601String(),
          if (expiryDate != null) 'expiryDate': expiryDate.toIso8601String(),
          if (categoryId != null) 'categoryId': categoryId,
          if (tags != null) 'tags': tags,
        },
      );
      if (res.statusCode == 200) {
        final doc = DocumentModel.fromJson(res.data);
        FastViewCache.instance.putMetadata(doc);
        ref.invalidate(documentsListProvider);
        ref.invalidate(vaultStatsProvider);
        ref.invalidate(recentlyViewedDocumentsProvider);
        return doc;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getReminders(String documentId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.get(ApiEndpoints.documentReminders(documentId));
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> addReminder(String documentId, DateTime reminderDate, String? notes) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.post(
        ApiEndpoints.documentReminders(documentId),
        data: {
          'reminderDate': reminderDate.toIso8601String(),
          if (notes != null) 'notes': notes,
        },
      );
      return res.statusCode == 201;
    } catch (_) {}
    return false;
  }

  Future<List<DocumentVersionModel>> fetchVersions(String documentId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.get('/documents/$documentId/versions');
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .map((e) => DocumentVersionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}

final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService(ref);
});

final localDocumentStorageProvider = Provider<LocalDocumentStorage>((ref) {
  return LocalDocumentStorage();
});

