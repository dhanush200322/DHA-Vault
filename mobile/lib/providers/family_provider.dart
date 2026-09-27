import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../models/family_vault.dart';
import 'auth_provider.dart';

class FamilyState {
  final bool isLoading;
  final List<FamilyVaultModel> families;
  final FamilyVaultModel? activeFamily;
  final List<FamilyMemberModel> members;
  final List<FamilyDocumentAccessModel> familyDocuments;
  final String? errorMessage;
  final String? lastGeneratedInviteToken;

  FamilyState({
    this.isLoading = false,
    this.families = const [],
    this.activeFamily,
    this.members = const [],
    this.familyDocuments = const [],
    this.errorMessage,
    this.lastGeneratedInviteToken,
  });

  FamilyState copyWith({
    bool? isLoading,
    List<FamilyVaultModel>? families,
    FamilyVaultModel? activeFamily,
    List<FamilyMemberModel>? members,
    List<FamilyDocumentAccessModel>? familyDocuments,
    String? errorMessage,
    String? lastGeneratedInviteToken,
  }) {
    return FamilyState(
      isLoading: isLoading ?? this.isLoading,
      families: families ?? this.families,
      activeFamily: activeFamily ?? this.activeFamily,
      members: members ?? this.members,
      familyDocuments: familyDocuments ?? this.familyDocuments,
      errorMessage: errorMessage,
      lastGeneratedInviteToken: lastGeneratedInviteToken,
    );
  }
}

class FamilyNotifier extends StateNotifier<FamilyState> {
  final ApiClient _client;

  FamilyNotifier(this._client) : super(FamilyState()) {
    fetchFamilies();
  }

  Future<void> fetchFamilies() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _client.dio.get('/families');
      if (res.statusCode == 200) {
        final list = (res.data as List)
            .map((item) => FamilyVaultModel.fromJson(item as Map<String, dynamic>))
            .toList();
        state = state.copyWith(
          isLoading: false,
          families: list,
          activeFamily: list.isNotEmpty ? (state.activeFamily ?? list.first) : null,
        );
        if (state.activeFamily != null) {
          await selectFamily(state.activeFamily!.id);
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load family vaults');
    }
  }

  Future<void> selectFamily(String familyId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _client.dio.get('/families/$familyId');
      final membersRes = await _client.dio.get('/families/$familyId/members');
      final docsRes = await _client.dio.get('/families/$familyId/documents');

      if (res.statusCode == 200) {
        final family = FamilyVaultModel.fromJson(res.data as Map<String, dynamic>);
        final members = (membersRes.data as List)
            .map((m) => FamilyMemberModel.fromJson(m as Map<String, dynamic>))
            .toList();
        final docs = (docsRes.data as List)
            .map((d) => FamilyDocumentAccessModel.fromJson(d as Map<String, dynamic>))
            .toList();

        state = state.copyWith(
          isLoading: false,
          activeFamily: family,
          members: members,
          familyDocuments: docs,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load family details');
    }
  }

  Future<bool> createFamily(String name) async {
    try {
      final res = await _client.dio.post('/families', data: {'name': name});
      if (res.statusCode == 201) {
        await fetchFamilies();
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to create family vault');
    }
    return false;
  }

  Future<String?> inviteMember(String familyId, String email, String role) async {
    try {
      final res = await _client.dio.post('/families/$familyId/invitations', data: {
        'email': email,
        'role': role,
      });
      if (res.statusCode == 201) {
        final token = res.data['token'] as String?;
        state = state.copyWith(lastGeneratedInviteToken: token);
        await selectFamily(familyId);
        return token;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to send invitation');
    }
    return null;
  }

  Future<bool> acceptInvitation(String token) async {
    try {
      final res = await _client.dio.post('/families/invitations/$token/accept');
      if (res.statusCode == 200) {
        await fetchFamilies();
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Invalid or expired invitation token');
    }
    return false;
  }

  Future<bool> updateMemberRole(String familyId, String memberUserId, String role) async {
    try {
      final res = await _client.dio.patch(
        '/families/$familyId/members/$memberUserId/role',
        data: {'role': role},
      );
      if (res.statusCode == 200) {
        await selectFamily(familyId);
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update member role');
    }
    return false;
  }

  Future<bool> removeMember(String familyId, String memberUserId) async {
    try {
      final res = await _client.dio.delete('/families/$familyId/members/$memberUserId');
      if (res.statusCode == 200) {
        await selectFamily(familyId);
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to remove member');
    }
    return false;
  }

  Future<bool> shareDocumentToFamily(
    String familyId,
    String documentId, {
    List<String> permissions = const ['VIEW', 'DOWNLOAD'],
    String? targetUserId,
  }) async {
    try {
      final res = await _client.dio.post(
        '/families/$familyId/documents/$documentId/share',
        data: {
          'permissions': permissions,
          if (targetUserId != null) 'targetUserId': targetUserId,
        },
      );
      if (res.statusCode == 201) {
        await selectFamily(familyId);
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to share document to family vault');
    }
    return false;
  }

  Future<bool> revokeFamilyDocument(String familyId, String documentId) async {
    try {
      final res = await _client.dio.delete(
        '/families/$familyId/documents/$documentId/access/all',
      );
      if (res.statusCode == 200) {
        await selectFamily(familyId);
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to revoke document access');
    }
    return false;
  }
}

final familyProvider = StateNotifierProvider<FamilyNotifier, FamilyState>((ref) {
  final client = ref.watch(apiClientProvider);
  return FamilyNotifier(client);
});
