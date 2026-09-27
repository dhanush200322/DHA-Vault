import 'document.dart';

class DocumentShareModel {
  final String id;
  final String documentId;
  final String ownerId;
  final String? recipientUserId;
  final String? recipientEmail;
  final List<String> permissions;
  final String status; // ACTIVE, EXPIRED, REVOKED, MAX_VIEWS_REACHED
  final Map<String, dynamic>? keyEnvelope;
  final bool allowDownload;
  final int? maxViews;
  final int viewCount;
  final String? watermarkText;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DocumentModel? document;
  final String? ownerEmail;
  final String? recipientUserEmail;

  DocumentShareModel({
    required this.id,
    required this.documentId,
    required this.ownerId,
    this.recipientUserId,
    this.recipientEmail,
    required this.permissions,
    required this.status,
    this.keyEnvelope,
    this.allowDownload = true,
    this.maxViews,
    this.viewCount = 0,
    this.watermarkText,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.document,
    this.ownerEmail,
    this.recipientUserEmail,
  });

  factory DocumentShareModel.fromJson(Map<String, dynamic> json) {
    final docJson = json['document'] as Map<String, dynamic>?;
    final ownerJson = json['owner'] as Map<String, dynamic>?;
    final recipientJson = json['recipientUser'] as Map<String, dynamic>?;

    return DocumentShareModel(
      id: json['id'] as String? ?? '',
      documentId: json['documentId'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      recipientUserId: json['recipientUserId'] as String?,
      recipientEmail: json['recipientEmail'] as String?,
      permissions: (json['permissions'] as List<dynamic>?)?.map((p) => p.toString()).toList() ?? ['VIEW', 'DOWNLOAD'],
      status: json['status'] as String? ?? 'ACTIVE',
      keyEnvelope: json['keyEnvelope'] as Map<String, dynamic>?,
      allowDownload: json['allowDownload'] as bool? ?? true,
      maxViews: json['maxViews'] as int?,
      viewCount: json['viewCount'] as int? ?? 0,
      watermarkText: json['watermarkText'] as String?,
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt']) : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
      document: docJson != null ? DocumentModel.fromJson(docJson) : null,
      ownerEmail: ownerJson?['email'] as String?,
      recipientUserEmail: recipientJson?['email'] as String? ?? json['recipientEmail'] as String?,
    );
  }

  bool get isActive => status == 'ACTIVE';
  bool get isExpired => status == 'EXPIRED' || (expiresAt != null && DateTime.now().isAfter(expiresAt!));
  bool get isRevoked => status == 'REVOKED';
  bool get isMaxViewsReached => status == 'MAX_VIEWS_REACHED' || (maxViews != null && viewCount >= maxViews!);

  String get documentTitle => document?.title ?? 'Shared Document';
  String get documentCategory => document?.category?.name ?? document?.documentType ?? 'General';
}
