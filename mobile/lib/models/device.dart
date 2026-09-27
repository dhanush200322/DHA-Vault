class DeviceModel {
  final String id;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String? pushToken;
  final DateTime lastActiveAt;
  final bool isTrusted;
  final bool isLocked;
  final String syncStatus;
  final String? appVersion;
  final DateTime createdAt;

  DeviceModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    this.pushToken,
    required this.lastActiveAt,
    required this.isTrusted,
    required this.isLocked,
    required this.syncStatus,
    this.appVersion,
    required this.createdAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String? ?? 'Unknown Device',
      platform: (json['platform'] as String? ?? 'mobile').toLowerCase(),
      pushToken: json['pushToken'] as String?,
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.parse(json['lastActiveAt'] as String)
          : DateTime.now(),
      isTrusted: json['isTrusted'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      syncStatus: json['syncStatus'] as String? ?? 'IDLE',
      appVersion: json['appVersion'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'pushToken': pushToken,
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'isTrusted': isTrusted,
      'isLocked': isLocked,
      'syncStatus': syncStatus,
      'appVersion': appVersion,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
