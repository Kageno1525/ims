import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

/// ⭐ Cache محلي للبروفايل — عشان تسريع تسجيل الدخول
class ProfileCache {
  static const _kProfileKey = 'ims_cached_profile';
  static const _kCacheTimeKey = 'ims_cached_profile_time';

  /// صلاحية الكاش: 7 أيام
  static const Duration _validity = Duration(days: 7);

  static Future<void> save(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = profile.toMap();
      data['uid'] = profile.uid; // ⭐ نحفظ الـ uid مع البيانات
      await prefs.setString(_kProfileKey, jsonEncode(data));
      await prefs.setInt(
        _kCacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  static Future<UserProfile?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kProfileKey);
      if (raw == null || raw.isEmpty) return null;

      // ⭐ نتأكد إن الكاش مش قديم أوي
      final ts = prefs.getInt(_kCacheTimeKey) ?? 0;
      if (ts == 0) return null;
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ts));
      if (age > _validity) {
        await clear();
        return null;
      }

      final data = jsonDecode(raw) as Map<String, dynamic>;
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