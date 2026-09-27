import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../models/emergency_access.dart';
import '../models/document.dart';
import 'auth_provider.dart';

class EmergencyState {
  final bool isLoading;
  final List<EmergencyAccessModel> delegations;
  final List<RecoveryDelegationModel> recoveryDelegations;
  final List<DocumentModel> activeScopedDocs;
  final String? errorMessage;

  EmergencyState({
    this.isLoading = false,
    this.delegations = const [],
    this.recoveryDelegations = const [],
    this.activeScopedDocs = const [],
    this.errorMessage,
  });

  EmergencyState copyWith({
    bool? isLoading,
    List<EmergencyAccessModel>? delegations,
    List<RecoveryDelegationModel>? recoveryDelegations,
    List<DocumentModel>? activeScopedDocs,
    String? errorMessage,
  }) {
    return EmergencyState(
      isLoading: isLoading ?? this.isLoading,
      delegations: delegations ?? this.delegations,
      recoveryDelegations: recoveryDelegations ?? this.recoveryDelegations,
      activeScopedDocs: activeScopedDocs ?? this.activeScopedDocs,
      errorMessage: errorMessage,
    );
  }
}

class EmergencyNotifier extends StateNotifier<EmergencyState> {
  final ApiClient _client;

  EmergencyNotifier(this._client) : super(EmergencyState()) {
    fetchEmergencyDelegations();
    fetchRecoveryDelegations();
  }

  Future<void> fetchEmergencyDelegations() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _client.dio.get('/emergency-access');
      if (res.statusCode == 200) {
        final list = (res.data as List)
            .map((item) => EmergencyAccessModel.fromJson(item as Map<String, dynamic>))
            .toList();
        state = state.copyWith(isLoading: false, delegations: list);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load emergency delegations');
    }
  }

  Future<void> fetchRecoveryDelegations() async {
    try {
      final res = await _client.dio.get('/recovery-delegations');
      if (res.statusCode == 200) {
        final list = (res.data as List)
            .map((item) => RecoveryDelegationModel.fromJson(item as Map<String, dynamic>))
            .toList();
        state = state.copyWith(recoveryDelegations: list);
      }
    } catch (_) {}
  }

  Future<bool> createEmergencyDelegate({
    required String delegateEmail,
    int activationDelayHours = 48,
    String scope = 'SELECTED_DOCUMENTS',
    List<String> selectedDocIds = const [],
    String? notes,
  }) async {
    try {
      final res = await _client.dio.post('/emergency-access', data: {
        'delegateEmail': delegateEmail,
        'activationDelayHours': activationDelayHours,
        'scope': scope,
        'selectedDocIds': selectedDocIds,
        if (notes != null) 'notes': notes,
      });

      if (res.statusCode == 201) {
        await fetchEmergencyDelegations();
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to configure emergency delegate');
    }
    return false;
  }

  Future<bool> triggerActivation(String id) async {
    try {
      final res = await _client.dio.post('/emergency-access/$id/activate');
      if (res.statusCode == 200) {
        await fetchEmergencyDelegations();
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to trigger emergency activation');
    }
    return false;
  }

  Future<bool> cancelActivation(String id) async {
    try {
      final res = await _client.dio.post('/emergency-access/$id/cancel');
      if (res.statusCode == 200) {
        await fetchEmergencyDelegations();
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to cancel emergency activation');
    }
    return false;
  }

  Future<bool> revokeEmergency(String id) async {
    try {
      final res = await _client.dio.post('/emergency-access/$id/revoke');
      if (res.statusCode == 200) {
        await fetchEmergencyDelegations();
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to revoke emergency access');
    }
    return false;
  }

  Future<List<DocumentModel>> fetchScopedDocuments(String id) async {
    try {
      final res = await _client.dio.get('/emergency-access/$id/documents');
      if (res.statusCode == 200) {
        final docs = (res.data as List)
            .map((item) => DocumentModel.fromJson(item as Map<String, dynamic>))
            .toList();
        state = state.copyWith(activeScopedDocs: docs);
        return docs;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Access not activated or waiting period active');
    }
    return [];
  }

  Future<bool> createRecoveryDelegation({
    required String delegateEmail,
    int expiresInDays = 30,
  }) async {
    try {
      final res = await _client.dio.post('/recovery-delegations', data: {
        'delegateEmail': delegateEmail,
        'expiresInDays': expiresInDays,
      });
      if (res.statusCode == 201) {
        await fetchRecoveryDelegations();
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to setup recovery delegation');
    }
    return false;
  }

  Future<bool> acceptRecovery(String id) async {
    try {
      final res = await _client.dio.post('/recovery-delegations/$id/accept');
      if (res.statusCode == 200) {
        await fetchRecoveryDelegations();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> revokeRecovery(String id) async {
    try {
      final res = await _client.dio.post('/recovery-delegations/$id/revoke');
      if (res.statusCode == 200) {
        await fetchRecoveryDelegations();
        return true;
      }
    } catch (_) {}
    return false;
  }
}

final emergencyProvider = StateNotifierProvider<EmergencyNotifier, EmergencyState>((ref) {
  final client = ref.watch(apiClientProvider);
  return EmergencyNotifier(client);
});
