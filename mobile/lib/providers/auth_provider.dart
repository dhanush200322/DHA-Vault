import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user.dart';
import 'security_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage: storage);
});

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? errorMessage;

  AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final Ref _ref;

  AuthNotifier(this._apiClient, this._ref) : super(AuthState(isLoading: true)) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.getAccessToken();

    if (token == null || token.isEmpty) {
      state = AuthState(isLoading: false, isAuthenticated: false);
      return;
    }

    try {
      final response = await _apiClient.dio.get(ApiEndpoints.me);
      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        state = AuthState(
          user: user,
          isLoading: false,
          isAuthenticated: true,
        );
        return;
      }
    } catch (_) {
      await storage.clearTokens();
    }

    state = AuthState(isLoading: false, isAuthenticated: false);
  }

  Future<bool> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.register,
        data: {
          'email': email.trim(),
          'password': password,
          if (fullName != null) 'fullName': fullName.trim(),
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;
        final storage = _ref.read(secureStorageProvider);
        await storage.saveTokens(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
        );

        final user = UserModel.fromJson(data['user']);
        state = AuthState(
          user: user,
          isLoading: false,
          isAuthenticated: true,
        );
        return true;
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Registration failed';
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg is List ? msg.join(', ') : msg.toString(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
    return false;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.login,
        data: {
          'email': email.trim(),
          'password': password,
          'deviceName': 'DHA Mobile Locker',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final storage = _ref.read(secureStorageProvider);
        await storage.saveTokens(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
        );

        final user = UserModel.fromJson(data['user']);
        state = AuthState(
          user: user,
          isLoading: false,
          isAuthenticated: true,
        );
        return true;
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Invalid credentials';
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg is List ? msg.join(', ') : msg.toString(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
    return false;
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post(ApiEndpoints.logout);
    } catch (_) {}

    final storage = _ref.read(secureStorageProvider);
    await storage.clearTokens();
    _ref.read(securityProvider.notifier).lockVault();

    state = AuthState(isLoading: false, isAuthenticated: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient, ref);
});
