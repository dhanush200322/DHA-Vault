import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../models/device.dart';
import 'auth_provider.dart';

class DeviceState {
  final bool isLoading;
  final List<DeviceModel> devices;
  final String? errorMessage;

  DeviceState({
    this.isLoading = false,
    this.devices = const [],
    this.errorMessage,
  });

  DeviceState copyWith({
    bool? isLoading,
    List<DeviceModel>? devices,
    String? errorMessage,
  }) {
    return DeviceState(
      isLoading: isLoading ?? this.isLoading,
      devices: devices ?? this.devices,
      errorMessage: errorMessage,
    );
  }
}

class DeviceNotifier extends StateNotifier<DeviceState> {
  final ApiClient _client;

  DeviceNotifier(this._client) : super(DeviceState()) {
    fetchDevices();
  }

  Future<void> fetchDevices() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _client.dio.get('/devices');
      if (res.statusCode == 200) {
        final list = (res.data as List)
            .map((item) => DeviceModel.fromJson(item as Map<String, dynamic>))
            .toList();
        state = state.copyWith(isLoading: false, devices: list);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load devices');
    }
  }

  Future<bool> registerCurrentDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    try {
      final res = await _client.dio.post('/devices/register', data: {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'appVersion': '3.0.0',
      });
      if (res.statusCode == 201) {
        await fetchDevices();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> toggleTrust(String deviceId, bool isTrusted) async {
    try {
      final res = await _client.dio.patch('/devices/$deviceId/trust', data: {
        'isTrusted': isTrusted,
      });
      if (res.statusCode == 200) {
        await fetchDevices();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> revokeDevice(String deviceId) async {
    try {
      final res = await _client.dio.post('/devices/$deviceId/revoke');
      if (res.statusCode == 200) {
        state = state.copyWith(
          devices: state.devices.where((d) => d.deviceId != deviceId).toList(),
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> remoteLockDevice(String deviceId) async {
    try {
      final res = await _client.dio.post('/devices/$deviceId/remote-lock');
      if (res.statusCode == 200) {
        await fetchDevices();
        return true;
      }
    } catch (_) {}
    return false;
  }
}

final deviceProvider = StateNotifierProvider<DeviceNotifier, DeviceState>((ref) {
  final client = ref.watch(apiClientProvider);
  return DeviceNotifier(client);
});
