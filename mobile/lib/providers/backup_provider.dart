import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../models/backup_status.dart';
import '../models/storage_breakdown.dart';
import 'auth_provider.dart';

class BackupState {
  final bool isBackingUp;
  final bool isRestoring;
  final bool isCloudBackupEnabled;
  final bool isWifiOnly;
  final bool isAutoBackup;
  final BackupStatusModel? status;
  final StorageBreakdownModel? storage;
  final String? errorMessage;
  final String? successMessage;

  BackupState({
    this.isBackingUp = false,
    this.isRestoring = false,
    this.isCloudBackupEnabled = false, // Local-only mode by default for privacy
    this.isWifiOnly = true,
    this.isAutoBackup = true,
    this.status,
    this.storage,
    this.errorMessage,
    this.successMessage,
  });

  BackupState copyWith({
    bool? isBackingUp,
    bool? isRestoring,
    bool? isCloudBackupEnabled,
    bool? isWifiOnly,
    bool? isAutoBackup,
    BackupStatusModel? status,
    StorageBreakdownModel? storage,
    String? errorMessage,
    String? successMessage,
  }) {
    return BackupState(
      isBackingUp: isBackingUp ?? this.isBackingUp,
      isRestoring: isRestoring ?? this.isRestoring,
      isCloudBackupEnabled: isCloudBackupEnabled ?? this.isCloudBackupEnabled,
      isWifiOnly: isWifiOnly ?? this.isWifiOnly,
      isAutoBackup: isAutoBackup ?? this.isAutoBackup,
      status: status ?? this.status,
      storage: storage ?? this.storage,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class BackupNotifier extends StateNotifier<BackupState> {
  final ApiClient _client;

  BackupNotifier(this._client) : super(BackupState()) {
    fetchStatus();
    fetchStorage();
  }

  void toggleCloudBackup(bool enabled) {
    state = state.copyWith(isCloudBackupEnabled: enabled);
  }

  void toggleWifiOnly(bool wifiOnly) {
    state = state.copyWith(isWifiOnly: wifiOnly);
  }

  void toggleAutoBackup(bool autoBackup) {
    state = state.copyWith(isAutoBackup: autoBackup);
  }

  Future<void> fetchStatus() async {
    try {
      final res = await _client.dio.get('/backup/status');
      if (res.statusCode == 200) {
        final model = BackupStatusModel.fromJson(res.data as Map<String, dynamic>);
        state = state.copyWith(status: model);
      }
    } catch (_) {}
  }

  Future<void> fetchStorage() async {
    try {
      final res = await _client.dio.get('/backup/storage');
      if (res.statusCode == 200) {
        final model = StorageBreakdownModel.fromJson(res.data as Map<String, dynamic>);
        state = state.copyWith(storage: model);
      }
    } catch (_) {}
  }

  Future<bool> startBackup() async {
    state = state.copyWith(isBackingUp: true, errorMessage: null, successMessage: null);
    try {
      final res = await _client.dio.post('/backup/start');
      if (res.statusCode == 200) {
        await fetchStatus();
        await fetchStorage();
        state = state.copyWith(
          isBackingUp: false,
          successMessage: 'Encrypted cloud backup completed successfully!',
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(isBackingUp: false, errorMessage: 'Backup failed');
    }
    state = state.copyWith(isBackingUp: false);
    return false;
  }

  Future<bool> restoreVault({String? backupId}) async {
    state = state.copyWith(isRestoring: true, errorMessage: null, successMessage: null);
    try {
      final res = await _client.dio.post('/backup/restore', data: {
        if (backupId != null) 'backupId': backupId,
      });
      if (res.statusCode == 200) {
        await fetchStatus();
        await fetchStorage();
        state = state.copyWith(
          isRestoring: false,
          successMessage: 'Vault index restored and verified!',
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(isRestoring: false, errorMessage: 'Vault restore failed');
    }
    state = state.copyWith(isRestoring: false);
    return false;
  }
}

final backupProvider = StateNotifierProvider<BackupNotifier, BackupState>((ref) {
  final client = ref.watch(apiClientProvider);
  return BackupNotifier(client);
});
