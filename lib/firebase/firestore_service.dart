import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════ USERS ═══════════════

  /// قراءة بروفايل مستخدم
  static Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromDoc(uid, doc.data() ?? {});
    } catch (e) {
      return null;
    }
  }

  /// Stream لبروفايل المستخدم (يتحدث لحظياً)
  static Stream<UserProfile?> userProfileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromDoc(uid, snap.data() ?? {});
    });
  }

  /// كل المستخدمين (للأدمن)
  static Stream<List<UserProfile>> allUsersStream() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => UserProfile.fromDoc(d.id, d.data()))
          .toList();
    });
  }

  /// إنشاء/تحديث بروفايل مستخدم
  static Future<void> upsertUserProfile({
    required String uid,
    required String email,
    required String name,
    String role = 'user',
    List<String> allowedScripts = const [],
    bool showNumbers = true,
    bool isBanned = false,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    final data = {
      'email': email,
      'name': name,
      'role': role,
      'allowedScripts': allowedScripts,
      'showNumbers': showNumbers,
      'isBanned': isBanned,
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
    };
    await ref.set(data, SetOptions(merge: true));
  }

  /// تحديث بيانات مستخدم
  static Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  /// حظر / إلغاء حظر
  static Future<void> setUserBanned(String uid, bool banned) async {
    await _db.collection('users').doc(uid).update({'isBanned': banned});
  }

  /// مسح مستخدم
  static Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  /// تحديث آخر دخول
  static Future<void> updateLastLogin(String uid) async {
    await _db.collection('users').doc(uid).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════ SCRIPTS ═══════════════

  /// كل السكربتات (للأدمن)
  static Stream<List<ScriptDoc>> allScriptsStream() {
    return _db
        .collection('scripts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => ScriptDoc.fromDoc(d.id, d.data()))
          .toList();
    });
  }

  /// السكربتات المسموح بها لمستخدم معين
  static Stream<List<ScriptDoc>> userScriptsStream(String uid) {
    return _db
        .collection('scripts')
        .where('assignedTo', arrayContains: uid)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => ScriptDoc.fromDoc(d.id, d.data()))
          .toList();
    });
  }

  /// رفع سكربت جديد
  static Future<String> uploadScript({
    required String name,
    required List<Map<String, dynamic>> steps,
    required List<String> assignedTo,
    required String createdBy,
  }) async {
    final ref = await _db.collection('scripts').add({
      'name': name,
      'steps': steps,
      'assignedTo': assignedTo,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// تحديث سكربت
  static Future<void> updateScript(
    String id,
    Map<String, dynamic> data,
  ) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('scripts').doc(id).set(data, SetOptions(merge: true));
  }

  /// مسح سكربت
  static Future<void> deleteScript(String id) async {
    await _db.collection('scripts').doc(id).delete();
  }

  // ═══════════════ SESSIONS ═══════════════

  /// كتابة جلسة جديدة (deviceId + sessionId)
  static Future<void> setSession({
    required String uid,
    required String sessionId,
    required String deviceModel,
    required String deviceName,
    required String ip,
  }) async {
    await _db.collection('sessions').doc(uid).set({
      'sessionId': sessionId,
      'deviceModel': deviceModel,
      'deviceName': deviceName,
      'ip': ip,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// قراءة الجلسة الحالية للمستخدم
  static Future<Map<String, dynamic>?> getSession(String uid) async {
    try {
      final doc = await _db.collection('sessions').doc(uid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  /// Stream للجلسة (عشان نراقب لو حد تاني دخل من جهاز مختلف)
  static Stream<Map<String, dynamic>?> sessionStream(String uid) {
    return _db.collection('sessions').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return snap.data();
    });
  }

  /// مسح جلسة (logout)
  static Future<void> clearSession(String uid) async {
    try {
      await _db.collection('sessions').doc(uid).delete();
    } catch (_) {}
  }
}