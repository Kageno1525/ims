import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static const _kHwidKey = 'ims_device_hwid';

  /// يجيب HWID ثابت للجهاز — نسخة واحدة لكل جهاز
  static Future<String> getHwid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kHwidKey);
      if (cached != null && cached.isNotEmpty) return cached;

      final plugin = DeviceInfoPlugin();
      final android = await plugin.androidInfo;

      // نبني HWID من بيانات ثابتة + عشوائي محفوظ
      final raw =
          '${android.androidId}|${android.device}|${android.model}|${android.brand}';
      final hash = _shortHash(raw);

      await prefs.setString(_kHwidKey, hash);
      return hash;
    } catch (_) {
      return 'unknown';
    }
  }

  static String _shortHash(String input) {
    // hash بسيط — مش محتاجين SHA-256 هنا
    int h = 0;
    for (int i = 0; i < input.length; i++) {
      h = ((h << 5) - h + input.codeUnitAt(i)) & 0x7fffffff;
    }
    final r = Random();
    final salt = r.nextInt(9999).toString().padLeft(4, '0');
    return 'HWID-${h.toRadixString(16).toUpperCase()}-$salt';
  }

  /// يجيب IP العام
  static Future<String> fetchIP() async {
    try {
      final res = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['ip']?.toString() ?? 'unknown';
      }
    } catch (_) {}
    return 'unknown';
  }

  /// يجيب معلومات الجهاز
  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      final android = await DeviceInfoPlugin().androidInfo;
      return {
        'hwid': await getHwid(),
        'model': '${android.manufacturer} ${android.model}',
        'device': android.device,
        'brand': android.brand,
        'version': 'Android ${android.version.release}',
        'sdk': 'SDK ${android.version.sdkInt}',
      };
    } catch (_) {
      return {
        'hwid': 'unknown',
        'model': 'Unknown',
        'device': 'unknown',
        'brand': 'unknown',
        'version': 'unknown',
        'sdk': 'unknown',
      };
    }
  }
}