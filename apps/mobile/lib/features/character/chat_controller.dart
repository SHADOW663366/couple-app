import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/auth_controller.dart';

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(ref);
});

class ChatState {
  const ChatState({
    this.sessionId,
    this.character,
    this.messages = const [],
    this.aiMode,
    this.loading = false,
    this.sending = false,
    this.error,
  });

  final String? sessionId;
  final Map<String, dynamic>? character;
  final List<Map<String, dynamic>> messages;
  final String? aiMode;
  final bool loading;
  final bool sending;
  final String? error;

  ChatState copyWith({
    String? sessionId,
    Map<String, dynamic>? character,
    List<Map<String, dynamic>>? messages,
    String? aiMode,
    bool? loading,
    bool? sending,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      sessionId: sessionId ?? this.sessionId,
      character: character ?? this.character,
      messages: messages ?? this.messages,
      aiMode: aiMode ?? this.aiMode,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref) : super(const ChatState());

  final Ref _ref;
  ApiClient get _api => _ref.read(apiClientProvider);

  Future<void> openSelf() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await _api.get('/chat/sessions/self');
      final session = res['session'] as Map<String, dynamic>?;
      final raw = res['messages'];
      final messages = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      state = state.copyWith(
        sessionId: session?['id']?.toString(),
        character: session?['character'] is Map
            ? Map<String, dynamic>.from(session!['character'] as Map)
            : null,
        aiMode: session?['aiMode']?.toString(),
        messages: messages,
        loading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> send(String content) async {
    final id = state.sessionId;
    if (id == null) return false;
    final text = content.trim();
    if (text.isEmpty) return false;

    state = state.copyWith(sending: true, clearError: true);
    try {
      final res = await _api.post(
        '/chat/sessions/$id/messages',
        auth: true,
        body: {'content': text},
      );
      final userMsg = Map<String, dynamic>.from(res['userMessage'] as Map);
      final aiMsg = Map<String, dynamic>.from(res['aiMessage'] as Map);
      state = state.copyWith(
        messages: [...state.messages, userMsg, aiMsg],
        aiMode: res['aiMode']?.toString() ?? state.aiMode,
        sending: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(sending: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(sending: false, error: e.toString());
      return false;
    }
  }
}
