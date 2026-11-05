import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final bound = user?['bound'] == true || user?['pairId'] != null;
    final nickname = user?['nickname']?.toString() ?? '旅人';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Couple'),
        actions: [
          IconButton(
            tooltip: '退出登录',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '你好，$nickname',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            bound ? '双人模式已开启 · 可一起玩真心话与共同日记' : '当前为单人模式 · 绑定后解锁双人玩法',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          _FeatureTile(
            title: '情侣绑定',
            subtitle: bound ? '查看伴侣 / 解除绑定' : '邀请码绑定对方',
            icon: Icons.favorite_outline,
            onTap: () => context.push('/pair'),
          ),
          _FeatureTile(
            title: 'AI 角色',
            subtitle: '二次元陪伴（M3 接入）',
            icon: Icons.smart_toy_outlined,
            onTap: () => _soon(context),
          ),
          _FeatureTile(
            title: '真心话',
            subtitle: bound ? '双人轮流问答' : '单人练习题库',
            icon: Icons.question_answer_outlined,
            onTap: () => context.push('/truth'),
          ),
          _FeatureTile(
            title: '日记',
            subtitle: '分享 / 共同日记 · 图与语音',
            icon: Icons.menu_book_outlined,
            onTap: () => _soon(context),
          ),
        ],
      ),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('下一里程碑实现，骨架已预留入口')),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
