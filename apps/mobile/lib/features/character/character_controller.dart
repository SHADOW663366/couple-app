import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/auth_controller.dart';

final characterControllerProvider =
    StateNotifierProvider<CharacterController, CharacterState>((ref) {
  return CharacterController(ref);
});

class CharacterState {
  const CharacterState({
    this.presets = const [],
    this.character,
    this.loading = false,
    this.error,
  });

  final List<Map<String, dynamic>> presets;
  final Map<String, dynamic>? character;
  final bool loading;
  final String? error;

  CharacterState copyWith({
    List<Map<String, dynamic>>? presets,
    Map<String, dynamic>? character,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearCharacter = false,
  }) {
    return CharacterState(
      presets: presets ?? this.presets,
      character: clearCharacter ? null : (character ?? this.character),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CharacterController extends StateNotifier<CharacterState> {
  CharacterController(this._ref) : super(const CharacterState());

  final Ref _ref;
  ApiClient get _api => _ref.read(apiClientProvider);

  Future<void> bootstrap() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final presetsRes = await _api.get('/characters/presets');
      final meRes = await _api.get('/characters/me');
      final raw = presetsRes['items'];
      final presets = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      final c = meRes['character'];
      state = state.copyWith(
        presets: presets,
        character: c is Map ? Map<String, dynamic>.from(c) : null,
        loading: false,
        clearCharacter: c == null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> create(String artKey, {String? name}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final created = await _api.post(
        '/characters',
        auth: true,
        body: {
          'artKey': artKey,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
      );
      state = state.copyWith(
        character: Map<String, dynamic>.from(created),
        loading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }
}
