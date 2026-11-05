import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';

/// 进前台 + 定时拉取 /users/me，同步绑定状态到 UI。
class SessionSync extends ConsumerStatefulWidget {
  const SessionSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionSync> createState() => _SessionSyncState();
}

class _SessionSyncState extends ConsumerState<SessionSync>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _sync());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync();
    }
  }

  Future<void> _sync() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isLoggedIn || !auth.bootstrapped) return;
    try {
      await ref.read(authControllerProvider.notifier).refreshMe();
    } catch (_) {
      // 休眠唤醒失败时静默；用户操作时会再试
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
