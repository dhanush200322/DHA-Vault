import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../models/document_share.dart';
import 'auth_provider.dart';

class SharesState {
  final bool isLoading;
  final List<DocumentShareModel> outgoingShares;
  final List<DocumentShareModel> incomingShares;
  final String? errorMessage;
  final Map<String, dynamic>? openedShareData;

  SharesState({
    this.isLoading = false,
    this.outgoingShares = const [],
    this.incomingShares = const [],
    this.errorMessage,
    this.openedShareData,
  });

  SharesState copyWith({
    bool? isLoading,
    List<DocumentShareModel>? outgoingShares,
    List<DocumentShareModel>? incomingShares,
    String? errorMessage,
    Map<String, dynamic>? openedShareData,
  }) {
    return SharesState(
      isLoading: isLoading ?? this.isLoading,
      outgoingShares: outgoingShares ?? this.outgoingShares,
      incomingShares: incomingShares ?? this.incomingShares,
      errorMessage: errorMessage,
      openedShareData: openedShareData,
    );
  }
}

class SharesNotifier extends StateNotifier<SharesState> {
  final ApiClient _client;

  SharesNotifier(this._client) : super(SharesState()) {
    fetchShares();
  }

  Future<void> fetchShares() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final outRes = await _client.dio.get('/shares/outgoing');
      final inRes = await _client.dio.get('/shares/incoming');

      if (outRes.statusCode == 200 && inRes.statusCode == 200) {
        final outgoing = (outRes.data as List)
            .map((item) => DocumentShareModel.fromJson(item as Map<String, dynamic>))
            .toList();
        final incoming = (inRes.data as List)
            .map((item) => DocumentShareModel.fromJson(item as Map<String, dynamic>))
            .toList();

        state = state.copyWith(
          isLoading: false,
          outgoingShares: outgoing,
          incomingShares: incoming,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load shares');
    }
  }

  Future<bool> createUserShare({
    required String documentId,
    required String recipientEmail,
    List<String> permissions = const ['VIEW', 'DOWNLOAD'],
    int? expiresInHours,
    int? maxViews,
    bool allowDownload = true,
    String? watermarkText,
  }) async {
    try {
      final res = await _client.dio.post('/shares/user', data: {
        'documentId': documentId,
        'recipientEmail': recipientEmail,
        'permissions': permissions,
        if (expiresInHours != null) 'expiresInHours': expiresInHours,
        if (maxViews != null) 'maxViews': maxViews,
        'allowDownload': allowDownload,
        if (watermarkText != null && watermarkText.isNotEmpty) 'watermarkText': watermarkText,
      });

      if (res.statusCode == 201) {
        await fetchShares();
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to create secure user share');
    }
    return false;
  }

  Future<Map<String, dynamic>?> openShare(String shareId) async {
    try {
      final res = await _client.dio.post('/shares/$shareId/open');
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        state = state.copyWith(openedShareData: data);
        await fetchShares();
        return data;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Cannot open share (expired, view limit, or revoked)');
    }
    return null;
  }

  Future<bool> revokeShare(String shareId) async {
    try {
      final res = await _client.dio.post('/shares/$shareId/revoke');
      if (res.statusCode == 200) {
        await fetchShares();
        return true;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to revoke share');
    }
    return false;
  }
}

final sharesProvider = StateNotifierProvider<SharesNotifier, SharesState>((ref) {
  final client = ref.watch(apiClientProvider);
  return SharesNotifier(client);
});
