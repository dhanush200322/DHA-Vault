class SyncStatusModel {
  final String status; // SYNCED, SYNCING, CONFLICT, OFFLINE
  final int totalDocuments;
  final int syncedDocuments;
  final int pendingCount;
  final int conflictCount;
  final DateTime? lastSyncedAt;

  SyncStatusModel({
    required this.status,
    required this.totalDocuments,
    required this.syncedDocuments,
    required this.pendingCount,
    required this.conflictCount,
    this.lastSyncedAt,
  });

  factory SyncStatusModel.fromJson(Map<String, dynamic> json) {
    return SyncStatusModel(
      status: json['status'] as String? ?? 'SYNCED',
      totalDocuments: json['totalDocuments'] as int? ?? 0,
      syncedDocuments: json['syncedDocuments'] as int? ?? 0,
      pendingCount: json['pendingCount'] as int? ?? 0,
      conflictCount: json['conflictCount'] as int? ?? 0,
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'] as String)
          : null,
    );
  }
}
