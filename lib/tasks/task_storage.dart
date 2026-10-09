import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'task_model.dart';

class TaskStorage {
  static const _fileName = 'ims_tasks.dat';
  static const _prefix = 'IMSENC:';

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
    } catch (_) {
      return null;
    }
  }

  /// ⭐ مجلد ثابت في Downloads — بيفضل حتى لو التطبيق اتمسح
  static Future<Directory?> _persistentDir() async {
    if (!Platform.isAndroid) return null;
    for (final p in [
      '/storage/emulated/0/Download/ims',
      '/sdcard/Download/ims',
      '/storage/emulated/0/Downloads/ims',
    ]) {
      try {
        final d = Directory(p);
        if (!await d.exists()) {
          try {
            await d.create(recursive: true);
          } catch (_) {}
        }
        if (await d.exists()) {
          final test = File('${d.path}/.test');
          try {
            await test.writeAsString('x');
            await test.delete();
            return d;
          } catch (_) {}
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<File?> _persistentFile() async {
    final dir = await _persistentDir();
    if (dir == null) return null;
    return File('${dir.path}/$_fileName');
  }

  /// ملف داخلي احتياطي
  static Future<File> _internalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<File?> _legacyJson() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/ims_tasks.json');
      if (await f.exists()) return f;
    } catch (_) {}
    return null;
  }

  static Future<List<Task>> loadAll() async {
    // 1) جرّب الملف الثابت في Downloads
    try {
      final pf = await _persistentFile();
      if (pf != null && await pf.exists()) {
        final raw = await pf.readAsString();
        if (raw.trim().isNotEmpty) {
          final decrypted = _decrypt(raw);
          if (decrypted != null && decrypted.trim().isNotEmpty) {
            final data = jsonDecode(decrypted) as List;
            return data
                .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
        }
      }
    } catch (_) {}

    // 2) جرّب الملف الداخلي (نسخة قديمة)
    try {
      final f = await _internalFile();
      if (await f.exists()) {
        final raw = await f.readAsString();
        if (raw.trim().isNotEmpty) {
          final decrypted = _decrypt(raw);
          if (decrypted != null && decrypted.trim().isNotEmpty) {
            final data = jsonDecode(decrypted) as List;
            final tasks = data
                .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            // ننقلهم للـ Downloads
            await saveAll(tasks);
            return tasks;
          }
        }
      }
    } catch (_) {}

    // 3) جرّب JSON القديم (بدون تشفير)
    try {
      final legacy = await _legacyJson();
      if (legacy != null) {
        final raw = await legacy.readAsString();
        if (raw.trim().isNotEmpty) {
          final data = jsonDecode(raw) as List;
          final tasks = data
              .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          await saveAll(tasks);
          try {
            await legacy.delete();
          } catch (_) {}
          return tasks;
        }
      }
    } catch (_) {}

    return [];
  }

  static Future<void> saveAll(List<Task> tasks) async {
    final raw = jsonEncode(tasks.map((t) => t.toJson()).toList());
    final encrypted = _encrypt(raw);

    // 1) احفظ في Downloads (الأساسي)
    try {
      final pf = await _persistentFile();
      if (pf != null) {
        await pf.writeAsString(encrypted, flush: true);
      }
    } catch (_) {}

    // 2) احفظ نسخة داخلية (احتياطي)
    try {
      final f = await _internalFile();
      await f.writeAsString(encrypted, flush: true);
    } catch (_) {}
  }

  static Future<void> upsert(Task task) async {
    final all = await loadAll();
    final idx = all.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      all[idx] = task;
    } else {
      all.add(task);
    }
    await saveAll(all);
  }

  static Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((t) => t.id == id);
    await saveAll(all);
  }

  /// مسار الملف الفعلي (للعرض في الإعدادات)
  static Future<String> storagePath() async {
    final pf = await _persistentFile();
    return pf?.path ?? 'مش متاح';
  }
}