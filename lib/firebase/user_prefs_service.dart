import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserPrefsService {
  static const _kPrefix = 'ims_script_pref_';

  static String _key(String scriptId) => '$_kPrefix$scriptId';

  static Future<ScriptUserPrefs> load(String scriptId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(scriptId));
      if (raw == null || raw.isEmpty) {
        return ScriptUserPrefs();
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return ScriptUserPrefs.fromMap(data);
    } catch (_) {
      return ScriptUserPrefs();
    }
  }

  static Future<void> save(
    String scriptId,
    ScriptUserPrefs prefsData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(scriptId),
        jsonEncode(prefsData.toMap()),
      );
    } catch (_) {}
  }

  static Future<void> clear(String scriptId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(scriptId));
    } catch (_) {}
  }
}

class ScriptUserPrefs {
  final int runCount;
  final String rangeName;
  final bool useFile;          // ⭐ جديد
  final bool advanceRow;       // ⭐ جديد
  final int fileRepeats;       // ⭐ جديد

  ScriptUserPrefs({
    this.runCount = 0,
    this.rangeName = '',
    this.useFile = true,
    this.advanceRow = true,
    this.fileRepeats = 0,
  });

  Map<String, dynamic> toMap() => {
        'runCount': runCount,
        'rangeName': rangeName,
        'useFile': useFile,
        'advanceRow': advanceRow,
        'fileRepeats': fileRepeats,
      };

  factory ScriptUserPrefs.fromMap(Map<String, dynamic> data) {
    return ScriptUserPrefs(
      runCount: (data['runCount'] as num?)?.toInt() ?? 0,
      rangeName: data['rangeName']?.toString() ?? '',
      useFile: data['useFile'] != false,
      advanceRow: data['advanceRow'] != false,
      fileRepeats: (data['fileRepeats'] as num?)?.toInt() ?? 0,
    );
  }
}