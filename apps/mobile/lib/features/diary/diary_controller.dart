import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import '../../core/api_client.dart';
import '../auth/auth_controller.dart';

final diaryControllerProvider =
    StateNotifierProvider<DiaryController, DiaryState>((ref) {
  return DiaryController(ref);
});

class DiaryState {
  const DiaryState({
    this.items = const [],
    this.loading = false,
    this.error,
  });

  final List<Map<String, dynamic>> items;
  final bool loading;
  final String? error;

  DiaryState copyWith({
    List<Map<String, dynamic>>? items,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return DiaryState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DiaryController extends StateNotifier<DiaryState> {
  DiaryController(this._ref) : super(const DiaryState());

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await _api.get('/diary');
      final raw = res['items'];
      final items = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      state = state.copyWith(items: items, loading: false);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> create({
    required String text,
    required String visibility,
    String? title,
    List<File> files = const [],
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final created = await _api.post(
        '/diary',
        auth: true,
        body: {
          'text': text,
          'visibility': visibility,
          if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        },
      );
      var entry = Map<String, dynamic>.from(created);
      if (files.isNotEmpty) {
        entry = await _uploadMedia(entry['id'].toString(), files);
      }
      await refresh();
      return entry;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return null;
    }
  }

  MediaType _guessMediaType(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.png':
        return MediaType('image', 'png');
      case '.gif':
        return MediaType('image', 'gif');
      case '.webp':
        return MediaType('image', 'webp');
      case '.m4a':
        return MediaType('audio', 'mp4');
      case '.aac':
        return MediaType('audio', 'aac');
      case '.mp3':
        return MediaType('audio', 'mpeg');
      case '.wav':
        return MediaType('audio', 'wav');
      case '.jpg':
      case '.jpeg':
      default:
        if (ext == '.m4a' || ext == '.aac' || ext == '.mp3') {
          return MediaType('audio', 'mp4');
        }
        return MediaType('image', 'jpeg');
    }
  }

  Future<Map<String, dynamic>> _uploadMedia(String id, List<File> files) async {
    final parts = <http.MultipartFile>[];
    for (final f in files) {
      final name = p.basename(f.path);
      parts.add(
        await http.MultipartFile.fromPath(
          'files',
          f.path,
          filename: name,
          contentType: _guessMediaType(f.path),
        ),
      );
    }
    final res = await _api.uploadFiles('/diary/$id/media', files: parts);
    return Map<String, dynamic>.from(res);
  }

  Future<bool> share(String id) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _api.post('/diary/$id/share', auth: true);
      await refresh();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> append(String id, String text) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _api.post('/diary/$id/append', auth: true, body: {'text': text});
      await refresh();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>?> getOne(String id) async {
    try {
      final res = await _api.get('/diary/$id');
      return Map<String, dynamic>.from(res);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}
