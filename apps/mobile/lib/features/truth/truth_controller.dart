import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

final truthControllerProvider =
    StateNotifierProvider<TruthController, TruthState>((ref) {
  return TruthController(ref);
});

class TruthState {
  const TruthState({
    this.session,
    this.memories = const [],
    this.loading = false,
    this.error,
    this.message,
  });

  final Map<String, dynamic>? session;
  final List<dynamic> memories;
  final bool loading;
  final String? error;
  final String? message;

  TruthState copyWith({
    Map<String, dynamic>? session,
    List<dynamic>? memories,
    bool? loading,
    String? error,
    String? message,
    bool clearSession = false,
    bool clearFeedback = false,
  }) {
    return TruthState(
      session: clearSession ? null : (session ?? this.session),
      memories: memories ?? this.memories,
      loading: loading ?? this.loading,
      error: clearFeedback ? null : (error ?? this.error),
      message: clearFeedback ? null : (message ?? this.message),
    );
  }
}

class TruthController extends StateNotifier<TruthState> {
  TruthController(this._ref) : super(const TruthState());

  final Ref _ref;
  Timer? _poll;

  void startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      refreshActive(silent: true);
    });
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  Future<void> bootstrap() async {
    await Future.wait([refreshActive(), loadMemories()]);
    startPolling();
  }

  Future<void> refreshActive({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loading: true, clearFeedback: true);
    }
    try {
      final api = _ref.read(apiClientProvider);
      final data = await api.get('/truth/sessions/active');
      final session = data['session'] as Map<String, dynamic>?;
      state = state.copyWith(
        session: session,
        clearSession: session == null,
        loading: false,
      );
    } catch (e) {
      if (!silent) {
        state = state.copyWith(loading: false, error: e.toString());
      }
    }
  }

  Future<void> start(String mode) async {
    state = state.copyWith(loading: true, clearFeedback: true);
    try {
      final api = _ref.read(apiClientProvider);
      final session = await api.post(
        '/truth/sessions',
        body: {'mode': mode, 'level': 2},
        auth: true,
      );
      state = state.copyWith(
        session: session,
        loading: false,
        message: mode == 'duo' ? '双人真心话开始' : '单人练习开始',
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> draw() async {
    final id = state.session?['id']?.toString();
    if (id == null) return;
    state = state.copyWith(loading: true, clearFeedback: true);
    try {
      final api = _ref.read(apiClientProvider);
      final session = await api.post('/truth/sessions/$id/draw', auth: true);
      state = state.copyWith(session: session, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> answer(String text) async {
    final id = state.session?['id']?.toString();
    if (id == null) return;
    state = state.copyWith(loading: true, clearFeedback: true);
    try {
      final api = _ref.read(apiClientProvider);
      final session = await api.post(
        '/truth/sessions/$id/answer',
        body: {'answer': text},
        auth: true,
      );
      state = state.copyWith(
        session: session,
        loading: false,
        message: '已提交回答',
      );
      await loadMemories();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> end() async {
    final id = state.session?['id']?.toString();
    if (id == null) return;
    state = state.copyWith(loading: true, clearFeedback: true);
    try {
      final api = _ref.read(apiClientProvider);
      await api.post('/truth/sessions/$id/end', auth: true);
      state = state.copyWith(
        clearSession: true,
        loading: false,
        message: '本局已结束',
      );
      await loadMemories();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMemories() async {
    try {
      final api = _ref.read(apiClientProvider);
      final data = await api.get('/truth/memories?limit=30');
      state = state.copyWith(memories: data['items'] as List<dynamic>? ?? []);
    } catch (_) {}
  }
}
