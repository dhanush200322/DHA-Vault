class EmergencyAccessModel {
  final String id;
  final String ownerId;
  final String? delegateUserId;
  final String delegateEmail;
  final String status; // PENDING, ACTIVE, TRIGGERED, EXPIRED, REVOKED, COMPLETED
  final int activationDelayHours;
  final DateTime? triggerRequestedAt;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final String scope; // ALL, SELECTED_DOCUMENTS, CATEGORIES, FAMILY_DOCUMENTS
  final List<String> selectedDocIds;
  final String? notes;
  final bool isFullyActivated;
  final int remainingSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ownerEmail;
  final String? delegateName;

  EmergencyAccessModel({
    required this.id,
    required this.ownerId,
    this.delegateUserId,
    required this.delegateEmail,
    required this.status,
    this.activationDelayHours = 48,
    this.triggerRequestedAt,
    this.activatedAt,
    this.expiresAt,
    this.scope = 'SELECTED_DOCUMENTS',
    this.selectedDocIds = const [],
    this.notes,
    this.isFullyActivated = false,
    this.remainingSeconds = 0,
    required this.createdAt,
    required this.updatedAt,
    this.ownerEmail,
    this.delegateName,
  });

  factory EmergencyAccessModel.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;
    final delegate = json['delegateUser'] as Map<String, dynamic>?;
    final delegateProfile = delegate?['profile'] as Map<String, dynamic>?;

    return EmergencyAccessModel(
      id: json['id'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      delegateUserId: json['delegateUserId'] as String?,
      delegateEmail: json['delegateEmail'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      activationDelayHours: json['activationDelayHours'] as int? ?? 48,
      triggerRequestedAt: json['triggerRequestedAt'] != null
          ? DateTime.tryParse(json['triggerRequestedAt'])
          : null,
      activatedAt: json['activatedAt'] != null
          ? DateTime.tryParse(json['activatedAt'])
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
      scope: json['scope'] as String? ?? 'SELECTED_DOCUMENTS',
      selectedDocIds: (json['selectedDocIds'] as List<dynamic>?)
              ?.map((id) => id.toString())
              .toList() ??
          [],
      notes: json['notes'] as String?,
      isFullyActivated: json['isFullyActivated'] as bool? ?? false,
      remainingSeconds: json['remainingSeconds'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      ownerEmail: owner?['email'] as String?,
      delegateName: delegateProfile?['fullName'] as String?,
    );
  }

  bool get isTriggered => status == 'TRIGGERED';
  bool get isCompleted => status == 'COMPLETED' || isFullyActivated;
  bool get isRevoked => status == 'REVOKED';
  bool get isActive => status == 'ACTIVE';
  DateTime? get triggeredAt => triggerRequestedAt;
}

class RecoveryDelegationModel {
  final String id;
  final String ownerId;
  final String? delegateUserId;
  final String delegateEmail;
  final String status; // PENDING, ACTIVE, REVOKED, COMPLETED
  final Map<String, dynamic>? recoveryPayload;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ownerEmail;
  final String? delegateName;

  RecoveryDelegationModel({
    required this.id,
    required this.ownerId,
    this.delegateUserId,
    required this.delegateEmail,
    required this.status,
    this.recoveryPayload,
    this.expiresAt,
    this.acceptedAt,
    this.revokedAt,
    required this.createdAt,
    required this.updatedAt,
    this.ownerEmail,
    this.delegateName,
  });

  factory RecoveryDelegationModel.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;
    final delegate = json['delegateUser'] as Map<String, dynamic>?;
    final delegateProfile = delegate?['profile'] as Map<String, dynamic>?;

    return RecoveryDelegationModel(
      id: json['id'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      delegateUserId: json['delegateUserId'] as String?,
      delegateEmail: json['delegateEmail'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      recoveryPayload: json['recoveryPayload'] as Map<String, dynamic>?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.tryParse(json['acceptedAt'])
          : null,
      revokedAt: json['revokedAt'] != null
          ? DateTime.tryParse(json['revokedAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      ownerEmail: owner?['email'] as String?,
      delegateName: delegateProfile?['fullName'] as String?,
    );
  }

  bool get isActive => status == 'ACTIVE';
  bool get isPending => status == 'PENDING';
  bool get isRevoked => status == 'REVOKED';
  bool get isAccepted => status == 'ACCEPTED';
}
