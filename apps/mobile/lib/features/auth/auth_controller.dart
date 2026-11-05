import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(apiClientProvider));
});

class AuthState {
  const AuthState({
    this.token,
    this.user,
    this.loading = false,
    this.error,
    this.bootstrapped = false,
  });

  final String? token;
  final Map<String, dynamic>? user;
  final bool loading;
  final String? error;
  final bool bootstrapped;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  AuthState copyWith({
    String? token,
    Map<String, dynamic>? user,
    bool? loading,
    String? error,
    bool? bootstrapped,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return AuthState(
      token: clearSession ? null : (token ?? this.token),
      user: clearSession ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      bootstrapped: bootstrapped ?? this.bootstrapped,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._api) : super(const AuthState()) {
    bootstrap();
  }

  final ApiClient _api;
  static const _tokenKey = 'access_token';

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null && token.isNotEmpty) {
      _api.setToken(token);
      try {
        final me = await _api.get('/users/me');
        state = state.copyWith(
          token: token,
          user: me,
          bootstrapped: true,
          clearError: true,
        );
        return;
      } catch (_) {
        await prefs.remove(_tokenKey);
        _api.setToken(null);
      }
    }
    state = state.copyWith(bootstrapped: true, clearSession: true);
  }

  Future<void> register(String email, String password, String nickname) async {
    await _authenticate(
      () => _api.post(
        '/auth/register',
        body: {
          'email': email,
          'password': password,
          'nickname': nickname,
        },
      ),
    );
  }

  Future<void> login(String email, String password) async {
    await _authenticate(
      () => _api.post(
        '/auth/login',
        body: {'email': email, 'password': password},
      ),
    );
  }

  Future<void> refreshMe() async {
    final token = state.token;
    if (token == null || token.isEmpty) return;
    final me = await _api.get('/users/me');
    // 仅在绑定相关字段变化时更新，减少无意义 rebuild
    final prev = state.user;
    final changed = prev?['pairId'] != me['pairId'] ||
        prev?['bound'] != me['bound'] ||
        prev?['nickname'] != me['nickname'] ||
        (prev?['partner'] as Map?)?['id'] != (me['partner'] as Map?)?['id'];
    if (changed || prev == null) {
      state = state.copyWith(user: me, clearError: true);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _api.setToken(null);
    state = const AuthState(bootstrapped: true);
  }

  Future<void> _authenticate(Future<Map<String, dynamic>> Function() call) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = await call();
      final token = data['accessToken'] as String;
      final user = data['user'] as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      _api.setToken(token);
      state = state.copyWith(
        token: token,
        user: user,
        loading: false,
        bootstrapped: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      rethrow;
    }
  }
}
