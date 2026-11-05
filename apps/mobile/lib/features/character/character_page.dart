import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'character_controller.dart';

class CharacterPage extends ConsumerStatefulWidget {
  const CharacterPage({super.key});

  @override
  ConsumerState<CharacterPage> createState() => _CharacterPageState();
}

class _CharacterPageState extends ConsumerState<CharacterPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(characterControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(characterControllerProvider);
    final character = state.character;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 角色')),
      body: state.loading && character == null && state.presets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(state.error!, style: const TextStyle(color: Colors.red)),
                  ),
                if (character != null) ...[
                  Text(
                    '你的角色',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            character['name']?.toString() ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            character['style']?.toString() ?? '',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          if (character['tags'] is List) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              children: (character['tags'] as List)
                                  .map(
                                    (t) => Chip(
                                      label: Text(t.toString()),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => context.push('/chat'),
                            child: const Text('开始聊天'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const Text(
                    '选一个二次元陪伴角色（每人一个，后续可扩展）',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ...state.presets.map((p) {
                    final tags = p['tags'] is List ? p['tags'] as List : const [];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          p['name']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${p['style'] ?? ''}\n${tags.map((e) => e.toString()).join(' · ')}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: state.loading
                            ? null
                            : () async {
                                final ok = await ref
                                    .read(characterControllerProvider.notifier)
                                    .create(p['artKey'].toString());
                                if (!context.mounted) return;
                                if (ok) {
                                  context.push('/chat');
                                } else {
                                  final err =
                                      ref.read(characterControllerProvider).error;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err ?? '创建失败')),
                                  );
                                }
                              },
                      ),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}
