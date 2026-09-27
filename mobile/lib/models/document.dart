import 'category.dart';

class DocumentModel {
  final String id;
  final String userId;
  final String? categoryId;
  final String title;
  final String? description;
  final String documentType;
  final String fileType;
  final int fileSize;
  final String mimeType;
  final String storagePath;
  final String? thumbnailPath;
  final String? extractedText;
  final String ocrStatus;
  final double? ocrConfidence;
  final String? ocrProvider;
  final Map<String, dynamic>? extractedFields;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final bool isFavorite;
  final bool isArchived;
  final bool isEncrypted;
  final String? checksum;
  final String syncStatus;
  final int encryptionVersion;
  final DateTime createdAt;
  final List<String> tags;
  final DateTime updatedAt;
  final CategoryModel? category;

  DocumentModel({
    required this.id,
    required this.userId,
    this.categoryId,
    required this.title,
    this.description,
    required this.documentType,
    required this.fileType,
    required this.fileSize,
    required this.mimeType,
    required this.storagePath,
    this.thumbnailPath,
    this.extractedText,
    this.ocrStatus = 'PENDING',
    this.ocrConfidence,
    this.ocrProvider,
    this.extractedFields,
    this.issueDate,
    this.expiryDate,
    this.isFavorite = false,
    this.isArchived = false,
    this.isEncrypted = false,
    this.checksum,
    this.syncStatus = 'SYNCED',
    this.encryptionVersion = 1,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.category,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    // Parse tags safely if array of strings or array of {tag: {name: ...}}
    List<String> parsedTags = [];
    if (json['tags'] is List) {
      for (final t in json['tags'] as List) {
        if (t is String) {
          parsedTags.add(t);
        } else if (t is Map && t['tag'] is Map && t['tag']['name'] != null) {
          parsedTags.add('#${t['tag']['name']}');
        } else if (t is Map && t['name'] != null) {
          parsedTags.add('#${t['name']}');
        }
      }
    }

    return DocumentModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      categoryId: json['categoryId'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      documentType: json['documentType'] as String? ?? 'OTHER',
      fileType: json['fileType'] as String? ?? 'PDF',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      mimeType: json['mimeType'] as String? ?? 'application/pdf',
      storagePath: json['storagePath'] as String? ?? '',
      thumbnailPath: json['thumbnailPath'] as String?,
      extractedText: json['extractedText'] as String?,
      ocrStatus: json['ocrStatus'] as String? ?? 'PENDING',
      ocrConfidence: (json['ocrConfidence'] as num?)?.toDouble(),
      ocrProvider: json['ocrProvider'] as String?,
      extractedFields: json['extractedFields'] as Map<String, dynamic>?,
      issueDate: json['issueDate'] != null ? DateTime.tryParse(json['issueDate'] as String) : null,
      expiryDate: json['expiryDate'] != null ? DateTime.tryParse(json['expiryDate'] as String) : null,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      isEncrypted: json['isEncrypted'] as bool? ?? false,
      checksum: json['checksum'] as String?,
      syncStatus: json['syncStatus'] as String? ?? 'SYNCED',
      encryptionVersion: (json['encryptionVersion'] as num?)?.toInt() ?? 1,
      tags: parsedTags,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      category: json['category'] != null ? CategoryModel.fromJson(json['category']) : null,
    );
  }

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final diff = daysUntilExpiry!;
    return diff >= 0 && diff <= 30;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  String get expiryStatus {
    if (expiryDate == null) return 'VALID';
    if (isExpired) return 'EXPIRED';
    if (isExpiringSoon) return 'EXPIRING SOON';
    return 'VALID';
  }

  bool get isOcrPending => ocrStatus == 'PENDING';
  bool get isOcrProcessing => ocrStatus == 'PROCESSING';
  bool get isOcrCompleted => ocrStatus == 'COMPLETED';
  bool get isOcrFailed => ocrStatus == 'FAILED';

  String get ocrConfidencePercentage {
    if (ocrConfidence == null) return '';
    return '${(ocrConfidence! * 100).toStringAsFixed(0)}%';
  }
}
