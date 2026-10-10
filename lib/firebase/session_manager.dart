import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

class SessionManager {
  static const _kSessionKey = 'ims_session_id';

  /// يرجّع sessionId مخزّن، أو ينشئ واحد جديد
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

  /// يجيب IP العام من api.ipify.org
  static Future<String> fetchIP() async {
    try {
      final res = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['ip']?.toString() ?? 'unknown';
      }
    } catch (_) {}
    return 'unknown';
  }

  /// يجيب معلومات الجهاز
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

  /// تثبيت الجلسة الحالية للمستخدم في Firestore
  /// يرجّع true لو الجهاز ده هو الجلسة الفعّالة
  static Future<bool> bindSession(String uid) async {
    final sessionId = await getOrCreateSessionId();
    final ip = await fetchIP();
    final info = await fetchDeviceInfo();

    final existing = await FirestoreService.getSession(uid);

    // لو فيه جلسة على جهاز تاني، ارفض
    if (existing != null) {
      final existingSession = existing['sessionId']?.toString() ?? '';
      if (existingSession.isNotEmpty && existingSession != sessionId) {
        return false;
      }
    }

    // سجّل الجلسة الحالية
    await FirestoreService.setSession(
      uid: uid,
      sessionId: sessionId,
      deviceModel: info['model'] ?? 'unknown',
      deviceName: info['device'] ?? 'unknown',
      ip: ip,
    );
    return true;
  }

  /// يمسح الجلسة المحلية (بس مش من Firestore — ده للأدمن)
  static Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
  }

  /// Stream يخبرك لو حد دخل من جهاز تاني (عشان نطرد الجهاز الحالي)
  static Stream<bool> watchSessionConflict(String uid) {
    return FirestoreService.sessionStream(uid).asyncMap((data) async {
      if (data == null) return false;
      final remoteSession = data['sessionId']?.toString() ?? '';
      if (remoteSession.isEmpty) return false;
      final localSession = await getOrCreateSessionId();
      return remoteSession != localSession;
    });
  }
}