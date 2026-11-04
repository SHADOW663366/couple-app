import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

final pairControllerProvider =
    StateNotifierProvider<PairController, PairState>((ref) {
  return PairController(ref);
});

class PairState {
  const PairState({
    this.inviteCode,
    this.qrPayload,
    this.expiresAt,
    this.loading = false,
    this.message,
    this.error,
  });

  final String? inviteCode;
  final String? qrPayload;
  final String? expiresAt;
  final bool loading;
  final String? message;
  final String? error;

  PairState copyWith({
    String? inviteCode,
    String? qrPayload,
    String? expiresAt,
    bool? loading,
    String? message,
    String? error,
    bool clearFeedback = false,
  }) {
    return PairState(
      inviteCode: inviteCode ?? this.inviteCode,
      qrPayload: qrPayload ?? this.qrPayload,
      expiresAt: expiresAt ?? this.expiresAt,
      loading: loading ?? this.loading,
      message: clearFeedback ? null : (message ?? this.message),
      error: clearFeedback ? null : (error ?? this.error),
    );
  }
}

class PairController extends StateNotifier<PairState> {
  PairController(this._ref) : super(const PairState());

  final Ref _ref;

  Future<void> createInvite() async {
    state = state.copyWith(loading: true, clearFeedback: true);
    try {
      final api = _ref.read(apiClientProvider);
      final data = await api.post('/pair/invite', auth: true);
      state = state.copyWith(
        loading: false,
        inviteCode: data['code'] as String?,
        qrPayload: data['qrPayload'] as String?,
        expiresAt: data['expiresAt']?.toString(),
        message: '邀请码已生成',
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> accept(String code) async {
    state = state.copyWith(loading: true, clearFeedback: true);
    try {
      final api = _ref.read(apiClientProvider);
      final data = await api.post(
        '/pair/accept',
        body: {'code': code.trim().toUpperCase()},
        auth: true,
      );
      await _ref.read(authControllerProvider.notifier).refreshMe();
      state = state.copyWith(
        loading: false,
        message: data['message']?.toString() ?? '绑定成功',
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> unbind() async {
    state = state.copyWith(loading: true, clearFeedback: true);
    try {
      final api = _ref.read(apiClientProvider);
      final data = await api.post('/pair/unbind', auth: true);
      await _ref.read(authControllerProvider.notifier).refreshMe();
      state = state.copyWith(
        loading: false,
        inviteCode: null,
        qrPayload: null,
        message: data['message']?.toString() ?? '已解绑',
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}
