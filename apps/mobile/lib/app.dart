import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/diary/diary_page.dart';
import 'features/home/home_page.dart';
import 'features/pair/pair_page.dart';
import 'features/truth/truth_page.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (_, __) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (!auth.bootstrapped) return null;
      final loggingIn = state.matchedLocation == '/login';
      if (!auth.isLoggedIn && !loggingIn) return '/login';
      if (auth.isLoggedIn && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/', builder: (_, __) => const HomePage()),
      GoRoute(path: '/pair', builder: (_, __) => const PairPage()),
      GoRoute(path: '/truth', builder: (_, __) => const TruthPage()),
      GoRoute(path: '/diary', builder: (_, __) => const DiaryPage()),
    ],
  );
});

class CoupleApp extends ConsumerWidget {
  const CoupleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'Couple',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6F5E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      routerConfig: router,
    );
  }
}
