class StorageCategoryUsage {
  final int bytes;
  final int count;

  StorageCategoryUsage({required this.bytes, required this.count});

  factory StorageCategoryUsage.fromJson(Map<String, dynamic> json) {
    return StorageCategoryUsage(
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class StorageBreakdownModel {
  final int totalUsedBytes;
  final int quotaBytes;
  final int availableBytes;
  final StorageCategoryUsage documents;
  final StorageCategoryUsage versions;
  final StorageCategoryUsage backups;

  StorageBreakdownModel({
    required this.totalUsedBytes,
    required this.quotaBytes,
    required this.availableBytes,
    required this.documents,
    required this.versions,
    required this.backups,
  });

  factory StorageBreakdownModel.fromJson(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] as Map<String, dynamic>? ?? {};
    return StorageBreakdownModel(
      totalUsedBytes: (json['totalUsedBytes'] as num?)?.toInt() ?? 0,
      quotaBytes: (json['quotaBytes'] as num?)?.toInt() ?? 10737418240,
      availableBytes: (json['availableBytes'] as num?)?.toInt() ?? 10737418240,
      documents: StorageCategoryUsage.fromJson(breakdown['documents'] as Map<String, dynamic>? ?? {}),
      versions: StorageCategoryUsage.fromJson(breakdown['versions'] as Map<String, dynamic>? ?? {}),
      backups: StorageCategoryUsage.fromJson(breakdown['backups'] as Map<String, dynamic>? ?? {}),
    );
  }

  String get formattedUsed {
    final mb = totalUsedBytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(1)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get formattedQuota {
    final gb = quotaBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(0)} GB';
  }

  double get usedPercentage {
    if (quotaBytes == 0) return 0.0;
    return (totalUsedBytes / quotaBytes).clamp(0.0, 1.0);
  }
}
