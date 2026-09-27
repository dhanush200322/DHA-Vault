import 'document.dart';

class FamilyMemberModel {
  final String id;
  final String familyVaultId;
  final String userId;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String role; // OWNER, MEMBER, VIEWER
  final String status; // ACTIVE, INVITED, SUSPENDED, REMOVED
  final DateTime? joinedAt;
  final DateTime createdAt;

  FamilyMemberModel({
    required this.id,
    required this.familyVaultId,
    required this.userId,
    required this.email,
    this.fullName,
    this.avatarUrl,
    required this.role,
    required this.status,
    this.joinedAt,
    required this.createdAt,
  });

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final profile = user?['profile'] as Map<String, dynamic>?;

    return FamilyMemberModel(
      id: json['id'] as String? ?? '',
      familyVaultId: json['familyVaultId'] as String? ?? '',
      userId: json['userId'] as String? ?? user?['id'] as String? ?? '',
      email: user?['email'] as String? ?? json['email'] as String? ?? '',
      fullName: profile?['fullName'] as String?,
      avatarUrl: profile?['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'MEMBER',
      status: json['status'] as String? ?? 'ACTIVE',
      joinedAt: json['joinedAt'] != null ? DateTime.tryParse(json['joinedAt']) : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }
}

class FamilyVaultModel {
  final String id;
  final String name;
  final String ownerId;
  final String status;
  final Map<String, dynamic>? settings;
  final String? currentUserRole;
  final List<FamilyMemberModel> members;
  final int memberCount;
  final int documentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyVaultModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.status,
    this.settings,
    this.currentUserRole,
    this.members = const [],
    this.memberCount = 0,
    this.documentCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyVaultModel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    final membersList = (json['members'] as List<dynamic>?)
            ?.map((m) => FamilyMemberModel.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];

    return FamilyVaultModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Family Vault',
      ownerId: json['ownerId'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      settings: json['settings'] as Map<String, dynamic>?,
      currentUserRole: json['currentUserRole'] as String? ?? json['myRole'] as String?,
      members: membersList,
      memberCount: count?['members'] as int? ?? membersList.length,
      documentCount: count?['documentAccess'] as int? ?? count?['documents'] as int? ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
    );
  }

  bool get isOwner => currentUserRole == 'OWNER';
  bool get canShare => currentUserRole == 'OWNER' || currentUserRole == 'MEMBER';
  bool get canManageMembers => isOwner;
}

class FamilyDocumentAccessModel {
  final String accessId;
  final String familyVaultId;
  final List<String> permissions;
  final DateTime sharedAt;
  final String sharedByEmail;
  final String? targetUserId;
  final DocumentModel? document;

  FamilyDocumentAccessModel({
    required this.accessId,
    required this.familyVaultId,
    required this.permissions,
    required this.sharedAt,
    required this.sharedByEmail,
    this.targetUserId,
    this.document,
  });

  String get id => accessId;
  String get documentId => document?.id ?? '';

  factory FamilyDocumentAccessModel.fromJson(Map<String, dynamic> json) {
    final sharedBy = json['sharedBy'] as Map<String, dynamic>?;
    final docJson = json['document'] as Map<String, dynamic>?;

    return FamilyDocumentAccessModel(
      accessId: json['accessId'] as String? ?? json['id'] as String? ?? '',
      familyVaultId: json['familyVaultId'] as String? ?? '',
      permissions: (json['permissions'] as List<dynamic>?)?.map((p) => p.toString()).toList() ?? ['VIEW', 'DOWNLOAD'],
      sharedAt: json['sharedAt'] != null ? DateTime.parse(json['sharedAt']) : DateTime.now(),
      sharedByEmail: sharedBy?['email'] as String? ?? 'Family Member',
      targetUserId: json['targetUserId'] as String?,
      document: docJson != null ? DocumentModel.fromJson(docJson) : null,
    );
  }
}
