import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'pair_controller.dart';

class PairPage extends ConsumerStatefulWidget {
  const PairPage({super.key});

  @override
  ConsumerState<PairPage> createState() => _PairPageState();
}

class _PairPageState extends ConsumerState<PairPage> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(authControllerProvider.notifier).refreshMe();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final pair = ref.watch(pairControllerProvider);
    final bound = auth.user?['bound'] == true || auth.user?['pairId'] != null;
    final partner = auth.user?['partner'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: const Text('情侣绑定')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (bound) ...[
            Text(
              '已与 ${partner?['nickname'] ?? '伴侣'} 绑定',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(partner?['email']?.toString() ?? '',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: pair.loading
                  ? null
                  : () => ref.read(pairControllerProvider.notifier).unbind(),
              child: const Text('解除绑定'),
            ),
          ] else ...[
            Text(
              '未绑定 · 仅可单人模式',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              '生成邀请码发给对方，或输入对方的邀请码完成绑定。',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: pair.loading
                  ? null
                  : () =>
                      ref.read(pairControllerProvider.notifier).createInvite(),
              child: const Text('生成邀请码'),
            ),
            if (pair.inviteCode != null) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: Text(
                    pair.inviteCode!,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  subtitle: Text(pair.qrPayload ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pair.inviteCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制邀请码')),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: '输入对方邀请码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: pair.loading
                  ? null
                  : () => ref
                      .read(pairControllerProvider.notifier)
                      .accept(_code.text),
              child: const Text('确认绑定'),
            ),
          ],
          if (pair.message != null) ...[
            const SizedBox(height: 16),
            Text(pair.message!, style: const TextStyle(color: Colors.green)),
          ],
          if (pair.error != null) ...[
            const SizedBox(height: 16),
            Text(pair.error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
