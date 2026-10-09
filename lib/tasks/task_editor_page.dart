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
      case TaskStepType.openApp:
        return Icons.apps_rounded;
      case TaskStepType.typeText:
        return Icons.keyboard_rounded;
      case TaskStepType.clickByText:
        return Icons.touch_app_rounded;
      case TaskStepType.clickByDesc:
        return Icons.description_rounded;
      case TaskStepType.clickById:
        return Icons.tag_rounded;
      case TaskStepType.clickAt:
        return Icons.my_location_rounded;
      case TaskStepType.waitForElement:
        return Icons.hourglass_bottom_rounded;
      case TaskStepType.swipe:
        return Icons.swipe_rounded;
      case TaskStepType.wait:
        return Icons.hourglass_top_rounded;
      case TaskStepType.back:
        return Icons.arrow_back_rounded;
      case TaskStepType.home:
        return Icons.home_rounded;
      case TaskStepType.recents:
        return Icons.view_carousel_rounded;
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
      case TaskStepType.waitForElement:
        return const [Color(0xFFE17055), Color(0xFFFF8A65)];
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
          Navigator.pop(
            ctx,
            TaskStep(id: _uid(), type: type, params: {}, waitAfterMs: 500),
          );
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
    if (configured != null) {
      setState(() => _steps.add(configured));
    }
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
    if (result != null) {
      setState(() => _steps[index] = result);
    }
  }

  void _removeStep(int index) {
    setState(() => _steps.removeAt(index));
  }

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
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: error ? const Color(0xFFFF6B6B) : const Color(0xFF00D68F),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              error ? 'خطأ' : 'تمام',
              style: _noDeco.copyWith(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
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
    if (name.isEmpty) {
      _showMsg('من فضلك اكتب اسم المهمة الأول');
      return;
    }
    if (_steps.isEmpty) {
      _showMsg('ضيف خطوة على الأقل قبل الحفظ');
      return;
    }

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
          _showMsg('مش لاقي تطبيق "$pkg"');
          return;
        }
        fixedSteps.add(step.copyWith(
          params: {...step.params, 'package': resolved},
        ));
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
                  IconBtn(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.initialTask == null ? 'مهمة جديدة' : 'تعديل المهمة',
                      style: _noDeco.copyWith(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconBtn(
                    icon: Icons.settings_rounded,
                    onTap: () => AutoFillBridge.openAccessibilitySettings(),
                  ),
                  const SizedBox(width: 4),
                  IconBtn(
                    icon: widget.isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
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
                  labelStyle: _noDeco.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  hintStyle: _noDeco.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  prefixIcon:
                      const Icon(Icons.drive_file_rename_outline_rounded),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.list_alt_rounded,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'الخطوات',
                    style: _noDeco.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_steps.length}',
                      style: _noDeco.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _steps.isEmpty ? _emptyView(theme) : _stepsList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ActionBtn(
                      label: 'إضافة خطوة',
                      icon: Icons.add_rounded,
                      gradient: const [
                        Color(0xFF00D2FF),
                        Color(0xFF3A7BD5)
                      ],
                      busy: false,
                      onTap: _addStep,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActionBtn(
                      label: 'حفظ',
                      icon: Icons.save_rounded,
                      gradient: const [
                        Color(0xFF00B894),
                        Color(0xFF00D68F)
                      ],
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

  Widget _emptyView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add_rounded,
              size: 60, color: theme.colorScheme.primary.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(
            'مفيش خطوات',
            style: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'اضغط "إضافة خطوة" وابدأ',
            style: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepsList() {
    return ListView.separated(
      itemCount: _steps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _stepCard(Theme.of(context), i),
    );
  }

  Widget _stepCard(ThemeData theme, int i) {
    final step = _steps[i];
    final colors = _colorFor(step.type);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surface.withOpacity(widget.isDark ? 0.6 : 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.first.withOpacity(0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_iconFor(step.type), color: Colors.white, size: 18),
                const SizedBox(height: 1),
                Text(
                  '${i + 1}',
                  style: _noDeco.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.typeLabel,
                  style: _noDeco.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colors.first,
                  ),
                ),
                if (step.summary.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    step.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _noDeco.copyWith(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.75),
                    ),
                  ),
                ],
                Row(
                  children: [
                    Text(
                      'انتظار: ${step.waitAfterMs}م',
                      style: _noDeco.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withOpacity(0.45),
                      ),
                    ),
                    if (step.isSearchStep && step.timeoutMs > 0) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.timer_rounded,
                          size: 10,
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.45)),
                      const SizedBox(width: 2),
                      Text(
                        '${step.timeoutMs}م',
                        style: _noDeco.copyWith(
                          fontSize: 10,
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ],
                    if (step.onFail == FailureAction.skip) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.skip_next_rounded,
                          size: 10, color: Color(0xFFFFB84D)),
                      if (step.skipCount > 0) ...[
                        const SizedBox(width: 2),
                        Text(
                          '×${step.skipCount + 1}',
                          style: _noDeco.copyWith(
                            fontSize: 10,
                            color: const Color(0xFFFFB84D),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                    onTap:
                        i == _steps.length - 1 ? null : () => _moveStep(i, 1),
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
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? color.withOpacity(0.25) : color,
          ),
        ),
      ),
    );
  }
}

// ═══════════ اختيار نوع الخطوة ═══════════
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
      case TaskStepType.openApp:
        return Icons.apps_rounded;
      case TaskStepType.typeText:
        return Icons.keyboard_rounded;
      case TaskStepType.clickByText:
        return Icons.touch_app_rounded;
      case TaskStepType.clickByDesc:
        return Icons.description_rounded;
      case TaskStepType.clickById:
        return Icons.tag_rounded;
      case TaskStepType.clickAt:
        return Icons.my_location_rounded;
      case TaskStepType.waitForElement:
        return Icons.hourglass_bottom_rounded;
      case TaskStepType.swipe:
        return Icons.swipe_rounded;
      case TaskStepType.wait:
        return Icons.hourglass_top_rounded;
      case TaskStepType.back:
        return Icons.arrow_back_rounded;
      case TaskStepType.home:
        return Icons.home_rounded;
      case TaskStepType.recents:
        return Icons.view_carousel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'اختر نوع الخطوة',
              textAlign: TextAlign.center,
              style: _noDeco.copyWith(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: TaskStepType.values.map((t) {
                final label =
                    TaskStep(id: '', type: t, params: {}, waitAfterMs: 0)
                        .typeLabel;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onPick(t),
                    child: Container(
                      width: 100,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface
                            .withOpacity(isDark ? 0.6 : 0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(_iconFor(t),
                              size: 26, color: theme.colorScheme.primary),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: _noDeco.copyWith(
                                fontSize: 11, fontWeight: FontWeight.w600),
                          ),
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

// ═══════════ إعدادات الخطوة ═══════════
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
  late TaskStepType _currentType;
  late int _waitAfter;
  late int _timeoutMs;
  late FailureAction _onFail;
  late int _skipCount;
  late TextEditingController _timeoutCtrl;
  late TextEditingController _skipCountCtrl;
  String? _selectedAppName;
  String? _lastHint;

  @override
  void initState() {
    super.initState();
    _ctrls = {};
    _currentType = widget.step.type;
    _waitAfter = widget.step.waitAfterMs;
    _timeoutMs = widget.step.timeoutMs;
    _onFail = widget.step.onFail;
    _skipCount = widget.step.skipCount;
    _timeoutCtrl = TextEditingController(text: _timeoutMs.toString());
    _skipCountCtrl = TextEditingController(text: _skipCount.toString());

    final keys = _fieldKeysFor(_currentType);
    for (final k in keys) {
      _ctrls[k] = TextEditingController(
        text: widget.step.params[k]?.toString() ??
            _defaultValueFor(_currentType, k),
      );
    }
  }

  List<String> _fieldKeysFor(TaskStepType t) {
    switch (t) {
      case TaskStepType.openApp:
        return ['package'];
      case TaskStepType.typeText:
        return ['text', 'viewId', 'hint', 'className', 'elementIndex'];
      case TaskStepType.clickByText:
      case TaskStepType.clickByDesc:
      case TaskStepType.clickById:
      case TaskStepType.waitForElement:
        return ['text', 'desc', 'viewId', 'className', 'elementIndex'];
      case TaskStepType.clickAt:
        return ['x', 'y'];
      case TaskStepType.swipe:
        return ['x1', 'y1', 'x2', 'y2', 'duration'];
      case TaskStepType.wait:
        return ['ms'];
      default:
        return [];
    }
  }

  String _defaultValueFor(TaskStepType t, String key) {
    if (t == TaskStepType.wait && key == 'ms') return '1000';
    if (t == TaskStepType.swipe && key == 'duration') return '300';
    if (key == 'elementIndex') return '0';
    return '';
  }

  String _labelFor(String key) {
    switch (key) {
      case 'package':
        return 'اسم الحزمة';
      case 'text':
        return 'النص / القيمة';
      case 'desc':
        return 'الوصف (content description)';
      case 'viewId':
        return 'الـ id';
      case 'hint':
        return 'نص الإرشاد (hint)';
      case 'className':
        return 'نوع العنصر (className)';
      case 'elementIndex':
        return 'الترتيب (0 = الأول)';
      case 'x':
        return 'X';
      case 'y':
        return 'Y';
      case 'x1':
        return 'X البداية';
      case 'y1':
        return 'Y البداية';
      case 'x2':
        return 'X النهاية';
      case 'y2':
        return 'Y النهاية';
      case 'duration':
      case 'ms':
        return 'المدة (مللي ثانية)';
      default:
        return key;
    }
  }

  bool _isTextField(String key) {
    return key == 'text' ||
        key == 'desc' ||
        key == 'hint' ||
        key == 'viewId' ||
        key == 'className';
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _timeoutCtrl.dispose();
    _skipCountCtrl.dispose();
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

  Future<void> _inspectScreen() async {
    final captured = await showDialog<List<ScreenElement>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CountdownDialog(),
    );

    if (captured == null || captured.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('مفيش عناصر. تأكد من Accessibility.')),
        );
      }
      return;
    }
    if (!mounted) return;

    final picked = await showModalBottomSheet<ScreenElement>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          _ElementPickerSheet(elements: captured, isDark: widget.isDark),
    );
    if (picked == null) return;

    int sameIdx = 0;
    for (final e in captured) {
      if (identical(e, picked)) break;
      if (e.sameSpecs(picked)) sameIdx++;
    }

    _applyPickedElement(picked, sameIdx);
  }

  void _applyPickedElement(ScreenElement picked, int sameIdx) {
    if (_currentType == TaskStepType.typeText) {
      setState(() {
        if (picked.hasId) _ctrls['viewId']?.text = picked.id;
        if (picked.hasHint) _ctrls['hint']?.text = picked.hint;
        if (picked.shortClassName.isNotEmpty) {
          _ctrls['className']?.text = picked.shortClassName;
        }
        _ctrls['elementIndex']?.text = sameIdx.toString();
        _lastHint = 'الكتابة في: ${picked.bestLabel}';
      });
      return;
    }

    TaskStepType newType = _currentType;

    if (_currentType == TaskStepType.clickByText && !picked.hasText) {
      if (picked.hasDesc) {
        newType = TaskStepType.clickByDesc;
      } else if (picked.hasId) {
        newType = TaskStepType.clickById;
      } else {
        newType = TaskStepType.clickAt;
      }
    } else if (_currentType == TaskStepType.clickByDesc && !picked.hasDesc) {
      if (picked.hasText) {
        newType = TaskStepType.clickByText;
      } else if (picked.hasId) {
        newType = TaskStepType.clickById;
      } else {
        newType = TaskStepType.clickAt;
      }
    } else if (_currentType == TaskStepType.clickById && !picked.hasId) {
      if (picked.hasText) {
        newType = TaskStepType.clickByText;
      } else if (picked.hasDesc) {
        newType = TaskStepType.clickByDesc;
      } else {
        newType = TaskStepType.clickAt;
      }
    }

    final keys = _fieldKeysFor(newType);
    final newCtrls = <String, TextEditingController>{};
    for (final k in keys) {
      String v = '';
      if (k == 'text') {
        v = picked.text;
      } else if (k == 'desc') {
        v = picked.desc;
      } else if (k == 'viewId') {
        v = picked.id;
      } else if (k == 'className') {
        v = picked.shortClassName;
      } else if (k == 'elementIndex') {
        v = sameIdx.toString();
      } else if (k == 'x') {
        v = picked.x.toString();
      } else if (k == 'y') {
        v = picked.y.toString();
      }
      newCtrls[k] = TextEditingController(text: v);
    }

    final wasChanged = newType != _currentType;
    setState(() {
      for (final c in _ctrls.values) {
        c.dispose();
      }
      _ctrls = newCtrls;
      _currentType = newType;
      if (wasChanged) {
        _lastHint =
            'تم تغيير النوع تلقائياً لـ ${TaskStep(id: '', type: newType, params: {}, waitAfterMs: 0).typeLabel}';
      } else {
        _lastHint = 'تم اختيار: ${picked.bestLabel}';
      }
    });
  }

  bool get _canInspect {
    switch (_currentType) {
      case TaskStepType.clickByText:
      case TaskStepType.clickByDesc:
      case TaskStepType.clickById:
      case TaskStepType.clickAt:
      case TaskStepType.typeText:
      case TaskStepType.waitForElement:
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
      case TaskStepType.waitForElement:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        TaskStep(id: '', type: _currentType, params: {}, waitAfterMs: 0)
            .typeLabel;
    final isOpenApp = _currentType == TaskStepType.openApp;
    final currentPkg = _ctrls['package']?.text ?? '';

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                textAlign: TextAlign.center,
                style: _noDeco.copyWith(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              if (_canInspect) _buildInspectButton(),
              if (_lastHint != null) ...[
                const SizedBox(height: 10),
                _buildHintBox(),
              ],
              if (isOpenApp) ...[
                const SizedBox(height: 14),
                _buildAppPicker(theme, currentPkg),
                const SizedBox(height: 14),
                TextField(
                  controller: _ctrls['package'],
                  style: _noDeco.copyWith(fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'اسم الحزمة (أو اختار من فوق)',
                    labelStyle: _noDeco.copyWith(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.6)),
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                ),
              ],
              if (!isOpenApp) ...[
                const SizedBox(height: 14),
                ..._buildFieldWidgets(theme),
              ],
              const SizedBox(height: 12),
              Text(
                'الانتظار بعد الخطوة: $_waitAfter مللي',
                style: _noDeco.copyWith(
                    fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _waitAfter.toDouble(),
                min: 0,
                max: 5000,
                divisions: 50,
                label: '$_waitAfter',
                onChanged: (v) => setState(() => _waitAfter = v.round()),
              ),
              if (_isSearchStep) ..._buildTimeoutSection(theme),
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
                      skipCount: _skipCount,
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

  Widget _buildInspectButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _inspectScreen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
            ),
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
                    Text(
                      'التقاط الشاشة',
                      style: _noDeco.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'يتملأ كل الحقول تلقائياً',
                      style: _noDeco.copyWith(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHintBox() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF00D68F).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00D68F).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF00D68F), size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _lastHint!,
              style: _noDeco.copyWith(
                  fontSize: 11, color: const Color(0xFF00D68F)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppPicker(ThemeData theme, String currentPkg) {
    return Material(
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
            border:
                Border.all(color: theme.colorScheme.primary.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.apps_rounded,
                  color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentPkg.isEmpty
                          ? 'اضغط لاختيار تطبيق'
                          : (_selectedAppName ?? 'تطبيق مختار'),
                      style: _noDeco.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (currentPkg.isNotEmpty)
                      Text(
                        currentPkg,
                        style: _noDeco.copyWith(
                          fontSize: 10.5,
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFieldWidgets(ThemeData theme) {
    final widgets = <Widget>[];
    for (final entry in _ctrls.entries) {
      if (entry.key == 'elementIndex') continue;
      widgets.add(_buildField(theme, entry.key, entry.value));
    }
    if (_ctrls.containsKey('elementIndex')) {
      widgets.add(const SizedBox(height: 4));
      widgets.add(_buildIndexField(theme));
    }
    return widgets;
  }

  Widget _buildField(
      ThemeData theme, String key, TextEditingController ctrl) {
    final isNumeric = key == 'x' ||
        key == 'y' ||
        key == 'x1' ||
        key == 'y1' ||
        key == 'x2' ||
        key == 'y2' ||
        key == 'duration' ||
        key == 'ms';

    final isVariable = _isTextField(key);
    final hintText = isVariable
        ? 'يدعم: {num} = الرقم الحالي • {num:0} = أول رقم • {date} • {time}'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            style: _noDeco.copyWith(fontSize: 15),
            keyboardType:
                isNumeric ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              labelText: _labelFor(key),
              labelStyle: _noDeco.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6)),
              helperText: hintText,
              helperStyle: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
              helperMaxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexField(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list_rounded,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ترتيب العنصر',
                  style: _noDeco.copyWith(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  'لو فيه عناصر متشابهة، 0 = الأول',
                  style: _noDeco.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _ctrls['elementIndex'],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: _noDeco.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTimeoutSection(ThemeData theme) {
    return [
      const SizedBox(height: 4),
      Divider(color: theme.colorScheme.primary.withOpacity(0.15)),
      const SizedBox(height: 8),
      Row(
        children: [
          Icon(Icons.timer_rounded,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'مهلة الانتظار',
            style: _noDeco.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const Spacer(),
          Text(
            _timeoutMs == 0 ? 'بدون' : '${(_timeoutMs / 1000).toStringAsFixed(1)}ث',
            style: _noDeco.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: Slider(
              value: _timeoutMs.toDouble().clamp(0, 120000),
              min: 0,
              max: 120000,
              divisions: 120,
              label: _timeoutMs == 0
                  ? 'بدون'
                  : '${(_timeoutMs / 1000).toStringAsFixed(0)}ث',
              onChanged: (v) {
                setState(() {
                  _timeoutMs = v.round();
                  _timeoutCtrl.text = _timeoutMs.toString();
                });
              },
            ),
          ),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _timeoutCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: _noDeco.copyWith(
                  fontSize: 14, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                suffixText: 'مللي',
                suffixStyle: TextStyle(fontSize: 10),
              ),
              onChanged: (v) {
                final n = int.tryParse(v) ?? 0;
                if (n >= 0) {
                  setState(() {
                    _timeoutMs = n;
                  });
                }
              },
            ),
          ),
        ],
      ),
      Text(
        _timeoutMs == 0
            ? 'هيتم تنفيذ الخطوة مرة واحدة بس'
            : 'هيفضل يدوّر لحد ${(_timeoutMs / 1000).toStringAsFixed(1)} ثانية',
        style: _noDeco.copyWith(
          fontSize: 10,
          color: theme.colorScheme.onSurface.withOpacity(0.55),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'لو فشلت الخطوة',
            style: _noDeco.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
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
              onTap: () =>
                  setState(() => _onFail = FailureAction.stop),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionChoice(
              theme,
              label: 'تخطى',
              icon: Icons.skip_next_rounded,
              selected: _onFail == FailureAction.skip,
              color: const Color(0xFFFFB84D),
              onTap: () =>
                  setState(() => _onFail = FailureAction.skip),
            ),
          ),
        ],
      ),
      if (_onFail == FailureAction.skip) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFFFB84D).withOpacity(0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.skip_next_rounded,
                  size: 16, color: Color(0xFFFFB84D)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عدد الخطوات الإضافية للتخطي',
                      style: _noDeco.copyWith(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '0 = تخطى الخطوة دي بس',
                      style: _noDeco.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _skipCountCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: _noDeco.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFB84D),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v) ?? 0;
                    if (n >= 0) {
                      setState(() => _skipCount = n);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ];
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
            color: selected
                ? color.withOpacity(0.2)
                : theme.colorScheme.surface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color
                  : theme.colorScheme.primary.withOpacity(0.15),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? color
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: _noDeco.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? color
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════ Countdown Dialog ═══════════
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
        setState(() {
          _seconds = 0;
          _capturing = true;
        });
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
          const Icon(Icons.screen_share_rounded,
              size: 50, color: Color(0xFF6C5CE7)),
          const SizedBox(height: 14),
          Text(
            _capturing ? 'جاري الالتقاط…' : 'هيتم الالتقاط بعد $_seconds',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _capturing ? 'من فضلك استنى' : 'اسرع! روح للتطبيق',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              decoration: TextDecoration.none,
            ),
          ),
          if (!_capturing) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: _seconds / 5,
                      strokeWidth: 4,
                      backgroundColor:
                          theme.colorScheme.onSurface.withOpacity(0.1),
                    ),
                  ),
                  Text(
                    '$_seconds',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
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

// ═══════════ Element Picker ═══════════
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
  bool _onlyInteractive = false;

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

  void _applyFilter() {
    final s = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = widget.elements.where((e) {
        if (_onlyInteractive && !e.isInteractive) return false;
        if (s.isEmpty) return true;
        return e.text.toLowerCase().contains(s) ||
            e.desc.toLowerCase().contains(s) ||
            e.id.toLowerCase().contains(s) ||
            e.hint.toLowerCase().contains(s);
      }).toList();
    });
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
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'عناصر الشاشة',
            style: _noDeco.copyWith(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${_filtered.length} من ${widget.elements.length}',
            style: _noDeco.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              style: _noDeco.copyWith(fontSize: 15),
              onChanged: (_) => _applyFilter(),
              decoration: InputDecoration(
                hintText: 'ابحث…',
                prefixIcon: const Icon(Icons.search_rounded),
                hintStyle: _noDeco.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: Text(
                    'عناصر قابلة للضغط فقط',
                    style: _noDeco.copyWith(fontSize: 11),
                  ),
                  selected: _onlyInteractive,
                  onSelected: (v) {
                    setState(() => _onlyInteractive = v);
                    _applyFilter();
                  },
                  backgroundColor:
                      theme.colorScheme.surface.withOpacity(0.5),
                  selectedColor:
                      theme.colorScheme.primary.withOpacity(0.3),
                  checkmarkColor: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'مفيش نتائج',
                      style: _noDeco.copyWith(
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) =>
                        _buildElementTile(theme, _filtered[i]),
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildElementTile(ThemeData theme, ScreenElement e) {
    final color = _colorFor(e);

    int sameIdx = 0;
    for (final x in widget.elements) {
      if (identical(x, e)) break;
      if (x.sameSpecs(e)) sameIdx++;
    }

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
                  width: 40,
                  height: 40,
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
                            child: Text(
                              _typeLabelFor(e),
                              style: _noDeco.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            e.shortClassName,
                            style: _noDeco.copyWith(
                              fontSize: 9.5,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.4),
                            ),
                          ),
                          if (sameIdx > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB84D)
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$sameIdx',
                                style: _noDeco.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFB84D),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (e.hasText)
                        Text(
                          e.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _noDeco.copyWith(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      if (e.hasDesc)
                        Text(
                          '📝 ${e.desc}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _noDeco.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.75),
                          ),
                        ),
                      if (e.hasHint && !e.hasText)
                        Text(
                          '💡 ${e.hint}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _noDeco.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      if (e.hasId)
                        Text(
                          '🏷 ${e.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _noDeco.copyWith(
                            fontSize: 10.5,
                            color:
                                theme.colorScheme.primary.withOpacity(0.8),
                          ),
                        ),
                      Text(
                        '(${e.x}, ${e.y}) • ${e.width}×${e.height}',
                        style: _noDeco.copyWith(
                          fontSize: 9.5,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.35),
                        ),
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
  }
}

// ═══════════ App Picker ═══════════
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
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'اختر تطبيق',
            style: _noDeco.copyWith(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${_all.length} تطبيق مثبّت',
            style: _noDeco.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
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
                      : _all
                          .where((a) =>
                              a.name.toLowerCase().contains(s) ||
                              a.package.toLowerCase().contains(s))
                          .toList();
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
                        child: Text(
                          'مفيش نتائج',
                          style: _noDeco.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) =>
                            _buildAppTile(theme, _filtered[i]),
                      ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildAppTile(ThemeData theme, InstalledApp app) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context, app),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
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
                      Text(
                        app.name,
                        style: _noDeco.copyWith(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.package,
                        style: _noDeco.copyWith(
                          fontSize: 10.5,
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}