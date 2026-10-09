import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'task_model.dart';

class TaskStorage {
  static const _fileName = 'ims_tasks.dat';
  static const _prefix = 'IMSENC:';

  // مفتاح مركب - صعب يتحلل
  static const _k1 = 'ims_2024_v3_sec';
  static const _k2 = 'xK9pZm4WqL8vN2bR';

  static String get _key => '$_k1$_k2${_k2.length}${_k1.length}';

  static String _encrypt(String plain) {
    final bytes = utf8.encode(plain);
    final keyBytes = utf8.encode(_key);
    final out = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      out.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return '$_prefix${base64.encode(out)}';
  }

  static String? _decrypt(String enc) {
    try {
      if (!enc.startsWith(_prefix)) return null;
      final body = enc.substring(_prefix.length);
      final bytes = base64.decode(body);
      final keyBytes = utf8.encode(_key);
      final out = <int>[];
      for (int i = 0; i < bytes.length; i++) {
        out.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      return utf8.decode(out);
    } catch (_) { return null; }
  }

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<File?> _legacyFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/ims_tasks.json');
      if (await f.exists()) return f;
    } catch (_) {}
    return null;
  }

  static Future<List<Task>> loadAll() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final raw = await f.readAsString();
        if (raw.trim().isEmpty) return [];
        final decrypted = _decrypt(raw);
        if (decrypted != null && decrypted.trim().isNotEmpty) {
          final data = jsonDecode(decrypted) as List;
          return data.map((e) => Task.fromJson(Map<String, dynamic>.from(e))).toList();
        }
      }

      // توافق مع الملف القديم (غير مشفر)
      final legacy = await _legacyFile();
      if (legacy != null) {
        final raw = await legacy.readAsString();
        if (raw.trim().isNotEmpty) {
          final data = jsonDecode(raw) as List;
          final tasks = data.map((e) => Task.fromJson(Map<String, dynamic>.from(e))).toList();
          // احفظها مشفرة
          await saveAll(tasks);
          // امسح القديم
          try { await legacy.delete(); } catch (_) {}
          return tasks;
        }
      }
      return [];
    } catch (_) { return []; }
  }

  static Future<void> saveAll(List<Task> tasks) async {
    final f = await _file();
    final raw = jsonEncode(tasks.map((t) => t.toJson()).toList());
    final encrypted = _encrypt(raw);
    await f.writeAsString(encrypted, flush: true);
  }

  static Future<void> upsert(Task task) async {
    final all = await loadAll();
    final idx = all.indexWhere((t) => t.id == task.id);
    if (idx >= 0) all[idx] = task;
    else all.add(task);
    await saveAll(all);
  }

  static Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((t) => t.id == id);
    await saveAll(all);
  }
}