import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'task_model.dart';

class TaskStorage {
  static const _fileName = 'ims_tasks.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<List<Task>> loadAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return [];
      final data = jsonDecode(raw) as List;
      return data
          .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<Task> tasks) async {
    final f = await _file();
    final raw = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await f.writeAsString(raw, flush: true);
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
}