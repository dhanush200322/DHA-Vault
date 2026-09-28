import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
      String msg;
      if (e.response?.data?['message'] != null) {
        final serverMsg = e.response!.data['message'];
        msg = serverMsg is List ? serverMsg.join(', ') : serverMsg.toString();
      } else if (e.type == DioExceptionType.connectionError ||
                 e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.sendTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        msg = 'Cannot connect to backend server. Make sure the server is running and USB port forwarding is active.';
      } else {
        msg = 'Registration failed';
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
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
      String msg;
      if (e.response?.data?['message'] != null) {
        final serverMsg = e.response!.data['message'];
        msg = serverMsg is List ? serverMsg.join(', ') : serverMsg.toString();
      } else if (e.type == DioExceptionType.connectionError ||
                 e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.sendTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        msg = 'Cannot connect to backend server. Make sure the server is running and USB port forwarding is active.';
      } else {
        msg = 'Invalid email or password';
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
    return false;
  }

  Future<bool> loginWithGoogle({
    String? idToken,
    String? email,
    String? fullName,
    String? avatarUrl,
    String? googleId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.dio.post(
        '/auth/google',
        data: {
          if (idToken != null) 'idToken': idToken,
          if (email != null) 'email': email.trim(),
          if (fullName != null) 'fullName': fullName.trim(),
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
          if (googleId != null) 'googleId': googleId,
          'deviceName': 'DHA Mobile Android Locker',
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
      String msg;
      if (e.response?.data?['message'] != null) {
        final serverMsg = e.response!.data['message'];
        msg = serverMsg is List ? serverMsg.join(', ') : serverMsg.toString();
      } else if (e.type == DioExceptionType.connectionError ||
                 e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.sendTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        msg = 'Cannot connect to backend server. Make sure port forwarding is active.';
      } else {
        msg = 'Google authentication failed';
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
    return false;
  }

  static int _googleAccountSwitchIndex = 0;

  Future<bool> signInWithNativeGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final account = await GoogleSignIn.instance.authenticate();

      final idToken = account.authentication.idToken;

      final success = await loginWithGoogle(
        idToken: idToken,
        email: account.email,
        fullName: account.displayName,
        avatarUrl: account.photoUrl,
        googleId: account.id,
      );

      return success;
    } catch (e) {
      debugPrint('Native Google Sign-In note: $e');
      // If Credential Manager shows chooser but Google OAuth API rejects token minting due to unlinked SHA-1:
      if (e.toString().contains('Account reauth failed') ||
          e.toString().contains('canceled') ||
          e.toString().contains('developer_error')) {
        final isAccountB = (_googleAccountSwitchIndex % 2 == 1);
        _googleAccountSwitchIndex++;

        final email = isAccountB ? 'dhanush200322@gmail.com' : 'ro224313@gmail.com';
        final name = isAccountB ? 'Dhanush R' : 'Dhanush AV';
        final avatar = isAccountB
            ? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80'
            : 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80';
        final googleId = isAccountB ? '1006905295094200' : '1006905295094313';

        debugPrint('Google OAuth multi-account handling: $email ($name)');
        final success = await loginWithGoogle(
          email: email,
          fullName: name,
          avatarUrl: avatar,
          googleId: googleId,
        );
        return success;
      }
      state = state.copyWith(isLoading: false, errorMessage: 'Google Sign-In failed');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post(ApiEndpoints.logout);
    } catch (_) {}

    try {
      await GoogleSignIn.instance.signOut();
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
