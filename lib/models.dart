enum LogLevel { info, ok, error, wait }

class LogEntry {
  final String msg;
  final DateTime time;
  final LogLevel level;
  LogEntry(this.msg, this.time, this.level);
}

class CsvFile {
  final String name;
  final String path;
  final int count;
  CsvFile({required this.name, required this.path, required this.count});
}

class InstalledApp {
  final String package;
  final String name;
  InstalledApp({required this.package, required this.name});
}

// ⭐ جديد: بروفايل المستخدم
class UserProfile {
  final String uid;
  final String email;
  final String name;
  final String role; // "admin" | "user"
  final List<String> allowedScripts;
  final bool showNumbers;
  final bool isBanned;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.allowedScripts = const [],
    this.showNumbers = true,
    this.isBanned = false,
    this.createdAt,
    this.lastLoginAt,
  });

  bool get isAdmin => role == 'admin';

  factory UserProfile.fromDoc(String uid, Map<String, dynamic> data) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      try {
        if (v is DateTime) return v;
        if (v is String) return DateTime.tryParse(v);
        // Firestore Timestamp
        final d = v.toDate();
        if (d is DateTime) return d;
      } catch (_) {}
      return null;
    }

    return UserProfile(
      uid: uid,
      email: data['email']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      role: data['role']?.toString() ?? 'user',
      allowedScripts: (data['allowedScripts'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      showNumbers: data['showNumbers'] != false,
      isBanned: data['isBanned'] == true,
      createdAt: parseTs(data['createdAt']),
      lastLoginAt: parseTs(data['lastLoginAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'role': role,
        'allowedScripts': allowedScripts,
        'showNumbers': showNumbers,
        'isBanned': isBanned,
      };
}

// ⭐ جديد: السكربت (نفس بنية المهمة)
class ScriptDoc {
  final String id;
  final String name;
  final List<Map<String, dynamic>> steps;
  final List<String> assignedTo;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ScriptDoc({
    required this.id,
    required this.name,
    required this.steps,
    required this.assignedTo,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory ScriptDoc.fromDoc(String id, Map<String, dynamic> data) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      try {
        if (v is DateTime) return v;
        if (v is String) return DateTime.tryParse(v);
        final d = v.toDate();
        if (d is DateTime) return d;
      } catch (_) {}
      return null;
    }

    return ScriptDoc(
      id: id,
      name: data['name']?.toString() ?? '',
      steps: (data['steps'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      assignedTo: (data['assignedTo'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      createdBy: data['createdBy']?.toString() ?? '',
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'steps': steps,
        'assignedTo': assignedTo,
        'createdBy': createdBy,
      };
}