enum TaskStepType {
  openApp,
  wait,
  typeText,
  clickByText,
  clickByDesc,
  clickById,
  clickAt,
  waitForElement,
  clearAppData,
  swipe,
  back,
  home,
  recents,
}

enum FailureAction { stop, skip }

enum OnAppearAction { none, click, type }

enum NotFoundAction {
  skip,       // تخطي خطوات
  stop,       // وقف المهمة
  clickAlt,   // اضغط على عنصر بديل
  typeAlt,    // اكتب نص
  back,       // رجوع
  home,       // الرئيسية
}

class TaskStep {
  final String id;
  final TaskStepType type;
  final Map<String, dynamic> params;
  final int waitAfterMs;
  final int timeoutMs;
  final FailureAction onFail;
  final int skipCount;
  final OnAppearAction onAppear;
  final NotFoundAction onNotFound;
  final String appearText;
  final String altText;
  final String altDesc;
  final String altViewId;
  final String altTypeText;

  TaskStep({
    required this.id,
    required this.type,
    required this.params,
    this.waitAfterMs = 500,
    this.timeoutMs = 0,
    this.onFail = FailureAction.stop,
    this.skipCount = 0,
    this.onAppear = OnAppearAction.none,
    this.onNotFound = NotFoundAction.skip,
    this.appearText = '',
    this.altText = '',
    this.altDesc = '',
    this.altViewId = '',
    this.altTypeText = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'params': params,
        'waitAfterMs': waitAfterMs,
        'timeoutMs': timeoutMs,
        'onFail': onFail.name,
        'skipCount': skipCount,
        'onAppear': onAppear.name,
        'onNotFound': onNotFound.name,
        'appearText': appearText,
        'altText': altText,
        'altDesc': altDesc,
        'altViewId': altViewId,
        'altTypeText': altTypeText,
      };

  factory TaskStep.fromJson(Map<String, dynamic> json) => TaskStep(
        id: json['id']?.toString() ?? '',
        type: TaskStepType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => TaskStepType.wait,
        ),
        params: Map<String, dynamic>.from(json['params'] ?? {}),
        waitAfterMs: json['waitAfterMs'] ?? 500,
        timeoutMs: json['timeoutMs'] ?? 0,
        onFail: FailureAction.values.firstWhere(
          (e) => e.name == json['onFail'],
          orElse: () => FailureAction.stop,
        ),
        skipCount: json['skipCount'] ?? 0,
        onAppear: OnAppearAction.values.firstWhere(
          (e) => e.name == json['onAppear'],
          orElse: () => OnAppearAction.none,
        ),
        onNotFound: NotFoundAction.values.firstWhere(
          (e) => e.name == json['onNotFound'],
          orElse: () => NotFoundAction.skip,
        ),
        appearText: json['appearText']?.toString() ?? '',
        altText: json['altText']?.toString() ?? '',
        altDesc: json['altDesc']?.toString() ?? '',
        altViewId: json['altViewId']?.toString() ?? '',
        altTypeText: json['altTypeText']?.toString() ?? '',
      );

  TaskStep copyWith({
    String? id,
    TaskStepType? type,
    Map<String, dynamic>? params,
    int? waitAfterMs,
    int? timeoutMs,
    FailureAction? onFail,
    int? skipCount,
    OnAppearAction? onAppear,
    NotFoundAction? onNotFound,
    String? appearText,
    String? altText,
    String? altDesc,
    String? altViewId,
    String? altTypeText,
  }) =>
      TaskStep(
        id: id ?? this.id,
        type: type ?? this.type,
        params: params ?? this.params,
        waitAfterMs: waitAfterMs ?? this.waitAfterMs,
        timeoutMs: timeoutMs ?? this.timeoutMs,
        onFail: onFail ?? this.onFail,
        skipCount: skipCount ?? this.skipCount,
        onAppear: onAppear ?? this.onAppear,
        onNotFound: onNotFound ?? this.onNotFound,
        appearText: appearText ?? this.appearText,
        altText: altText ?? this.altText,
        altDesc: altDesc ?? this.altDesc,
        altViewId: altViewId ?? this.altViewId,
        altTypeText: altTypeText ?? this.altTypeText,
      );

  bool get isWaitStep => type == TaskStepType.waitForElement;

  bool get isClickStep =>
      type == TaskStepType.clickByText ||
      type == TaskStepType.clickByDesc ||
      type == TaskStepType.clickById ||
      type == TaskStepType.clickAt;

  bool get isSearchStep => isClickStep || isWaitStep;

  String get typeLabel {
    switch (type) {
      case TaskStepType.openApp:
        return 'فتح تطبيق';
      case TaskStepType.wait:
        return 'انتظار';
      case TaskStepType.typeText:
        return 'كتابة نص';
      case TaskStepType.clickByText:
        return 'ضغط على نص';
      case TaskStepType.clickByDesc:
        return 'ضغط على وصف';
      case TaskStepType.clickById:
        return 'ضغط على id';
      case TaskStepType.clickAt:
        return 'ضغط بإحداثيات';
      case TaskStepType.waitForElement:
        return 'انتظار ظهور عنصر';
      case TaskStepType.clearAppData:
        return 'مسح بيانات تطبيق';
      case TaskStepType.swipe:
        return 'سحب (Swipe)';
      case TaskStepType.back:
        return 'رجوع';
      case TaskStepType.home:
        return 'الرئيسية';
      case TaskStepType.recents:
        return 'التطبيقات الأخيرة';
    }
  }

  String get summary {
    switch (type) {
      case TaskStepType.openApp:
        return params['package']?.toString() ?? '';
      case TaskStepType.wait:
        return '${params['ms'] ?? 1000} مللي';
      case TaskStepType.typeText:
        final v = params['text']?.toString() ?? '';
        final id = params['viewId']?.toString() ?? '';
        final hint = params['hint']?.toString() ?? '';
        if (id.isNotEmpty) return 'في $id: $v';
        if (hint.isNotEmpty) return 'في "$hint": $v';
        return v;
      case TaskStepType.clickByText:
        return 'النص: ${params['text'] ?? ''}';
      case TaskStepType.clickByDesc:
        return 'الوصف: ${params['desc'] ?? ''}';
      case TaskStepType.clickById:
        return 'id: ${params['viewId'] ?? ''}';
      case TaskStepType.clickAt:
        return '(${params['x'] ?? 0}, ${params['y'] ?? 0})';
      case TaskStepType.waitForElement:
        final t = params['text']?.toString() ?? '';
        final d = params['desc']?.toString() ?? '';
        final id = params['viewId']?.toString() ?? '';
        String target = '';
        if (t.isNotEmpty) {
          target = 'نص: $t';
        } else if (d.isNotEmpty) {
          target = 'وصف: $d';
        } else if (id.isNotEmpty) {
          target = 'id: $id';
        } else {
          target = '(بدون شرط)';
        }
        String appear = '';
        switch (onAppear) {
          case OnAppearAction.click:
            appear = ' → اضغط';
            break;
          case OnAppearAction.type:
            appear = ' → اكتب "$appearText"';
            break;
          case OnAppearAction.none:
            appear = '';
        }
        return '$target$appear';
      case TaskStepType.clearAppData:
        return params['package']?.toString() ?? '';
      case TaskStepType.swipe:
        return '(${params['x1']},${params['y1']}) → (${params['x2']},${params['y2']})';
      case TaskStepType.back:
      case TaskStepType.home:
      case TaskStepType.recents:
        return '';
    }
  }
}

class Task {
  final String id;
  final String name;
  final List<TaskStep> steps;
  final DateTime createdAt;
  final DateTime? lastRunAt;

  Task({
    required this.id,
    required this.name,
    required this.steps,
    required this.createdAt,
    this.lastRunAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'steps': steps.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'lastRunAt': lastRunAt?.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        steps: (json['steps'] as List? ?? [])
            .map((e) => TaskStep.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        lastRunAt: json['lastRunAt'] != null
            ? DateTime.tryParse(json['lastRunAt'].toString())
            : null,
      );

  Task copyWith({
    String? name,
    List<TaskStep>? steps,
    DateTime? lastRunAt,
  }) =>
      Task(
        id: id,
        name: name ?? this.name,
        steps: steps ?? this.steps,
        createdAt: createdAt,
        lastRunAt: lastRunAt ?? this.lastRunAt,
      );
}