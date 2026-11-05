import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../auth/auth_controller.dart';
import 'diary_controller.dart';

class DiaryPage extends ConsumerStatefulWidget {
  const DiaryPage({super.key});

  @override
  ConsumerState<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(diaryControllerProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final diary = ref.watch(diaryControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final myId = auth.user?['id']?.toString();
    final bound = auth.user?['bound'] == true || auth.user?['pairId'] != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('日记'),
        actions: [
          IconButton(
            onPressed: diary.loading
                ? null
                : () => ref.read(diaryControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposer(context, bound: bound),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('写日记'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(diaryControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(
              bound
                  ? '个人日记可分享给对方；也可写共同日记一起追加'
                  : '未绑定仅可写个人私密日记；绑定后可分享与共同写',
              style: const TextStyle(color: Colors.black54),
            ),
            if (diary.error != null) ...[
              const SizedBox(height: 12),
              Text(diary.error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            if (diary.loading && diary.items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (diary.items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Text('还没有日记，写一篇吧')),
              )
            else
              ...diary.items.map(
                (e) => _DiaryCard(
                  entry: e,
                  myId: myId,
                  onOpen: () => _openDetail(context, e['id'].toString()),
                  onShare: e['visibility'] == 'private' &&
                          e['authorId']?.toString() == myId &&
                          bound
                      ? () async {
                          final ok = await ref
                              .read(diaryControllerProvider.notifier)
                              .share(e['id'].toString());
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已分享给对方')),
                            );
                          }
                        }
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openComposer(BuildContext context, {required bool bound}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DiaryComposerPage(bound: bound)),
    );
    if (result == true && mounted) {
      await ref.read(diaryControllerProvider.notifier).refresh();
    }
  }

  Future<void> _openDetail(BuildContext context, String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DiaryDetailPage(entryId: id)),
    );
    if (mounted) {
      await ref.read(diaryControllerProvider.notifier).refresh();
    }
  }
}

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({
    required this.entry,
    required this.myId,
    required this.onOpen,
    this.onShare,
  });

  final Map<String, dynamic> entry;
  final String? myId;
  final VoidCallback onOpen;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final visibility = entry['visibility']?.toString() ?? 'private';
    final title = entry['title']?.toString();
    final text = entry['text']?.toString() ?? '';
    final media = entry['media'] is List ? entry['media'] as List : const [];
    final label = switch (visibility) {
      'shared' => '已分享',
      'joint' => '共同日记',
      _ => '私密',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(label),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  const Spacer(),
                  if (onShare != null)
                    TextButton(onPressed: onShare, child: const Text('分享给对方')),
                ],
              ),
              if (title != null && title.isNotEmpty)
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (media.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '附件 ${media.length} 个',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DiaryComposerPage extends ConsumerStatefulWidget {
  const DiaryComposerPage({super.key, required this.bound});

  final bool bound;

  @override
  ConsumerState<DiaryComposerPage> createState() => _DiaryComposerPageState();
}

class _DiaryComposerPageState extends ConsumerState<DiaryComposerPage> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  final _recorder = AudioRecorder();
  String _visibility = 'private';
  final List<File> _files = [];
  bool _recording = false;
  String? _recordingPath;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (x == null) return;
    setState(() => _files.add(File(x.path)));
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        if (path != null) _files.add(File(path));
      });
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能录音')),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/diary_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    setState(() {
      _recording = true;
      _recordingPath = path;
    });
  }

  Future<void> _submit() async {
    if (_text.text.trim().isEmpty && _files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请写点文字或添加图片/语音')),
      );
      return;
    }
    final entry = await ref.read(diaryControllerProvider.notifier).create(
          text: _text.text,
          visibility: _visibility,
          title: _title.text,
          files: List<File>.from(_files),
        );
    if (!mounted) return;
    if (entry != null) {
      Navigator.of(context).pop(true);
    } else {
      final err = ref.read(diaryControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? '保存失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(diaryControllerProvider).loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('写日记'),
        actions: [
          TextButton(
            onPressed: loading ? null : _submit,
            child: const Text('发布'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: [
              const ButtonSegment(value: 'private', label: Text('私密')),
              ButtonSegment(
                value: 'shared',
                label: const Text('分享给对方'),
                enabled: widget.bound,
              ),
              ButtonSegment(
                value: 'joint',
                label: const Text('共同日记'),
                enabled: widget.bound,
              ),
            ],
            selected: {_visibility},
            onSelectionChanged: (s) => setState(() => _visibility = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: '标题（可选）',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '今天想写点什么',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: loading ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('图片'),
              ),
              OutlinedButton.icon(
                onPressed: loading ? null : _toggleRecord,
                icon: Icon(_recording ? Icons.stop : Icons.mic_none),
                label: Text(_recording ? '停止录音' : '语音'),
              ),
            ],
          ),
          if (_recordingPath != null && _recording)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('录音中…', style: TextStyle(color: Colors.red)),
            ),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._files.asMap().entries.map((e) {
              final name = e.value.path.split(RegExp(r'[\\/]')).last;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  name.toLowerCase().endsWith('.m4a') ||
                          name.toLowerCase().endsWith('.aac')
                      ? Icons.audiotrack
                      : Icons.image,
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _files.removeAt(e.key)),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class DiaryDetailPage extends ConsumerStatefulWidget {
  const DiaryDetailPage({super.key, required this.entryId});

  final String entryId;

  @override
  ConsumerState<DiaryDetailPage> createState() => _DiaryDetailPageState();
}

class _DiaryDetailPageState extends ConsumerState<DiaryDetailPage> {
  Map<String, dynamic>? _entry;
  bool _loading = true;
  String? _error;
  final _append = TextEditingController();
  final _player = AudioPlayer();
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _append.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final entry =
        await ref.read(diaryControllerProvider.notifier).getOne(widget.entryId);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _loading = false;
      _error = entry == null ? (ref.read(diaryControllerProvider).error ?? '加载失败') : null;
    });
  }

  Future<void> _play(String mediaId, String urlPath) async {
    if (_playingId == mediaId) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    final api = ref.read(apiClientProvider);
    final bytes = await api.getBytes(urlPath);
    await _player.play(
      BytesSource(Uint8List.fromList(bytes), mimeType: 'audio/mp4'),
    );
    setState(() => _playingId = mediaId);
  }

  Future<void> _submitAppend() async {
    final text = _append.text.trim();
    if (text.isEmpty) return;
    final ok = await ref
        .read(diaryControllerProvider.notifier)
        .append(widget.entryId, text);
    if (!mounted) return;
    if (ok) {
      _append.clear();
      await _load();
    } else {
      final err = ref.read(diaryControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? '追加失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final myId = auth.user?['id']?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('日记详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(myId),
    );
  }

  Widget _buildBody(String? myId) {
    final entry = _entry!;
    final visibility = entry['visibility']?.toString() ?? 'private';
    final media = entry['media'] is List ? entry['media'] as List : const [];
    final blocks = entry['blocks'] is List ? entry['blocks'] as List : const [];
    final title = entry['title']?.toString();
    final text = entry['text']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          switch (visibility) {
            'shared' => '已分享给对方',
            'joint' => '共同日记',
            _ => '私密日记',
          },
          style: const TextStyle(color: Colors.black54),
        ),
        if (title != null && title.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ],
        if (visibility != 'joint' && text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ],
        if (visibility == 'joint') ...[
          const SizedBox(height: 16),
          ...blocks.map((b) {
            final map = Map<String, dynamic>.from(b as Map);
            final mine = map['authorId']?.toString() == myId;
            return Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: mine
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(map['text']?.toString() ?? ''),
              ),
            );
          }),
          const SizedBox(height: 8),
          TextField(
            controller: _append,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '追加一句',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: ref.watch(diaryControllerProvider).loading
                ? null
                : _submitAppend,
            child: const Text('追加'),
          ),
        ],
        if (media.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('附件', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...media.map((m) {
            final map = Map<String, dynamic>.from(m as Map);
            final kind = map['kind']?.toString();
            final id = map['id']?.toString() ?? '';
            final url = map['url']?.toString() ?? '/diary/media/$id';
            if (kind == 'image') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _AuthImage(path: url),
                ),
              );
            }
            final playing = _playingId == id;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(playing ? Icons.stop_circle : Icons.play_circle),
              title: const Text('语音'),
              onTap: () async {
                try {
                  await _play(id, url);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('播放失败：$e')),
                    );
                  }
                }
              },
            );
          }),
        ],
      ],
    );
  }
}

class _AuthImage extends ConsumerStatefulWidget {
  const _AuthImage({required this.path});

  final String path;

  @override
  ConsumerState<_AuthImage> createState() => _AuthImageState();
}

class _AuthImageState extends ConsumerState<_AuthImage> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await ref.read(apiClientProvider).getBytes(widget.path);
      if (!mounted) return;
      setState(() => _bytes = Uint8List.fromList(bytes));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '图片加载失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(_error!, style: const TextStyle(color: Colors.black54)),
      );
    }
    if (_bytes == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Image.memory(_bytes!, fit: BoxFit.cover);
  }
}
