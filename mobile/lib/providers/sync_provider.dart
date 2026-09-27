import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../models/sync_status.dart';
import 'auth_provider.dart';

class SyncState {
  final bool isSyncing;
  final SyncStatusModel? status;
  final String? errorMessage;
  final String? lastSyncMessage;

  SyncState({
    this.isSyncing = false,
    this.status,
    this.errorMessage,
    this.lastSyncMessage,
  });

  SyncState copyWith({
    bool? isSyncing,
    SyncStatusModel? status,
    String? errorMessage,
    String? lastSyncMessage,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      status: status ?? this.status,
      errorMessage: errorMessage,
      lastSyncMessage: lastSyncMessage ?? this.lastSyncMessage,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final ApiClient _client;

  SyncNotifier(this._client) : super(SyncState()) {
    fetchSyncStatus();
  }

  Future<void> fetchSyncStatus() async {
    try {
      final res = await _client.dio.get('/sync/status');
      if (res.statusCode == 200) {
        final model = SyncStatusModel.fromJson(res.data as Map<String, dynamic>);
        state = state.copyWith(status: model, errorMessage: null);
      }
    } catch (_) {
      // Offline fallback
      state = state.copyWith(
        status: SyncStatusModel(
          status: 'OFFLINE',
          totalDocuments: state.status?.totalDocuments ?? 0,
          syncedDocuments: state.status?.syncedDocuments ?? 0,
          pendingCount: state.status?.pendingCount ?? 0,
          conflictCount: state.status?.conflictCount ?? 0,
        ),
      );
    }
  }

  Future<bool> startSync({String? deviceId}) async {
    state = state.copyWith(isSyncing: true, errorMessage: null);
    try {
      final res = await _client.dio.post('/sync/start', data: {
        'deviceId': deviceId,
        'items': [],
      });
      if (res.statusCode == 200) {
        final message = res.data['message'] as String?;
        await fetchSyncStatus();
        state = state.copyWith(isSyncing: false, lastSyncMessage: message);
        return true;
      }
    } catch (e) {
      state = state.copyWith(isSyncing: false, errorMessage: 'Sync failed');
    }
    state = state.copyWith(isSyncing: false);
    return false;
  }

  Future<bool> resolveConflict(String conflictId, String resolution) async {
    try {
      final res = await _client.dio.post('/sync/resolve-conflict', data: {
        'conflictId': conflictId,
        'resolution': resolution,
      });
      if (res.statusCode == 200) {
        await fetchSyncStatus();
        return true;
      }
    } catch (_) {}
    return false;
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final client = ref.watch(apiClientProvider);
  return SyncNotifier(client);
});
