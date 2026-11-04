import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  bool _registerMode = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (_registerMode) {
        await auth.register(
          _email.text.trim(),
          _password.text,
          _nickname.text.trim(),
        );
      } else {
        await auth.login(_email.text.trim(), _password.text);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            Text(
              'Couple',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _registerMode ? '创建账号，开始你们的空间' : '登录后进入单人 / 双人模式',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '邮箱'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码（至少 6 位）'),
            ),
            if (_registerMode) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _nickname,
                decoration: const InputDecoration(labelText: '昵称'),
              ),
            ],
            if (auth.error != null) ...[
              const SizedBox(height: 12),
              Text(auth.error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: auth.loading ? null : _submit,
              child: Text(auth.loading
                  ? '请稍候…'
                  : (_registerMode ? '注册' : '登录')),
            ),
            TextButton(
              onPressed: () => setState(() => _registerMode = !_registerMode),
              child: Text(_registerMode ? '已有账号？去登录' : '没有账号？注册'),
            ),
          ],
        ),
      ),
    );
  }
}
