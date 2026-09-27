class DocumentVersionModel {
  final String id;
  final String documentId;
  final int versionNumber;
  final int fileSize;
  final String storagePath;
  final String? checksum;
  final String? changeNotes;
  final String? deviceId;
  final DateTime createdAt;

  DocumentVersionModel({
    required this.id,
    required this.documentId,
    required this.versionNumber,
    required this.fileSize,
    required this.storagePath,
    this.checksum,
    this.changeNotes,
    this.deviceId,
    required this.createdAt,
  });

  factory DocumentVersionModel.fromJson(Map<String, dynamic> json) {
    return DocumentVersionModel(
      id: json['id'] as String,
      documentId: json['documentId'] as String,
      versionNumber: json['versionNumber'] as int? ?? 1,
      fileSize: json['fileSize'] as int? ?? 0,
      storagePath: json['storagePath'] as String? ?? '',
      checksum: json['checksum'] as String?,
      changeNotes: json['changeNotes'] as String?,
      deviceId: json['deviceId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentId': documentId,
      'versionNumber': versionNumber,
      'fileSize': fileSize,
      'storagePath': storagePath,
      'checksum': checksum,
      'changeNotes': changeNotes,
      'deviceId': deviceId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
