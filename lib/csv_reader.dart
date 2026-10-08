import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class CsvReader {
  static Future<List<String>> _candidatePaths() async {
    final list = <String>[];
    if (Platform.isAndroid) {
      list.add('/storage/emulated/0/Download/ranges');
      list.add('/sdcard/Download/ranges');
    }
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) list.add('${ext.path}/ranges');
    } catch (_) {}
    try {
      final dl = await getDownloadsDirectory();
      if (dl != null) list.add('${dl.path}/ranges');
    } catch (_) {}
    try {
      final app = await getApplicationDocumentsDirectory();
      list.add('${app.path}/ranges');
    } catch (_) {}
    return list;
  }

  static Future<Directory?> getRangesDir({bool createIfMissing = false}) async {
    for (final p in await _candidatePaths()) {
      try {
        final d = Directory(p);
        if (await d.exists()) return d;
      } catch (_) {}
    }
    if (createIfMissing) {
      final list = await _candidatePaths();
      if (list.isNotEmpty) {
        try {
          final d = Directory(list.first);
          await d.create(recursive: true);
          return d;
        } catch (_) {}
      }
    }
    return null;
  }

  /// يقرأ كل الملفات بدون تكرار (dedupe بـ realpath)
  static Future<List<CsvFile>> listFiles() async {
    final seen = <String>{};
    final files = <CsvFile>[];
    final paths = await _candidatePaths();

    for (final p in paths) {
      try {
        final dir = Directory(p);
        if (!await dir.exists()) continue;
        await for (final ent in dir.list(followLinks: false)) {
          if (ent is! File) continue;
          if (!ent.path.toLowerCase().endsWith('.csv')) continue;
          // resolve symlinks عشان مفيش تكرار
          String real;
          try {
            real = ent.resolveSymbolicLinksSync();
          } catch (_) {
            real = ent.absolute.path;
          }
          if (seen.contains(real)) continue;
          seen.add(real);
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