import 'package:dio/dio.dart';
import '../../config/app_config.dart';
import '../storage/secure_vault_storage.dart';

class ApiClient {
  late final Dio dio;
  final SecureVaultStorage storage;

  ApiClient({required this.storage}) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // If 401 Unauthorized, attempt refresh token rotation
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/auth/')) {
            final refreshToken = await storage.getRefreshToken();
            if (refreshToken != null) {
              try {
                final refreshResponse = await Dio(
                  BaseOptions(baseUrl: AppConfig.apiBaseUrl),
                ).post(
                  '/auth/refresh',
                  data: {'refreshToken': refreshToken},
                );

                if (refreshResponse.statusCode == 200) {
                  final newAccess = refreshResponse.data['accessToken'] as String;
                  final newRefresh = refreshResponse.data['refreshToken'] as String;
                  await storage.saveTokens(
                    accessToken: newAccess,
                    refreshToken: newRefresh,
                  );

                  // Retry the original request
                  error.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
                  final clonedRequest = await dio.fetch(error.requestOptions);
                  return handler.resolve(clonedRequest);
                }
              } catch (_) {
                await storage.clearTokens();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}
