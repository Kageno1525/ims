import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class CsvReader {
  /// بيرجع كل الأماكن المحتملة لمجلد ranges
  static Future<List<Directory>> _candidateDirs() async {
    final list = <Directory>[];
    if (Platform.isAndroid) {
      // 1) المسارات العامة (المستخدم شايفها)
      for (final p in [
        '/storage/emulated/0/Download/ranges',
        '/sdcard/Download/ranges',
        '/storage/emulated/0/Downloads/ranges',
      ]) {
        list.add(Directory(p));
      }
      // 2) مسار التطبيق الخارجي
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) list.add(Directory('${ext.path}/ranges'));
      } catch (_) {}
      // 3) Download من path_provider
      try {
        final dl = await getDownloadsDirectory();
        if (dl != null) list.add(Directory('${dl.path}/ranges'));
      } catch (_) {}
    }
    // 4) مجلد التطبيق الداخلي
    try {
      final app = await getApplicationDocumentsDirectory();
      list.add(Directory('${app.path}/ranges'));
    } catch (_) {}
    return list;
  }

  /// أول مجلد موجود فعلاً من المرشحين
  static Future<Directory?> getRangesDir({bool createIfMissing = false}) async {
    final candidates = await _candidateDirs();
    for (final d in candidates) {
      try {
        if (await d.exists()) return d;
      } catch (_) {}
    }
    if (createIfMissing && candidates.isNotEmpty) {
      try {
        await candidates.first.create(recursive: true);
        return candidates.first;
      } catch (_) {}
    }
    return null;
  }

  /// كل الملفات من كل المجلدات المحتملة
  static Future<List<CsvFile>> listFiles() async {
    final candidates = await _candidateDirs();
    final seen = <String>{};
    final files = <CsvFile>[];

    for (final dir in candidates) {
      try {
        if (!await dir.exists()) continue;
        await for (final ent in dir.list()) {
          if (ent is! File) continue;
          if (!ent.path.toLowerCase().endsWith('.csv')) continue;
          if (seen.contains(ent.path)) continue;
          seen.add(ent.path);
          try {
            final nums = await readColumnC(ent.path);
            final name = ent.path
                .split(Platform.pathSeparator)
                .last
                .replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
            files.add(CsvFile(name: name, path: ent.path, count: nums.length));
          } catch (_) {}
        }
      } catch (_) {}
    }
    files.sort((a, b) => a.name.compareTo(b.name));
    return files;
  }

  static Future<List<String>> readColumnC(String path) async {
    final file = File(path);
    if (!await file.exists()) return [];
    final bytes = await file.readAsBytes();
    String content;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      content = utf8.decode(bytes.sublist(3), allowMalformed: true);
    } else {
      content = utf8.decode(bytes, allowMalformed: true);
    }
    final rows = _parse(content);
    final numbers = <String>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) continue;
      final v = row[2].trim();
      if (v.isNotEmpty) numbers.add(v);
    }
    return numbers;
  }

  static List<List<String>> _parse(String content) {
    final rows = <List<String>>[];
    final fields = <String>[];
    final sb = StringBuffer();
    bool inQ = false;
    int i = 0;
    while (i < content.length) {
      final c = content[i];
      if (inQ) {
        if (c == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            sb.write('"');
            i += 2;
            continue;
          }
          inQ = false;
          i++;
          continue;
        }
        sb.write(c);
        i++;
      } else {
        if (c == '"') {
          inQ = true;
          i++;
        } else if (c == ',') {
          fields.add(sb.toString());
          sb.clear();
          i++;
        } else if (c == '\r') {
          i++;
        } else if (c == '\n') {
          fields.add(sb.toString());
          sb.clear();
          rows.add(List.of(fields));
          fields.clear();
          i++;
        } else {
          sb.write(c);
          i++;
        }
      }
    }
    if (sb.isNotEmpty || fields.isNotEmpty) {
      fields.add(sb.toString());
      rows.add(List.of(fields));
    }
    return rows;
  }
}