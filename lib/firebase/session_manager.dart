import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

class SessionManager {
  static const _kSessionKey = 'ims_session_id';

  static Future<String> getOrCreateSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kSessionKey);
    if (id == null || id.isEmpty) {
      id = _generateId();
      await prefs.setString(_kSessionKey, id);
    }
    return id;
  }

  static String _generateId() {
    final r = Random.secure();
    final bytes = List<int>.generate(24, (_) => r.nextInt(256));
    return base64Url.encode(bytes);
  }

  static Future<String> fetchIP() async {
    try {
      final res = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['ip']?.toString() ?? 'unknown';
      }
    } catch (_) {}
    return 'unknown';
  }

  static Future<Map<String, String>> fetchDeviceInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      final android = await plugin.androidInfo;
      return {
        'model': '${android.manufacturer} ${android.model}',
        'device': android.device,
        'version': 'Android ${android.version.release}',
      };
    } catch (_) {
      return {
        'model': 'Unknown',
        'device': 'unknown',
        'version': 'unknown',
      };
    }
  }

  static Future<SessionCheck> bindSession(
    String uid, {
    required String currentHwid,
    required bool isAdmin,
  }) async {
    if (currentHwid.isEmpty || currentHwid == 'unknown') {
      return SessionCheck.ok;
    }

    try {
      await FirestoreService.setUserHwid(uid, currentHwid)
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    if (!isAdmin) {
      try {
        final profile = await FirestoreService.getUserProfile(uid)
            .timeout(const Duration(seconds: 4));
        if (profile != null &&
            profile.hwid.isNotEmpty &&
            profile.hwid != currentHwid) {
          return SessionCheck.wrongDevice(boundHwid: profile.hwid);
        }
      } catch (_) {}
    }

    getOrCreateSessionId().then((sessionId) async {
      try {
        final ip = await fetchIP();
        final info = await fetchDeviceInfo();
        await FirestoreService.setSessionWithHwid(
          uid: uid,
          sessionId: sessionId,
          hwid: currentHwid,
          deviceModel: info['model'] ?? 'unknown',
          deviceName: info['device'] ?? 'unknown',
          ip: ip,
        );
      } catch (_) {}
    });

    return SessionCheck.ok;
  }

  static Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
  }

  static Stream<bool> watchSessionConflict(String uid, String currentHwid) {
    return FirestoreService.sessionStream(uid).map((data) {
      if (data == null) return false;
      final remoteHwid = data['hwid']?.toString() ?? '';
      if (remoteHwid.isEmpty) return false;
      return remoteHwid != currentHwid;
    });
  }
}

enum SessionCheckStatus { ok, wrongDevice, sessionConflict }

class SessionCheck {
  final SessionCheckStatus status;
  final String? boundHwid;

  SessionCheck._(this.status, {this.boundHwid});

  static final ok = SessionCheck._(SessionCheckStatus.ok);

  factory SessionCheck.wrongDevice({required String boundHwid}) =>
      SessionCheck._(SessionCheckStatus.wrongDevice, boundHwid: boundHwid);

  static final sessionConflict =
      SessionCheck._(SessionCheckStatus.sessionConflict);
}