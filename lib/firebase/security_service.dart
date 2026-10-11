import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityService {
  static final _db = FirebaseFirestore.instance;

  /// يسجل محاولة دخول مشبوهة — بدون حظر
  static Future<void> logSecurityEvent({
    required String type,       // 'admin_login_attempt' مثلاً
    required String hwid,
    required String ip,
    required String deviceModel,
    required String deviceName,
    required String attemptedUsername,
    required String targetAccountUid,
    required String targetAccountName,
    String? previousUsername,
  }) async {
    try {
      await _db.collection('security_events').add({
        'type': type,
        'hwid': hwid,
        'ip': ip,
        'deviceModel': deviceModel,
        'deviceName': deviceName,
        'attemptedUsername': attemptedUsername,
        'targetAccountUid': targetAccountUid,
        'targetAccountName': targetAccountName,
        'previousUsername': previousUsername ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false,
      });
    } catch (_) {}
  }

  /// يتأكد لو الجهاز ده محظور
  static Future<bool> isHwidBanned(String hwid) async {
    try {
      final doc = await _db.collection('banned_devices').doc(hwid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// يحظر HWID
  static Future<void> banHwid({
    required String hwid,
    required String bannedBy,
    required String deviceModel,
    required String lastUsername,
    required String reason,
  }) async {
    await _db.collection('banned_devices').doc(hwid).set({
      'hwid': hwid,
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': bannedBy,
      'deviceModel': deviceModel,
      'lastUsername': lastUsername,
      'reason': reason,
    });
  }

  /// يرفع الحظر
  static Future<void> unbanHwid(String hwid) async {
    await _db.collection('banned_devices').doc(hwid).delete();
  }

  /// Stream للأحداث الأمنية (للأدمن)
  static Stream<List<Map<String, dynamic>>> securityEventsStream() {
    return _db
        .collection('security_events')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    });
  }

  /// Stream للأجهزة المحظورة
  static Stream<List<Map<String, dynamic>>> bannedDevicesStream() {
    return _db
        .collection('banned_devices')
        .orderBy('bannedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    });
  }

  /// عدد الإشعارات غير المقروءة
  static Stream<int> unseenCountStream() {
    return _db
        .collection('security_events')
        .where('seen', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// يخلي كل الإشعارات مقروءة
  static Future<void> markAllSeen() async {
    try {
      final snap = await _db
          .collection('security_events')
          .where('seen', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'seen': true});
      }
      await batch.commit();
    } catch (_) {}
  }
}