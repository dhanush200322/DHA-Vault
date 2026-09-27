class BackupStatusModel {
  final String status; // COMPLETED, IN_PROGRESS, PAUSED, FAILED
  final DateTime? lastBackupAt;
  final int totalDocuments;
  final int totalStorageBytes;
  final int pendingCount;
  final String storageProvider;
  final String? latestBackupId;

  BackupStatusModel({
    required this.status,
    this.lastBackupAt,
    required this.totalDocuments,
    required this.totalStorageBytes,
    required this.pendingCount,
    required this.storageProvider,
    this.latestBackupId,
  });

  factory BackupStatusModel.fromJson(Map<String, dynamic> json) {
    return BackupStatusModel(
      status: json['status'] as String? ?? 'COMPLETED',
      lastBackupAt: json['lastBackupAt'] != null
          ? DateTime.parse(json['lastBackupAt'] as String)
          : null,
      totalDocuments: json['totalDocuments'] as int? ?? 0,
      totalStorageBytes: (json['totalStorageBytes'] as num?)?.toInt() ?? 0,
      pendingCount: json['pendingCount'] as int? ?? 0,
      storageProvider: json['storageProvider'] as String? ?? 'local',
      latestBackupId: json['latestBackupId'] as String?,
    );
  }
}
