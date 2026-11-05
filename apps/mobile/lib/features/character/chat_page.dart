import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(chatControllerProvider.notifier).openSelf();
      _jumpBottom();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    final ok = await ref.read(chatControllerProvider.notifier).send(text);
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(chatControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? '发送失败')),
      );
      return;
    }
    _jumpBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final name = chat.character?['name']?.toString() ?? 'AI';
    final modeLabel = chat.aiMode == 'deepseek' ? 'DeepSeek' : '本地陪伴';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                modeLabel,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (chat.error != null && chat.sessionId == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(chat.error!, textAlign: TextAlign.center),
                ),
              ),
            )
          else ...[
            if (chat.loading)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: chat.messages.length,
                itemBuilder: (context, index) {
                  final m = chat.messages[index];
                  final mine = m['sender']?.toString() == 'user';
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: mine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : const Color(0xFFF1F3F2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(m['content']?.toString() ?? ''),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !chat.sending && chat.sessionId != null,
                        decoration: const InputDecoration(
                          hintText: '跟角色说点什么…',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: chat.sending || chat.sessionId == null
                          ? null
                          : _send,
                      icon: chat.sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
