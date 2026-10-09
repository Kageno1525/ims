import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets.dart';
import '../autofill_bridge.dart';
import '../models.dart' show InstalledApp;
import 'task_model.dart';

class TaskEditorPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final Task? initialTask;

  const TaskEditorPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    this.initialTask,
  });

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  late TextEditingController _nameCtrl;
  late List<TaskStep> _steps;

  static const _noDeco = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialTask?.name ?? '');
    _steps = List.from(widget.initialTask?.steps ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _uid() => DateTime.now().microsecondsSinceEpoch.toString();

  IconData _iconFor(TaskStepType t) {
    switch (t) {
      case TaskStepType.openApp: return Icons.apps_rounded;
      case TaskStepType.typeText: return Icons.keyboard_rounded;
      case TaskStepType.clickByText: return Icons.touch_app_rounded;
      case TaskStepType.clickByDesc: return Icons.description_rounded;
      case TaskStepType.clickById: return Icons.tag_rounded;
      case TaskStepType.clickAt: return Icons.my_location_rounded;
      case TaskStepType.swipe: return Icons.swipe_rounded;
      case TaskStepType.wait: return Icons.hourglass_top_rounded;
      case TaskStepType.back: return Icons.arrow_back_rounded;
      case TaskStepType.home: return Icons.home_rounded;
      case TaskStepType.recents: return Icons.view_carousel_rounded;
    }
  }

  List<Color> _colorFor(TaskStepType t) {
    switch (t) {
      case TaskStepType.openApp:
        return const [Color(0xFF6C5CE7), Color(0xFF8E7CFF)];
      case TaskStepType.typeText:
        return const [Color(0xFF00D2FF), Color(0xFF3A7BD5)];
      case TaskStepType.clickByText:
      case TaskStepType.clickByDesc:
      case TaskStepType.clickById:
        return const [Color(0xFF00B894), Color(0xFF00D68F)];
      case TaskStepType.clickAt:
        return const [Color(0xFFFFB84D), Color(0xFFFFD93D)];
      case TaskStepType.swipe:
        return const [Color(0xFFFF6B6B), Color(0xFFFF8E53)];
      case TaskStepType.wait:
        return const [Color(0xFF95A5A6), Color(0xFF7F8C8D)];
      case TaskStepType.back:
      case TaskStepType.home:
      case TaskStepType.recents:
        return const [Color(0xFF34495E), Color(0xFF2C3E50)];
    }
  }

  Future<void> _addStep() async {
    final result = await showModalBottomSheet<TaskStep>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StepTypePicker(
        isDark: widget.isDark,
        onPick: (type) {
          Navigator.pop(ctx,
              TaskStep(id: _uid(), type: type, params: {}, waitAfterMs: 500));
        },
      ),
    );
    if (result == null) return;
    if (!mounted) return;

    final configured = await showModalBottomSheet<TaskStep>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StepConfigSheet(
        isDark: widget.isDark,
        step: result,
      ),
    );

    if (configured != null) setState(() => _steps.add(configured));
  }

  Future<void> _editStep(int index) async {
    final result = await showModalBottomSheet<TaskStep>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StepConfigSheet(
        isDark: widget.isDark,
        step: _steps[index],
      ),
    );
    if (result != null) setState(() => _steps[index] = result);
  }

  void _removeStep(int index) => setState(() => _steps.removeAt(index));

  void _moveStep(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _steps.length) return;
    setState(() {
      final s = _steps.removeAt(index);
      _steps.insert(newIndex, s);
    });
  }

  void _showMsg(String msg, {bool error = true}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                color: error ? const Color(0xFFFF6B6B) : const Color(0xFF00D68F),
                size: 22),
            const SizedBox(width: 8),
            Text(error ? 'خطأ' : 'تمام',
                style: _noDeco.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(msg, style: _noDeco.copyWith(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('حسناً',
                style: _noDeco.copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _showMsg('من فضلك اكتب اسم المهمة الأول'); return; }
    if (_steps.isEmpty) { _showMsg('ضيف خطوة على الأقل قبل الحفظ'); return; }

    final fixedSteps = <TaskStep>[];
    for (final step in _steps) {
      if (step.type == TaskStepType.openApp) {
        final pkg = step.params['package']?.toString().trim() ?? '';
        if (pkg.isEmpty) {
          _showMsg('فيه خطوة "فتح تطبيق" مش محدّد فيها أي تطبيق');
          return;
        }
        final resolved = await AutoFillBridge.resolvePackage(pkg);
        if (resolved == null) {
          _showMsg('مش لاقي تطبيق "$pkg". اختاره من القائمة.');
          return;
        }
        fixedSteps.add(step.copyWith(params: {...step.params, 'package': resolved}));
      } else {
        fixedSteps.add(step);
      }
    }

    final task = Task(
      id: widget.initialTask?.id ?? _uid(),
      name: name,
      steps: fixedSteps,
      createdAt: widget.initialTask?.createdAt ?? DateTime.now(),
      lastRunAt: widget.initialTask?.lastRunAt,
    );
    if (mounted) Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBtn(icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.initialTask == null ? 'مهمة جديدة' : 'تعديل المهمة',
                      style: _noDeco.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconBtn(
                    icon: Icons.settings_rounded,
                    onTap: () => AutoFillBridge.openAccessibilitySettings(),
                  ),
                  const SizedBox(width: 4),
                  IconBtn(
                    icon: widget.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    onTap: widget.onToggleTheme,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                style: _noDeco.copyWith(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'اسم المهمة',
                  hintText: 'مثال: افتح واتساب',
                  labelStyle: _noDeco.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  hintStyle: _noDeco.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.list_alt_rounded, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('الخطوات',
                      style: _noDeco.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_steps.length}',
                        style: _noDeco.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _steps.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.playlist_add_rounded,
                                size: 60,
                                color: theme.colorScheme.primary.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text('مفيش خطوات',
                                style: _noDeco.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('اضغط "إضافة خطوة" وابدأ',
                                style: _noDeco.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                                    fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _steps.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _stepCard(theme, i),
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ActionBtn(
                      label: 'إضافة خطوة',
                      icon: Icons.add_rounded,
                      gradient: const [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                      busy: false,
                      onTap: _addStep,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActionBtn(
                      label: 'حفظ',
                      icon: Icons.save_rounded,
                      gradient: const [Color(0xFF00B894), Color(0xFF00D68F)],
                      busy: false,
                      onTap: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepCard(ThemeData theme, int i) {
    final step = _steps[i];
    final colors = _colorFor(step.type);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(widget.isDark ? 0.6 : 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.first.withOpacity(0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_iconFor(step.type), color: Colors.white, size: 18),
                const SizedBox(height: 1),
                Text('${i + 1}',
                    style: _noDeco.copyWith(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.typeLabel,
                    style: _noDeco.copyWith(
                      fontWeight: FontWeight.bold, fontSize: 14, color: colors.first)),
                if (step.summary.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(step.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _noDeco.copyWith(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.75))),
                ],
                Row(
                  children: [
                    Text('انتظار: ${step.waitAfterMs}م',
                        style: _noDeco.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withOpacity(0.45))),
                    if (step.isSearchStep && step.timeoutMs > 0) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.timer_rounded, size: 10,
                          color: theme.colorScheme.onSurface.withOpacity(0.45)),
                      const SizedBox(width: 2),
                      Text('${step.timeoutMs}م',
                          style: _noDeco.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withOpacity(0.45))),
                    ],
                    if (step.onFail == FailureAction.skip) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.skip_next_rounded, size: 10,
                          color: const Color(0xFFFFB84D)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tinyIconBtn(
                    icon: Icons.keyboard_arrow_up_rounded,
                    onTap: i == 0 ? null : () => _moveStep(i, -1),
                    color: theme.colorScheme.onSurface,
                  ),
                  _tinyIconBtn(
                    icon: Icons.keyboard_arrow_down_rounded,
                    onTap: i == _steps.length - 1 ? null : () => _moveStep(i, 1),
                    color: theme.colorScheme.onSurface,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tinyIconBtn(
                    icon: Icons.edit_rounded,
                    onTap: () => _editStep(i),
                    color: const Color(0xFF00D2FF),
                  ),
                  _tinyIconBtn(
                    icon: Icons.close_rounded,
                    onTap: () => _removeStep(i),
                    color: const Color(0xFFFF6B6B),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tinyIconBtn({
    required IconData icon,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon,
              size: 18,
              color: onTap == null ? color.withOpacity(0.25) : color),
        ),
      ),
    );
  }
}

// ═══════ اختيار نوع الخطوة ═══════
class _StepTypePicker extends StatelessWidget {
  final bool isDark;
  final Function(TaskStepType) onPick;
  const _StepTypePicker({required this.isDark, required this.onPick});

  static const _noDeco = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  IconData _iconFor(TaskStepType t) {
    switch (t) {
      case TaskStepType.openApp: return Icons.apps_rounded;
      case TaskStepType.typeText: return Icons.keyboard_rounded;
      case TaskStepType.clickByText: return Icons.touch_app_rounded;
      case TaskStepType.clickByDesc: return Icons.description_rounded;
      case TaskStepType.clickById: return Icons.tag_rounded;
      case TaskStepType.clickAt: return Icons.my_location_rounded;
      case TaskStepType.swipe: return Icons.swipe_rounded;
      case TaskStepType.wait: return Icons.hourglass_top_rounded;
      case TaskStepType.back: return Icons.arrow_back_rounded;
      case TaskStepType.home: return Icons.home_rounded;
      case TaskStepType.recents: return Icons.view_carousel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = TaskStepType.values;
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 50, height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('اختر نوع الخطوة',
                textAlign: TextAlign.center,
                style: _noDeco.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              alignment: WrapAlignment.center,
              children: items.map((t) {
                final label = TaskStep(id: '', type: t, params: {}, waitAfterMs: 0).typeLabel;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onPick(t),
                    child: Container(
                      width: 100,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(isDark ? 0.6 : 0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.25)),
                      ),
                      child: Column(
                        children: [
                          Icon(_iconFor(t), size: 26, color: theme.colorScheme.primary),
                          const SizedBox(height: 6),
                          Text(label,
                              textAlign: TextAlign.center,
                              style: _noDeco.copyWith(
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════ إعدادات الخطوة ═══════
class _StepConfigSheet extends StatefulWidget {
  final bool isDark;
  final TaskStep step;
  const _StepConfigSheet({required this.isDark, required this.step});

  @override
  State<_StepConfigSheet> createState() => _StepConfigSheetState();
}

class _StepConfigSheetState extends State<_StepConfigSheet> {
  static const _noDeco = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  late Map<String, TextEditingController> _ctrls;
  late TaskStepType _currentType;  // ⭐ نوع الخطوة الحالي - قابل للتغيير
  late int _waitAfter;
  late int _timeoutMs;
  late FailureAction _onFail;
  String? _selectedAppName;
  String? _lastWarning;  // ⭐ تحذير آخر التقاط

  @override
  void initState() {
    super.initState();
    _ctrls = {};
    _currentType = widget.step.type;
    _waitAfter = widget.step.waitAfterMs;
    _timeoutMs = widget.step.timeoutMs;
    _onFail = widget.step.onFail;

    final keys = _fieldKeysFor(_currentType);
    for (final k in keys) {
      _ctrls[k] = TextEditingController(
        text: widget.step.params[k]?.toString() ?? _defaultValueFor(_currentType, k),
      );
    }
  }

  List<String> _fieldKeysFor(TaskStepType t) {
    switch (t) {
      case TaskStepType.openApp: return ['package'];
      case TaskStepType.typeText:
      case TaskStepType.clickByText: return ['text'];
      case TaskStepType.clickByDesc: return ['desc'];
      case TaskStepType.clickById: return ['viewId'];
      case TaskStepType.clickAt: return ['x', 'y'];
      case TaskStepType.swipe: return ['x1', 'y1', 'x2', 'y2', 'duration'];
      case TaskStepType.wait: return ['ms'];
      default: return [];
    }
  }

  String _defaultValueFor(TaskStepType t, String key) {
    if (t == TaskStepType.wait && key == 'ms') return '1000';
    if (t == TaskStepType.swipe && key == 'duration') return '300';
    return '';
  }

  String _labelFor(String key) {
    switch (key) {
      case 'package': return 'اسم الحزمة';
      case 'text': return 'النص';
      case 'desc': return 'الوصف (Content Description)';
      case 'viewId': return 'الـ view id';
      case 'x': return 'X';
      case 'y': return 'Y';
      case 'x1': return 'X البداية';
      case 'y1': return 'Y البداية';
      case 'x2': return 'X النهاية';
      case 'y2': return 'Y النهاية';
      case 'duration':
      case 'ms': return 'المدة (مللي ثانية)';
      default: return key;
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _pickApp() async {
    final app = await showModalBottomSheet<InstalledApp>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AppPickerSheet(isDark: widget.isDark),
    );
    if (app != null && mounted) {
      setState(() {
        _ctrls['package']?.text = app.package;
        _selectedAppName = app.name;
      });
    }
  }

  // ⭐ تغيير نوع الخطوة (نحتفظ بالبيانات)
  void _changeType(TaskStepType newType) {
    setState(() {
      final oldValues = <String, String>{};
      for (final e in _ctrls.entries) {
        oldValues[e.key] = e.value.text;
      }
      _currentType = newType;

      final keys = _fieldKeysFor(newType);
      final newCtrls = <String, TextEditingController>{};
      for (final k in keys) {
        // احتفظ بالقيمة القديمة لو موجودة
        final val = oldValues[k] ?? _defaultValueFor(newType, k);
        newCtrls[k] = TextEditingController(text: val);
      }
      for (final c in _ctrls.values) c.dispose();
      _ctrls = newCtrls;
      _lastWarning = null;
    });
  }

  // ⭐ التقاط الشاشة
  Future<void> _inspectScreen() async {
    final captured = await showDialog<List<ScreenElement>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CountdownDialog(),
    );

    if (captured == null || captured.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مفيش عناصر. تأكد من Accessibility.')),
        );
      }
      return;
    }
    if (!mounted) return;

    final picked = await showModalBottomSheet<ScreenElement>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ElementPickerSheet(elements: captured, isDark: widget.isDark),
    );
    if (picked == null) return;

    // ⭐ املأ كل الحقول الممكنة
    setState(() {
      if (_ctrls.containsKey('text')) _ctrls['text']?.text = picked.text;
      if (_ctrls.containsKey('desc')) _ctrls['desc']?.text = picked.desc;
      if (_ctrls.containsKey('viewId')) _ctrls['viewId']?.text = picked.id;
      if (_ctrls.containsKey('x')) _ctrls['x']?.text = picked.x.toString();
      if (_ctrls.containsKey('y')) _ctrls['y']?.text = picked.y.toString();
    });

    // ⭐ تحقق + اقتراح نوع خطوة أفضل
    String? warning;
    TaskStepType? suggestedType;

    final hasText = picked.text.isNotEmpty;
    final hasDesc = picked.desc.isNotEmpty;
    final hasId = picked.id.isNotEmpty;

    switch (_currentType) {
      case TaskStepType.clickByText:
        if (!hasText) {
          warning = 'العنصر ده مفيهوش "نص"';
          if (hasDesc) suggestedType = TaskStepType.clickByDesc;
          else if (hasId) suggestedType = TaskStepType.clickById;
          else suggestedType = TaskStepType.clickAt;
        }
        break;
      case TaskStepType.clickByDesc:
        if (!hasDesc) {
          warning = 'العنصر ده مفيهوش "وصف"';
          if (hasText) suggestedType = TaskStepType.clickByText;
          else if (hasId) suggestedType = TaskStepType.clickById;
          else suggestedType = TaskStepType.clickAt;
        }
        break;
      case TaskStepType.clickById:
        if (!hasId) {
          warning = 'العنصر ده مفيهوش "id"';
          if (hasText) suggestedType = TaskStepType.clickByText;
          else if (hasDesc) suggestedType = TaskStepType.clickByDesc;
          else suggestedType = TaskStepType.clickAt;
        }
        break;
      case TaskStepType.clickAt:
        // الإحداثيات دايماً موجودة
        break;
      default:
        break;
    }

    setState(() => _lastWarning = warning);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning ?? 'تم اختيار: ${picked.bestLabel}'),
          duration: Duration(seconds: warning != null ? 5 : 2),
          backgroundColor: warning != null ? const Color(0xFFFF6B6B) : null,
          action: suggestedType != null
              ? SnackBarAction(
                  label: 'غيّر النوع',
                  textColor: Colors.white,
                  onPressed: () => _changeType(suggestedType!),
                )
              : null,
        ),
      );
    }
  }

  bool get _canInspect {
    switch (_currentType) {
      case TaskStepType.clickByText:
      case TaskStepType.clickByDesc:
      case TaskStepType.clickById:
      case TaskStepType.clickAt:
        return true;
      default:
        return false;
    }
  }

  bool get _isSearchStep {
    switch (_currentType) {
      case TaskStepType.clickByText:
      case TaskStepType.clickByDesc:
      case TaskStepType.clickById:
      case TaskStepType.clickAt:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = TaskStep(id: '', type: _currentType, params: {}, waitAfterMs: 0).typeLabel;
    final isOpenApp = _currentType == TaskStepType.openApp;
    final currentPkg = _ctrls['package']?.text ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 50, height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(label,
                  textAlign: TextAlign.center,
                  style: _noDeco.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // ⭐ زرار تغيير النوع - مفيد جداً
              if (_isSearchStep)
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showTypeChangeSheet(),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('تغيير نوع الخطوة', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // ⚠️ تحذير لو فيه مشكلة
              if (_lastWarning != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFFF6B6B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_lastWarning!,
                            style: _noDeco.copyWith(
                                color: const Color(0xFFFF6B6B),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (_canInspect) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _inspectScreen,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('التقاط الشاشة الحالية',
                                    style: _noDeco.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                Text('هيتم الالتقاط بعد 5 ثواني',
                                    style: _noDeco.copyWith(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.85))),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (isOpenApp) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickApp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: currentPkg.isEmpty
                            ? theme.colorScheme.primary.withOpacity(0.15)
                            : theme.colorScheme.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.apps_rounded, color: theme.colorScheme.primary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentPkg.isEmpty
                                      ? 'اضغط لاختيار تطبيق من القائمة'
                                      : (_selectedAppName ?? 'تطبيق مختار'),
                                  style: _noDeco.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary),
                                ),
                                if (currentPkg.isNotEmpty)
                                  Text(currentPkg,
                                      style: _noDeco.copyWith(
                                          fontSize: 10.5,
                                          color: theme.colorScheme.onSurface.withOpacity(0.5))),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: theme.colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _ctrls['package'],
                  style: _noDeco.copyWith(fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'اسم الحزمة (أو اختار من فوق)',
                    labelStyle: _noDeco.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                ),
              ],

              if (!isOpenApp)
                ..._ctrls.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: e.value,
                        style: _noDeco.copyWith(fontSize: 15),
                        keyboardType: int.tryParse(e.value.text) != null
                            ? TextInputType.number : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: _labelFor(e.key),
                          labelStyle: _noDeco.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                        ),
                      ),
                    )),

              const SizedBox(height: 4),
              Text('الانتظار بعد الخطوة: $_waitAfter مللي',
                  style: _noDeco.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
              Slider(
                value: _waitAfter.toDouble(),
                min: 0, max: 5000, divisions: 50,
                label: '$_waitAfter',
                onChanged: (v) => setState(() => _waitAfter = v.round()),
              ),

              if (_isSearchStep) ...[
                const SizedBox(height: 4),
                Divider(color: theme.colorScheme.primary.withOpacity(0.15)),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(Icons.timer_rounded, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('مهلة الانتظار',
                        style: _noDeco.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary)),
                    const Spacer(),
                    Text(
                      _timeoutMs == 0 ? 'بدون' : '$_timeoutMs مللي',
                      style: _noDeco.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withOpacity(0.8)),
                    ),
                  ],
                ),
                Slider(
                  value: _timeoutMs.toDouble(),
                  min: 0, max: 15000, divisions: 30,
                  label: _timeoutMs == 0 ? 'بدون' : '$_timeoutMs',
                  onChanged: (v) => setState(() => _timeoutMs = v.round()),
                ),
                Text(
                  _timeoutMs == 0
                      ? 'هيتم تنفيذ الخطوة مرة واحدة بس'
                      : 'هيفضل يدوّر على العنصر لحد $_timeoutMs مللي',
                  style: _noDeco.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.55)),
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('لو فشلت الخطوة',
                        style: _noDeco.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _actionChoice(
                        theme,
                        label: 'وقف المهمة',
                        icon: Icons.stop_rounded,
                        selected: _onFail == FailureAction.stop,
                        color: const Color(0xFFFF6B6B),
                        onTap: () => setState(() => _onFail = FailureAction.stop),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionChoice(
                        theme,
                        label: 'تخطى الخطوة',
                        icon: Icons.skip_next_rounded,
                        selected: _onFail == FailureAction.skip,
                        color: const Color(0xFFFFB84D),
                        onTap: () => setState(() => _onFail = FailureAction.skip),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              ActionBtn(
                label: 'تم',
                icon: Icons.check_rounded,
                gradient: const [Color(0xFF00B894), Color(0xFF00D68F)],
                busy: false,
                onTap: () {
                  final params = <String, dynamic>{};
                  for (final e in _ctrls.entries) {
                    params[e.key] = e.value.text;
                  }
                  Navigator.pop(
                    context,
                    widget.step.copyWith(
                      type: _currentType,
                      params: params,
                      waitAfterMs: _waitAfter,
                      timeoutMs: _timeoutMs,
                      onFail: _onFail,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ⭐ sheet صغير لتغيير نوع الخطوة
  void _showTypeChangeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final types = [
          TaskStepType.clickByText,
          TaskStepType.clickByDesc,
          TaskStepType.clickById,
          TaskStepType.clickAt,
        ];
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50, height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              Text('غيّر نوع الخطوة',
                  style: _noDeco.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...types.map((t) {
                final label = TaskStep(id: '', type: t, params: {}, waitAfterMs: 0).typeLabel;
                final isCur = t == _currentType;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isCur
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : theme.colorScheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(ctx);
                        _changeType(t);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: Row(
                          children: [
                            Icon(
                              isCur ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                              color: isCur ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.4),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(label,
                                style: _noDeco.copyWith(
                                    fontSize: 14,
                                    fontWeight: isCur ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _actionChoice(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.2) : theme.colorScheme.surface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : theme.colorScheme.primary.withOpacity(0.15),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? color : theme.colorScheme.onSurface.withOpacity(0.6)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: _noDeco.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selected ? color : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════ Countdown Dialog ═══════
class _CountdownDialog extends StatefulWidget {
  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  int _seconds = 5;
  Timer? _timer;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      if (_seconds > 1) {
        setState(() => _seconds--);
      } else {
        t.cancel();
        setState(() { _seconds = 0; _capturing = true; });
        final elements = await AutoFillBridge.dumpScreen();
        if (mounted) Navigator.pop(context, elements);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.screen_share_rounded, size: 50, color: Color(0xFF6C5CE7)),
          const SizedBox(height: 14),
          Text(
            _capturing ? 'جاري الالتقاط…' : 'هيتم الالتقاط بعد $_seconds',
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold,
              decoration: TextDecoration.none),
          ),
          const SizedBox(height: 10),
          Text(
            _capturing ? 'من فضلك استنى'
                : 'اسرع! روح للتطبيق اللي عايز تلتقط منه',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              decoration: TextDecoration.none),
          ),
          if (!_capturing) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 50, height: 50,
                    child: CircularProgressIndicator(
                      value: _seconds / 5,
                      strokeWidth: 4,
                      backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
                    ),
                  ),
                  Text('$_seconds',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none)),
                ],
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

// ═══════ عرض عناصر الشاشة ═══════
class _ElementPickerSheet extends StatefulWidget {
  final List<ScreenElement> elements;
  final bool isDark;
  const _ElementPickerSheet({required this.elements, required this.isDark});

  @override
  State<_ElementPickerSheet> createState() => _ElementPickerSheetState();
}

class _ElementPickerSheetState extends State<_ElementPickerSheet> {
  static const _noDeco = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  late List<ScreenElement> _filtered;
  late TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _filtered = widget.elements;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  IconData _iconFor(ScreenElement e) {
    if (e.editable) return Icons.keyboard_rounded;
    if (e.clickable || e.clickableParent) return Icons.touch_app_rounded;
    if (e.hasText) return Icons.text_fields_rounded;
    return Icons.widgets_rounded;
  }

  Color _colorFor(ScreenElement e) {
    if (e.editable) return const Color(0xFF00D2FF);
    if (e.clickable) return const Color(0xFF00D68F);
    if (e.clickableParent) return const Color(0xFFFFB84D);
    if (e.hasText) return const Color(0xFF6C5CE7);
    return const Color(0xFF95A5A6);
  }

  String _typeLabelFor(ScreenElement e) {
    if (e.editable) return 'حقل كتابة';
    if (e.clickable) return 'قابل للضغط';
    if (e.clickableParent) return 'أب قابل للضغط';
    if (e.hasText) return 'نص';
    if (e.hasDesc) return 'وصف';
    if (e.hasId) return 'id';
    return 'عنصر';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 50, height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Text('عناصر الشاشة',
              style: _noDeco.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${widget.elements.length} عنصر',
              style: _noDeco.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              style: _noDeco.copyWith(fontSize: 15),
              onChanged: (q) {
                final s = q.trim().toLowerCase();
                setState(() {
                  _filtered = s.isEmpty
                      ? widget.elements
                      : widget.elements.where((e) =>
                          e.text.toLowerCase().contains(s) ||
                          e.desc.toLowerCase().contains(s) ||
                          e.id.toLowerCase().contains(s)).toList();
                });
              },
              decoration: InputDecoration(
                hintText: 'ابحث عن نص أو id…',
                hintStyle: _noDeco.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4)),
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text('مفيش نتائج',
                        style: _noDeco.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final e = _filtered[i];
                      final color = _colorFor(e);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context, e),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(_iconFor(e), color: color, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(_typeLabelFor(e),
                                                  style: _noDeco.copyWith(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: color)),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              e.className.split(".").last,
                                              style: _noDeco.copyWith(
                                                  fontSize: 9.5,
                                                  color: theme.colorScheme
                                                      .onSurface.withOpacity(0.4)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (e.hasText)
                                          Text(e.text,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: _noDeco.copyWith(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold)),
                                        if (e.hasDesc)
                                          Text('📝 ${e.desc}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: _noDeco.copyWith(
                                                  fontSize: 11,
                                                  color: theme.colorScheme
                                                      .onSurface.withOpacity(0.75))),
                                        if (e.hasId)
                                          Text('🏷 ${e.id}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: _noDeco.copyWith(
                                                  fontSize: 10.5,
                                                  color: theme.colorScheme.primary
                                                      .withOpacity(0.8))),
                                        Text(
                                          '(${e.x}, ${e.y}) • ${e.width}×${e.height}',
                                          style: _noDeco.copyWith(
                                              fontSize: 9.5,
                                              color: theme.colorScheme
                                                  .onSurface.withOpacity(0.35)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ═══════ قائمة التطبيقات ═══════
class _AppPickerSheet extends StatefulWidget {
  final bool isDark;
  const _AppPickerSheet({required this.isDark});

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  static const _noDeco = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  List<InstalledApp> _all = [];
  List<InstalledApp> _filtered = [];
  bool _loading = true;
  late TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await AutoFillBridge.listInstalledApps();
    if (!mounted) return;
    setState(() {
      _all = list;
      _filtered = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 50, height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Text('اختر تطبيق',
              style: _noDeco.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${_all.length} تطبيق مثبّت',
              style: _noDeco.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              style: _noDeco.copyWith(fontSize: 15),
              onChanged: (q) {
                final s = q.trim().toLowerCase();
                setState(() {
                  _filtered = s.isEmpty
                      ? _all
                      : _all.where((a) =>
                          a.name.toLowerCase().contains(s) ||
                          a.package.toLowerCase().contains(s)).toList();
                });
              },
              decoration: InputDecoration(
                hintText: 'ابحث باسم التطبيق…',
                hintStyle: _noDeco.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4)),
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text('مفيش نتائج',
                            style: _noDeco.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5))))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final app = _filtered[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.pop(context, app),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40, height: 40,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(Icons.android_rounded,
                                            color: theme.colorScheme.primary, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(app.name,
                                                style: _noDeco.copyWith(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 2),
                                            Text(app.package,
                                                style: _noDeco.copyWith(
                                                    fontSize: 10.5,
                                                    color: theme.colorScheme
                                                        .onSurface.withOpacity(0.5))),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.arrow_forward_ios_rounded,
                                          size: 12,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.3)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}