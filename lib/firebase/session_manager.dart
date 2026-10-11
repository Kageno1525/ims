import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';
import 'device_service.dart';

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
          .timeout(const Duration(seconds: 6));
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

  // ⭐⭐⭐ ربط الجلسة + التحقق من HWID
  // بياخد اليوزر والـ hwid الجديد، ويرجّع:
  //   ok → تمام
  //   wrongDevice → اليوزر مربوط بجهاز تاني
  //   sessionConflict → نفس اليوزر فاتح على جهاز تاني بنفس الوقت
  static Future<SessionCheck> bindSession(
    String uid, {
    required String currentHwid,
    required bool isAdmin,
  }) async {
    // 1) اجلب بيانات اليوزر
    final profile = await FirestoreService.getUserProfile(uid);
    if (profile == null) {
      return SessionCheck.ok;
    }

    // 2) ⭐ فحص HWID — لو اليوزر مربوط بجهاز تاني
    //    ⚠️ الحماية دي بتتطبق على اليوزر العادي بس (الأدمن بيتخطاها)
    if (!isAdmin) {
      if (profile.hwid.isNotEmpty && profile.hwid != currentHwid) {
        return SessionCheck.wrongDevice(
          boundHwid: profile.hwid,
        );
      }

      // 3) لو مفيش hwid محفوظ → اربط الجهاز ده
      if (profile.hwid.isEmpty) {
        try {
          await FirestoreService.setUserHwid(uid, currentHwid);
        } catch (_) {}
      }
    }

    // 4) فحص الجلسة (نفس الجهاز مفتوح مرتين)
    final sessionId = await getOrCreateSessionId();
    final ip = await fetchIP();
    final info = await fetchDeviceInfo();

    final existing = await FirestoreService.getSession(uid);
    if (existing != null) {
      final existingSession = existing['sessionId']?.toString() ?? '';
      if (existingSession.isNotEmpty && existingSession != sessionId) {
        return SessionCheck.sessionConflict;
      }
    }

    await FirestoreService.setSession(
      uid: uid,
      sessionId: sessionId,
      deviceModel: info['model'] ?? 'unknown',
      deviceName: info['device'] ?? 'unknown',
      ip: ip,
    );

    return SessionCheck.ok;
  }

  static Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
  }

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

// ⭐ نتيجة فحص الجلسة
enum SessionCheckStatus { ok, wrongDevice, sessionConflict }

class SessionCheck {
  final SessionCheckStatus status;
  final String? boundHwid;
  final String? boundDeviceModel;

  SessionCheck._(this.status, {this.boundHwid, this.boundDeviceModel});

  static final ok = SessionCheck._(SessionCheckStatus.ok);

  factory SessionCheck.wrongDevice({
    required String boundHwid,
    String? boundDeviceModel,
  }) =>
      SessionCheck._(
        SessionCheckStatus.wrongDevice,
        boundHwid: boundHwid,
        boundDeviceModel: boundDeviceModel,
      );

  static final sessionConflict =
      SessionCheck._(SessionCheckStatus.sessionConflict);
}