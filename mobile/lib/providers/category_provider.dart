import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_endpoints.dart';
import '../models/category.dart';
import 'auth_provider.dart';

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final auth = ref.watch(authProvider);

  if (!auth.isAuthenticated) {
    return [];
  }

  final response = await apiClient.dio.get(ApiEndpoints.categories);
  if (response.statusCode == 200) {
    final list = response.data as List;
    return list.map((item) => CategoryModel.fromJson(item)).toList();
  }
  return [];
});
