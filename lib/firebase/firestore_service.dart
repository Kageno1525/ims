import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';
import '../tasks/task_model.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════ USERS ═══════════════

  static Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromDoc(uid, doc.data() ?? {});
    } catch (e) {
      return null;
    }
  }

  static Stream<UserProfile?> userProfileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromDoc(uid, snap.data() ?? {});
    });
  }

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

  static Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  static Future<void> setUserBanned(String uid, bool banned) async {
    await _db.collection('users').doc(uid).update({'isBanned': banned});
  }

  static Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  static Future<void> updateLastLogin(String uid) async {
    await _db.collection('users').doc(uid).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════ SCRIPTS ═══════════════

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

  // ⭐ البحث عن سكربت بالاسم — عشان نعرف لو موجود
  static Future<ScriptDoc?> getScriptByName(String name) async {
    try {
      final snap = await _db
          .collection('scripts')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first;
      return ScriptDoc.fromDoc(d.id, d.data());
    } catch (_) {
      return null;
    }
  }

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

  // ⭐ تحديث محتوى السكربت فقط — مع الاحتفاظ بـ assignedTo والاسم
  static Future<void> updateScriptContent({
    required String scriptId,
    required List<Map<String, dynamic>> steps,
  }) async {
    await _db.collection('scripts').doc(scriptId).update({
      'steps': steps,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateScript(
    String id,
    Map<String, dynamic> data,
  ) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('scripts').doc(id).set(data, SetOptions(merge: true));
  }

  static Future<void> deleteScript(String id) async {
    await _db.collection('scripts').doc(id).delete();
  }

  // ═══════════════ ADMIN TASKS ═══════════════
  // ⭐ المهام بتاعت الأدمن — محفوظة على Firestore عشان تفضل موجودة

  static Stream<List<Task>> adminTasksStream() {
    return _db
        .collection('admin_tasks')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        return Task(
          id: data['id']?.toString() ?? d.id,
          name: data['name']?.toString() ?? '',
          steps: (data['steps'] as List? ?? [])
              .map((e) =>
                  TaskStep.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          createdAt: _parseTs(data['createdAt']) ?? DateTime.now(),
          lastRunAt: _parseTs(data['lastRunAt']),
          repeatCount: data['repeatCount'] ?? 1,
          autoIncrement: data['autoIncrement'] == true,
        );
      }).toList();
    });
  }

  static Future<void> saveAdminTask(Task task) async {
    await _db.collection('admin_tasks').doc(task.id).set({
      'id': task.id,
      'name': task.name,
      'steps': task.steps.map((s) => s.toJson()).toList(),
      'createdAt': task.createdAt.toIso8601String(),
      'lastRunAt': task.lastRunAt?.toIso8601String(),
      'repeatCount': task.repeatCount,
      'autoIncrement': task.autoIncrement,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteAdminTask(String id) async {
    await _db.collection('admin_tasks').doc(id).delete();
  }

  // ═══════════════ SESSIONS ═══════════════

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

  static Future<Map<String, dynamic>?> getSession(String uid) async {
    try {
      final doc = await _db.collection('sessions').doc(uid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  static Stream<Map<String, dynamic>?> sessionStream(String uid) {
    return _db.collection('sessions').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return snap.data();
    });
  }

  static Future<void> clearSession(String uid) async {
    try {
      await _db.collection('sessions').doc(uid).delete();
    } catch (_) {}
  }

  // Helper
  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    try {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      final d = v.toDate();
      if (d is DateTime) return d;
    } catch (_) {}
    return null;
  }
}