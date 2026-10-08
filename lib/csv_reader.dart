import 'dart:convert';
import 'dart:io';
import 'models.dart';

class CsvReader {
  /// مجلد ملفات الـ CSV: Download/ranges
  static Future<Directory?> getRangesDir() async {
    if (!Platform.isAndroid) return null;
    for (final p in ['/storage/emulated/0/Download', '/sdcard/Download']) {
      try {
        final d = Directory(p);
        if (await d.exists()) {
          return Directory('${d.path}/ranges');
        }
      } catch (_) {}
    }
    return null;
  }

  /// يقرأ كل ملفات CSV الموجودة في المجلد ويرجع معلوماتها
  static Future<List<CsvFile>> listFiles() async {
    final dir = await getRangesDir();
    if (dir == null || !await dir.exists()) return [];
    final files = <CsvFile>[];
    await for (final ent in dir.list()) {
      if (ent is! File) continue;
      if (!ent.path.toLowerCase().endsWith('.csv')) continue;
      try {
        final nums = await readColumnC(ent.path);
        final name = ent.path.split(Platform.pathSeparator).last
            .replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
        files.add(CsvFile(name: name, path: ent.path, count: nums.length));
      } catch (_) {}
    }
    files.sort((a, b) => a.name.compareTo(b.name));
    return files;
  }

  /// يقرأ العمود C (index=2) من الصف 2 لآخر الصف
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

  /// CSV parser بسيط يدعم quotes
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