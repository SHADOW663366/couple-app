import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'truth_controller.dart';

class TruthPage extends ConsumerStatefulWidget {
  const TruthPage({super.key});

  @override
  ConsumerState<TruthPage> createState() => _TruthPageState();
}

class _TruthPageState extends ConsumerState<TruthPage> {
  final _answer = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(truthControllerProvider.notifier).bootstrap());
  }

  @override
  void deactivate() {
    ref.read(truthControllerProvider.notifier).stopPolling();
    super.deactivate();
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final truth = ref.watch(truthControllerProvider);
    final bound = auth.user?['bound'] == true || auth.user?['pairId'] != null;
    final session = truth.session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('真心话'),
        actions: [
          if (session != null)
            TextButton(
              onPressed: truth.loading
                  ? null
                  : () => ref.read(truthControllerProvider.notifier).end(),
              child: const Text('结束本局'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            bound ? '可单人练习，也可双人轮流作答' : '未绑定仅可单人练习；绑定后解锁双人模式',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          if (session == null) ...[
            FilledButton(
              onPressed: truth.loading
                  ? null
                  : () => ref.read(truthControllerProvider.notifier).start('solo'),
              child: const Text('开始单人练习'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: (!bound || truth.loading)
                  ? null
                  : () => ref.read(truthControllerProvider.notifier).start('duo'),
              child: Text(bound ? '开始双人真心话' : '双人模式（需先绑定）'),
            ),
          ] else ...[
            _SessionCard(session: session),
            const SizedBox(height: 16),
            if (session['waitingDraw'] == true)
              FilledButton(
                onPressed: truth.loading
                    ? null
                    : () => ref.read(truthControllerProvider.notifier).draw(),
                child: const Text('抽一道题'),
              ),
            if (session['waitingAnswer'] == true) ...[
              Text(
                session['currentPrompt']?.toString() ?? '',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _answer,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '写下你的回答',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: truth.loading
                    ? null
                    : () async {
                        await ref
                            .read(truthControllerProvider.notifier)
                            .answer(_answer.text);
                        _answer.clear();
                      },
                child: const Text('提交回答'),
              ),
            ],
            if (session['myTurn'] != true)
              Text(
                '等待 ${session['currentTurnNickname'] ?? '对方'} 操作…',
                style: const TextStyle(color: Colors.black54),
              ),
          ],
          if (truth.message != null) ...[
            const SizedBox(height: 12),
            Text(truth.message!, style: const TextStyle(color: Colors.green)),
          ],
          if (truth.error != null) ...[
            const SizedBox(height: 12),
            Text(truth.error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 28),
          Text(
            '我们的回忆',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          if (truth.memories.isEmpty)
            const Text('还没有记录，去答一题吧', style: TextStyle(color: Colors.black54)),
          ...truth.memories.map((raw) {
            final m = raw as Map<String, dynamic>;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(m['prompt']?.toString() ?? ''),
              subtitle: Text(
                '${m['answererNickname']}: ${m['answer']}',
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final mode = session['mode'] == 'duo' ? '双人' : '单人';
    final turn = session['currentTurnNickname']?.toString() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$mode模式 · 当前回合：$turn'),
            if (session['currentPrompt'] != null) ...[
              const SizedBox(height: 8),
              Text(
                session['currentPrompt'].toString(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
