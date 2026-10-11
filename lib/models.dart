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

class ScriptRules {
  final bool allowRunCount;
  final int defaultRunCount;
  final int maxRunCount;
  final bool allowRange;
  final String defaultRange;

  ScriptRules({
    this.allowRunCount = false,
    this.defaultRunCount = 1,
    this.maxRunCount = 100,
    this.allowRange = false,
    this.defaultRange = '',
  });

  Map<String, dynamic> toMap() => {
        'allowRunCount': allowRunCount,
        'defaultRunCount': defaultRunCount,
        'maxRunCount': maxRunCount,
        'allowRange': allowRange,
        'defaultRange': defaultRange,
      };

  factory ScriptRules.fromMap(Map<String, dynamic>? data) {
    if (data == null) return ScriptRules();
    return ScriptRules(
      allowRunCount: data['allowRunCount'] == true,
      defaultRunCount: (data['defaultRunCount'] as num?)?.toInt() ?? 1,
      maxRunCount: (data['maxRunCount'] as num?)?.toInt() ?? 100,
      allowRange: data['allowRange'] == true,
      defaultRange: data['defaultRange']?.toString() ?? '',
    );
  }
}

class UserProfile {
  final String uid;
  final String email;
  final String name;
  final String role;
  final List<String> allowedScripts;
  final bool showNumbers;
  final bool isBanned;
  final String hwid;
  final DateTime? hwidBoundAt;
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
    this.hwid = '',
    this.hwidBoundAt,
    this.createdAt,
    this.lastLoginAt,
  });

  bool get isAdmin => role == 'admin';
  bool get hasBoundDevice => hwid.isNotEmpty;

  String get username {
    if (email.isEmpty) return '';
    final idx = email.indexOf('@');
    if (idx == -1) return email;
    return email.substring(0, idx);
  }

  factory UserProfile.fromDoc(String uid, Map<String, dynamic> data) {
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
      hwid: data['hwid']?.toString() ?? '',
      hwidBoundAt: _parseTs(data['hwidBoundAt']),
      createdAt: _parseTs(data['createdAt']),
      lastLoginAt: _parseTs(data['lastLoginAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'role': role,
        'allowedScripts': allowedScripts,
        'showNumbers': showNumbers,
        'isBanned': isBanned,
        'hwid': hwid,
      };

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

class ScriptDoc {
  final String id;
  final String name;
  final List<Map<String, dynamic>> steps;
  final List<String> assignedTo;
  final String createdBy;
  final ScriptRules rules;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ScriptDoc({
    required this.id,
    required this.name,
    required this.steps,
    required this.assignedTo,
    required this.createdBy,
    ScriptRules? rules,
    this.createdAt,
    this.updatedAt,
  }) : rules = rules ?? ScriptRules();

  factory ScriptDoc.fromDoc(String id, Map<String, dynamic> data) {
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
      rules: ScriptRules.fromMap(
        data['rules'] != null
            ? Map<String, dynamic>.from(data['rules'])
            : null,
      ),
      createdAt: _parseTs(data['createdAt']),
      updatedAt: _parseTs(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'steps': steps,
        'assignedTo': assignedTo,
        'createdBy': createdBy,
        'rules': rules.toMap(),
      };

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