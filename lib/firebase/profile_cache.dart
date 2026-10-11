import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

/// ⭐ Cache محلي للبروفايل — **مشفّر**
/// التشفير: XOR بمسار متعدد الطبقات مع SHA-256 key مشتق
class ProfileCache {
  static const _kProfileKey = 'ims_secure_profile_v2';
  static const _kCacheTimeKey = 'ims_secure_profile_time_v2';

  // ⭐ Salt سري — لو حد شاف الملف، مش هيعرف يفك التشفير بدون الـ salt ده
  static const String _secretSalt = 'Kageno@IMS#2026$Secure_Key!xK9pZ';

  static const Duration _validity = Duration(days: 30);

  // ⭐ توليد مفتاح تشفير من الـ salt
  static List<int> _deriveKey(String salt) {
    final bytes = utf8.encode(salt);
    final hash = sha256.convert(bytes);
    return hash.bytes;
  }

  // ⭐ تشفير XOR متعدد الطبقات
  static String _encrypt(String plain) {
    try {
      final dataBytes = utf8.encode(plain);
      final key = _deriveKey(_secretSalt);
      final out = <int>[];

      for (int i = 0; i < dataBytes.length; i++) {
        final k = key[(i * 7 + 3) % key.length];
        final shift = (i % 5) + 1;
        out.add(((dataBytes[i] ^ k) + shift) & 0xFF);
      }

      return base64Url.encode(out);
    } catch (_) {
      return '';
    }
  }

  // ⭐ فك التشفير
  static String? _decrypt(String enc) {
    try {
      final bytes = base64Url.decode(enc);
      final key = _deriveKey(_secretSalt);
      final out = <int>[];

      for (int i = 0; i < bytes.length; i++) {
        final k = key[(i * 7 + 3) % key.length];
        final shift = (i % 5) + 1;
        out.add((bytes[i] - shift) & 0xFF ^ k);
      }

      return utf8.decode(out);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = profile.toMap();
      data['uid'] = profile.uid;

      final json = jsonEncode(data);
      final enc = _encrypt(json);

      await prefs.setString(_kProfileKey, enc);
      await prefs.setInt(
        _kCacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  static Future<UserProfile?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enc = prefs.getString(_kProfileKey);
      if (enc == null || enc.isEmpty) return null;

      final ts = prefs.getInt(_kCacheTimeKey) ?? 0;
      if (ts == 0) return null;
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ts));
      if (age > _validity) {
        await clear();
        return null;
      }

      final json = _decrypt(enc);
      if (json == null || json.isEmpty) return null;

      final data = jsonDecode(json) as Map<String, dynamic>;
      final uid = data['uid']?.toString() ?? '';
      if (uid.isEmpty) return null;

      return UserProfile.fromDoc(uid, data);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kProfileKey);
      await prefs.remove(_kCacheTimeKey);
    } catch (_) {}
  }
}