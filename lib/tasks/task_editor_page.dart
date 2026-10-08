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
            Text(error ? 'خطأ' : 'تمام',
                style: _noDeco.copyWith(
                    fontWeight: FontWeight.bold, fontSize: 16)),
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

    // ⭐ تحقق من كل خطوات فتح التطبيق
    final fixedSteps = <TaskStep>[];
    for (final step in _steps) {
      if (step.type == TaskStepType.openApp) {
        final pkg = step.params['package']?.toString().trim() ?? '';
        if (pkg.isEmpty) {
          _showMsg('فيه خطوة "فتح تطبيق" مش محدّد فيها أي تطبيق');
          return;
        }
        // لو مش باكدج صريح (مش فيه نقطة)، دوّر عليه بالاسم
        if (!pkg.contains('.')) {
          final resolved = await AutoFillBridge.resolvePackage(pkg);
          if (resolved == null) {
            _showMsg('مش لاقي تطبيق اسمه "$pkg". اختاره من القائمة.');
            return;
          }
          fixedSteps.add(step.copyWith(
            params: {...step.params, 'package': resolved},
          ));
        } else {
          // تأكد إن الباكدج موجود
          final resolved = await AutoFillBridge.resolvePackage(pkg);
          if (resolved == null) {
            _showMsg('مفيش تطبيق بالباكدج "$pkg" على الجهاز');
            return;
          }
          fixedSteps.add(step.copyWith(
            params: {...step.params, 'package': resolved},
          ));
        }
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
                  Text('الخطوات',
                      style: _noDeco.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
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
                                color: theme.colorScheme.primary
                                    .withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text('مفيش خطوات',
                                style: _noDeco.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('اضغط "إضافة خطوة" وابدأ',
                                style: _noDeco.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.4),
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_iconFor(step.type), color: Colors.white, size: 18),
                const SizedBox(height: 1),
                Text('${i + 1}',
                    style: _noDeco.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
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
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: colors.first,
                    )),
                if (step.summary.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(step.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _noDeco.copyWith(
                          fontSize: 12,
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.75))),
                ],
                const SizedBox(height: 2),
                Text('انتظار: ${step.waitAfterMs} مللي',
                    style: _noDeco.copyWith(
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.45))),
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
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('اختر نوع الخطوة',
                textAlign: TextAlign.center,
                style: _noDeco.copyWith(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: items.map((t) {
                final label = TaskStep(
                        id: '', type: t, params: {}, waitAfterMs: 0)
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
                            color:
                                theme.colorScheme.primary.withOpacity(0.25)),
                      ),
                      child: Column(
                        children: [
                          Icon(_iconFor(t),
                              size: 26, color: theme.colorScheme.primary),
                          const SizedBox(height: 6),
                          Text(label,
                              textAlign: TextAlign.center,
                              style: _noDeco.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
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
  late int _waitAfter;
  String? _selectedAppName;

  @override
  void initState() {
    super.initState();
    _ctrls = {};
    _waitAfter = widget.step.waitAfterMs;

    final keys = _fieldKeysFor(widget.step.type);
    for (final k in keys) {
      _ctrls[k] = TextEditingController(
        text: widget.step.params[k]?.toString() ??
            _defaultValueFor(widget.step.type, k),
      );
    }
  }

  List<String> _fieldKeysFor(TaskStepType t) {
    switch (t) {
      case TaskStepType.openApp:
        return ['package'];
      case TaskStepType.typeText:
      case TaskStepType.clickByText:
        return ['text'];
      case TaskStepType.clickByDesc:
        return ['desc'];
      case TaskStepType.clickById:
        return ['viewId'];
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
    return '';
  }

  String _labelFor(String key) {
    switch (key) {
      case 'package':
        return 'اسم التطبيق';
      case 'text':
        return 'النص';
      case 'desc':
        return 'الوصف (Content Description)';
      case 'viewId':
        return 'الـ view id';
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

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.step.typeLabel;
    final isOpenApp = widget.step.type == TaskStepType.openApp;
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
              Text(label,
                  textAlign: TextAlign.center,
                  style: _noDeco.copyWith(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // لو الخطوة openApp - زرار اختيار التطبيق
              if (isOpenApp) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickApp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: currentPkg.isEmpty
                            ? theme.colorScheme.primary.withOpacity(0.15)
                            : theme.colorScheme.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                theme.colorScheme.primary.withOpacity(0.35)),
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
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.5))),
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

                // حقل الباكدج - بس عشان يشوفه
                TextField(
                  controller: _ctrls['package'],
                  style: _noDeco.copyWith(fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'اسم الحزمة (أو اختار من فوق)',
                    labelStyle: _noDeco.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    hintStyle: _noDeco.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4)),
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
                            ? TextInputType.number
                            : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: _labelFor(e.key),
                          labelStyle: _noDeco.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6)),
                          hintStyle: _noDeco.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.4)),
                        ),
                      ),
                    )),

              const SizedBox(height: 4),
              Text('الانتظار بعد الخطوة: $_waitAfter مللي',
                  style: _noDeco.copyWith(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              Slider(
                value: _waitAfter.toDouble(),
                min: 0,
                max: 5000,
                divisions: 50,
                label: '$_waitAfter',
                onChanged: (v) => setState(() => _waitAfter = v.round()),
              ),
              const SizedBox(height: 8),
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
                      params: params,
                      waitAfterMs: _waitAfter,
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
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Text('اختر تطبيق',
              style: _noDeco.copyWith(
                  fontSize: 20, fontWeight: FontWeight.bold)),
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
                        child: Text('مفيش نتائج',
                            style: _noDeco.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5))))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final app = _filtered[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 3),
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
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(Icons.android_rounded,
                                            color: theme.colorScheme.primary,
                                            size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(app.name,
                                                style: _noDeco.copyWith(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 2),
                                            Text(app.package,
                                                style: _noDeco.copyWith(
                                                    fontSize: 10.5,
                                                    color: theme.colorScheme
                                                        .onSurface
                                                        .withOpacity(0.5))),
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