import 'package:flutter/material.dart';
import '../widgets.dart';
import '../autofill_bridge.dart';
import '../firebase/firestore_service.dart';
import '../pages/upload_script_sheet.dart';
import 'task_model.dart';
import 'task_pickers.dart';
import 'step_config_sheet.dart';

// ⭐ فلاج الأدمن
const bool IS_ADMIN_APP = bool.fromEnvironment(
  'IS_ADMIN',
  defaultValue: true,
);

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
  late int _taskRepeat;
  late bool _autoIncrement;
  late TextEditingController _taskRepeatCtrl;

  static const _noDeco = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.initialTask?.name ?? '');
    _steps = List.from(widget.initialTask?.steps ?? []);
    _taskRepeat = widget.initialTask?.repeatCount ?? 1;
    _autoIncrement = widget.initialTask?.autoIncrement ?? false;
    _taskRepeatCtrl = TextEditingController(text: _taskRepeat.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taskRepeatCtrl.dispose();
    super.dispose();
  }

  String _uid() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _addStep() async {
    final type = await showStepTypePicker(
      context,
      isDark: widget.isDark,
    );
    if (type == null || !mounted) return;

    final newStep = TaskStep(
      id: _uid(),
      type: type,
      params: {},
      waitAfterMs: 500,
    );

    final configured = await showStepConfigSheet(
      context,
      isDark: widget.isDark,
      step: newStep,
    );

    if (configured != null) {
      setState(() => _steps.add(configured));
    }
  }

  Future<void> _editStep(int index) async {
    final result = await showStepConfigSheet(
      context,
      isDark: widget.isDark,
      step: _steps[index],
    );
    if (result != null) {
      setState(() => _steps[index] = result);
    }
  }

  void _removeStep(int index) => setState(() => _steps.removeAt(index));

  void _toggleSpeed(int index) {
    setState(() {
      _steps[index] = _steps[index].copyWith(
        speedMode: !_steps[index].speedMode,
      );
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final s = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, s);
    });
  }

  void _showMsg(String msg, {bool error = true}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: error
                  ? const Color(0xFFFF6B6B)
                  : const Color(0xFF00D68F),
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

  Future<List<TaskStep>?> _resolvePackages() async {
    final fixedSteps = <TaskStep>[];
    for (final step in _steps) {
      if (step.type == TaskStepType.openApp ||
          step.type == TaskStepType.clearAppData) {
        final pkg = step.params['package']?.toString().trim() ?? '';
        if (pkg.isEmpty) {
          _showMsg(
            step.type == TaskStepType.openApp
                ? 'فيه خطوة "فتح تطبيق" مش محدّد فيها تطبيق'
                : 'فيه خطوة "مسح بيانات" مش محدّد فيها تطبيق',
          );
          return null;
        }
        final resolved = await AutoFillBridge.resolvePackage(pkg);
        if (resolved == null) {
          _showMsg('مش لاقي تطبيق "$pkg"');
          return null;
        }
        fixedSteps.add(step.copyWith(
          params: {...step.params, 'package': resolved},
        ));
      } else {
        fixedSteps.add(step);
      }
    }
    return fixedSteps;
  }

  // ⭐ حفظ محلي في Firestore
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showMsg('اكتب اسم المهمة الأول');
      return;
    }
    if (_steps.isEmpty) {
      _showMsg('ضيف خطوة على الأقل');
      return;
    }

    final fixedSteps = await _resolvePackages();
    if (fixedSteps == null) return;
    if (!mounted) return;

    final task = Task(
      id: widget.initialTask?.id ?? _uid(),
      name: name,
      steps: fixedSteps,
      createdAt: widget.initialTask?.createdAt ?? DateTime.now(),
      lastRunAt: widget.initialTask?.lastRunAt,
      repeatCount: _taskRepeat,
      autoIncrement: _autoIncrement,
    );

    await FirestoreService.saveAdminTask(task);
    if (mounted) Navigator.pop(context, task);
  }

  // ⭐⭐ رفع كسكربت — Update / New flow
  Future<void> _uploadAsScript() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showMsg('اكتب اسم المهمة الأول');
      return;
    }
    if (_steps.isEmpty) {
      _showMsg('ضيف خطوة على الأقل');
      return;
    }

    final fixedSteps = await _resolvePackages();
    if (fixedSteps == null) return;
    if (!mounted) return;

    final task = Task(
      id: widget.initialTask?.id ?? _uid(),
      name: name,
      steps: fixedSteps,
      createdAt: widget.initialTask?.createdAt ?? DateTime.now(),
      lastRunAt: widget.initialTask?.lastRunAt,
      repeatCount: _taskRepeat,
      autoIncrement: _autoIncrement,
    );
    await FirestoreService.saveAdminTask(task);

    // ⭐ ندور على سكربت بنفس الاسم
    final existing = await FirestoreService.getScriptByName(name);
    if (!mounted) return;

    final stepsJson = fixedSteps.map((s) => s.toJson()).toList();

    if (existing != null) {
      final choice = await _askUpdateOrNew(existing);
      if (choice == null) return;
      if (!mounted) return;

      if (choice == 'update') {
        await FirestoreService.updateScriptContent(
          scriptId: existing.id,
          steps: stepsJson,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تحديث السكربت — المستخدمين زي ما هم'),
            backgroundColor: Color(0xFF00D68F),
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, task);
        return;
      } else if (choice == 'new') {
        final newName = await _askNewName(name);
        if (newName == null || newName.isEmpty) return;
        if (!mounted) return;

        await FirestoreService.uploadScript(
          name: newName,
          steps: stepsJson,
          assignedTo: const [],
          createdBy: '',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم رفع "$newName" كسكربت جديد'),
            backgroundColor: const Color(0xFF00D68F),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, task);
        return;
      }
    } else {
      final uploaded = await showUploadScriptSheet(
        context,
        isDark: widget.isDark,
        task: task,
      );
      if (!mounted) return;
      if (uploaded == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم رفع السكربت'),
            backgroundColor: Color(0xFF00D68F),
          ),
        );
        Navigator.pop(context, task);
      }
    }
  }

  Future<String?> _askUpdateOrNew(ScriptDoc existing) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB84D).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.info_outline_rounded,
                  color: Color(0xFFFFB84D), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('سكربت بنفس الاسم موجود',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      decoration: TextDecoration.none)),
            ),
          ],
        ),
        content: Text(
          'فيه سكربت اسمه "${existing.name}" موجود بالفعل.\n'
          'الاسم ده مربوط بـ ${existing.assignedTo.length} مستخدم.\n\n'
          'عايز تحدّث المحتوى بتاعه، ولا تعمل واحد جديد باسم تاني؟',
          style: _noDeco.copyWith(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: _noDeco),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'new'),
            child: Text('إنشاء جديد',
                style: _noDeco.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00D2FF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'update'),
            child: Text('تحديث',
                style: _noDeco.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00D68F))),
          ),
        ],
      ),
    );
  }

  Future<String?> _askNewName(String suggested) async {
    final ctrl = TextEditingController(text: '$suggested - نسخة');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('اسم السكربت الجديد',
            style: _noDeco.copyWith(
                fontWeight: FontWeight.bold, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: _noDeco.copyWith(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'اسم جديد',
            hintStyle: _noDeco.copyWith(
                color: Theme.of(ctx)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.4)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: _noDeco),
          ),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(ctx, v);
            },
            child: Text('إنشاء',
                style: _noDeco.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00D68F))),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
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
                      widget.initialTask == null
                          ? 'مهمة جديدة'
                          : 'تعديل المهمة',
                      style: _noDeco.copyWith(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconBtn(
                    icon: Icons.settings_rounded,
                    onTap: () =>
                        AutoFillBridge.openAccessibilitySettings(),
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
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                style: _noDeco.copyWith(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'اسم المهمة',
                  hintText: 'مثال: افتح واتساب',
                  labelStyle: _noDeco.copyWith(
                      color: theme.colorScheme.onSurface
                          .withOpacity(0.6)),
                  hintStyle: _noDeco.copyWith(
                      color: theme.colorScheme.onSurface
                          .withOpacity(0.4)),
                  prefixIcon: const Icon(
                      Icons.drive_file_rename_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              _buildTaskLoopSection(theme),
              const SizedBox(height: 12),
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
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primary.withOpacity(0.2),
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
              const SizedBox(height: 8),
              Expanded(
                child:
                    _steps.isEmpty ? _emptyView(theme) : _stepsList(),
              ),
              const SizedBox(height: 10),
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
              if (IS_ADMIN_APP) ...[
                const SizedBox(height: 10),
                ActionBtn(
                  label: 'رفع كسكربت',
                  icon: Icons.cloud_upload_rounded,
                  gradient: const [
                    Color(0xFF6C5CE7),
                    Color(0xFF00D2FF),
                  ],
                  busy: false,
                  onTap: _uploadAsScript,
                ),
              ],
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Kageno',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.35),
                    fontSize: 10,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskLoopSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C5CE7).withOpacity(0.12),
            const Color(0xFF00D2FF).withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF6C5CE7).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.repeat_rounded,
                  size: 18, color: Color(0xFF6C5CE7)),
              const SizedBox(width: 6),
              Text(
                'تكرار المهمة كلها',
                style: _noDeco.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6C5CE7),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _taskRepeatCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: _noDeco.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6C5CE7),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v) ?? 1;
                    if (n >= 1) setState(() => _taskRepeat = n);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _taskRepeat == 1
                ? 'هتتنفذ مرة واحدة'
                : 'هتتنفذ $_taskRepeat مرة',
            style: _noDeco.copyWith(
              fontSize: 10.5,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (_taskRepeat > 1) ...[
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () =>
                    setState(() => _autoIncrement = !_autoIncrement),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _autoIncrement
                        ? const Color(0xFF00D68F).withOpacity(0.15)
                        : theme.colorScheme.surface.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _autoIncrement
                          ? const Color(0xFF00D68F)
                          : theme.colorScheme.primary
                              .withOpacity(0.15),
                      width: _autoIncrement ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _autoIncrement
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: _autoIncrement
                            ? const Color(0xFF00D68F)
                            : theme.colorScheme.onSurface
                                .withOpacity(0.4),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الرقم يتقدم مع كل دورة',
                          style: _noDeco.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _autoIncrement
                                ? const Color(0xFF00D68F)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add_rounded,
              size: 60,
              color: theme.colorScheme.primary.withOpacity(0.3)),
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
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _steps.length,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          elevation: 8,
          shadowColor: const Color(0xFF6C5CE7).withOpacity(0.4),
          borderRadius: BorderRadius.circular(18),
          child: child,
        );
      },
      itemBuilder: (context, i) => Padding(
        key: ValueKey(_steps[i].id),
        padding: const EdgeInsets.only(bottom: 10),
        child: _StepCard(
          index: i,
          total: _steps.length,
          step: _steps[i],
          isDark: widget.isDark,
          onEdit: () => _editStep(i),
          onDelete: () => _removeStep(i),
          onToggleSpeed: () => _toggleSpeed(i),
          dragIndex: i,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _StepCard
// ═══════════════════════════════════════════════════════════
class _StepCard extends StatelessWidget {
  final int index;
  final int total;
  final TaskStep step;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleSpeed;
  final int dragIndex;

  const _StepCard({
    required this.index,
    required this.total,
    required this.step,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSpeed,
    required this.dragIndex,
  });

  static const _noDeco = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  Color get _accent {
    switch (step.type) {
      case TaskStepType.openApp:
        return const Color(0xFF6C5CE7);
      case TaskStepType.wait:
        return const Color(0xFF95A5A6);
      case TaskStepType.typeText:
        return const Color(0xFF00D2FF);
      case TaskStepType.numberFromFile:
        return const Color(0xFF8E44AD);
      case TaskStepType.clickByText:
      case TaskStepType.clickByDesc:
      case TaskStepType.clickById:
        return const Color(0xFF00B894);
      case TaskStepType.clickAt:
        return const Color(0xFFFFB84D);
      case TaskStepType.waitForElement:
        return const Color(0xFFE17055);
      case TaskStepType.clearAppData:
        return const Color(0xFFFF6B6B);
      case TaskStepType.swipe:
        return const Color(0xFFFF8E53);
      case TaskStepType.swipeToFind:
        return const Color(0xFF9B59B6);
      case TaskStepType.back:
      case TaskStepType.home:
      case TaskStepType.recents:
        return const Color(0xFF34495E);
    }
  }

  IconData get _icon {
    switch (step.type) {
      case TaskStepType.openApp:
        return Icons.apps_rounded;
      case TaskStepType.wait:
        return Icons.hourglass_top_rounded;
      case TaskStepType.typeText:
        return Icons.keyboard_rounded;
      case TaskStepType.numberFromFile:
        return Icons.numbers_rounded;
      case TaskStepType.clickByText:
        return Icons.text_fields_rounded;
      case TaskStepType.clickByDesc:
        return Icons.description_rounded;
      case TaskStepType.clickById:
        return Icons.tag_rounded;
      case TaskStepType.clickAt:
        return Icons.my_location_rounded;
      case TaskStepType.waitForElement:
        return Icons.hourglass_bottom_rounded;
      case TaskStepType.clearAppData:
        return Icons.delete_sweep_rounded;
      case TaskStepType.swipe:
        return Icons.swipe_rounded;
      case TaskStepType.swipeToFind:
        return Icons.search_rounded;
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
    final accent =
        step.speedMode ? const Color(0xFFFFD93D) : _accent;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface
            .withOpacity(isDark ? 0.6 : 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withOpacity(0.35),
          width: step.speedMode ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(step.speedMode ? 0.15 : 0.08),
            blurRadius: step.speedMode ? 16 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(theme, accent),
                      const SizedBox(height: 8),
                      _buildBody(theme),
                      const SizedBox(height: 8),
                      _buildFooter(theme),
                    ],
                  ),
                ),
              ),
              _buildControls(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color accent) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, accent.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, color: Colors.white, size: 16),
              Text(
                '${index + 1}',
                style: _noDeco.copyWith(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    step.typeLabel,
                    style: _noDeco.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  if (step.speedMode) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFFFD93D).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded,
                              size: 11, color: Color(0xFFF39C12)),
                          const SizedBox(width: 2),
                          Text(
                            'سريع',
                            style: _noDeco.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF39C12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (step.hasLoop) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.repeat_rounded,
                        size: 10, color: Color(0xFF6C5CE7)),
                    const SizedBox(width: 3),
                    Text(
                      'يكرر ${step.repeatCount} مرات',
                      style: _noDeco.copyWith(
                        fontSize: 9.5,
                        color: const Color(0xFF6C5CE7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              if (step.onFail == FailureAction.skip &&
                  !step.isWaitStep) ...[
                const SizedBox(height: 2),
                Text(
                  'عند الفشل: تخطى ${step.skipCount + 1} خطوة',
                  style: _noDeco.copyWith(
                    fontSize: 9.5,
                    color: const Color(0xFFFFB84D),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (step.type) {
      case TaskStepType.openApp:
        return _appBody(theme, false);
      case TaskStepType.clearAppData:
        return _appBody(theme, true);
      case TaskStepType.wait:
        return _waitBody(theme);
      case TaskStepType.typeText:
        return _typeTextBody(theme);
      case TaskStepType.numberFromFile:
        return _typeTextBody(theme);
      case TaskStepType.clickByText:
      case TaskStepType.clickByDesc:
      case TaskStepType.clickById:
        return _clickBody(theme);
      case TaskStepType.clickAt:
        return _clickAtBody(theme);
      case TaskStepType.waitForElement:
        return _waitForElementBody(theme);
      case TaskStepType.swipe:
        return _swipeBody(theme);
      case TaskStepType.swipeToFind:
        return _swipeBody(theme);
      case TaskStepType.back:
      case TaskStepType.home:
      case TaskStepType.recents:
        return _navBody(theme);
    }
  }

  Widget _appBody(ThemeData theme, bool isClear) {
    final pkg = step.params['package']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isClear ? Icons.warning_amber_rounded : Icons.android_rounded,
            size: 14,
            color: _accent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              pkg.isEmpty ? '(بدون اسم)' : pkg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _noDeco.copyWith(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitBody(ThemeData theme) {
    final ms =
        int.tryParse(step.params['ms']?.toString() ?? '0') ?? 0;
    final sec = (ms / 1000).toStringAsFixed(ms % 1000 == 0 ? 0 : 1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          sec,
          style: _noDeco.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: _accent,
            height: 1,
          ),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'ثانية',
            style: _noDeco.copyWith(
              fontSize: 13,
              color: _accent.withOpacity(0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _typeTextBody(ThemeData theme) {
    final v = step.params['text']?.toString() ?? '';
    final id = step.params['viewId']?.toString() ?? '';
    final hint = step.params['hint']?.toString() ?? '';
    String target = '';
    if (id.isNotEmpty) {
      target = id.split('/').last;
    } else if (hint.isNotEmpty) {
      target = 'في "$hint"';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (v.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: _accent.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.keyboard_rounded,
                    size: 12, color: _accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    v,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _noDeco.copyWith(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (target.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.arrow_forward_rounded,
                  size: 11, color: _accent.withOpacity(0.6)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'في: $target',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _noDeco.copyWith(
                    fontSize: 10.5,
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _clickBody(ThemeData theme) {
    final t = step.params['text']?.toString() ?? '';
    final d = step.params['desc']?.toString() ?? '';
    final id = step.params['viewId']?.toString() ?? '';

    String label = '';
    String chipLabel = '';
    Color chipColor = _accent;

    if (t.isNotEmpty) {
      label = t;
      chipLabel = 'نص';
      chipColor = const Color(0xFF6C5CE7);
    } else if (d.isNotEmpty) {
      label = d;
      chipLabel = 'وصف';
      chipColor = const Color(0xFFFFB84D);
    } else if (id.isNotEmpty) {
      label = id.split('/').last;
      chipLabel = 'id';
      chipColor = const Color(0xFF00D2FF);
    } else {
      label = '(بدون هدف)';
      chipLabel = '؟';
    }

    return Row(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: chipColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            chipLabel,
            style: _noDeco.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: chipColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _noDeco.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _clickAtBody(ThemeData theme) {
    final x = step.params['x']?.toString() ?? '0';
    final y = step.params['y']?.toString() ?? '0';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.my_location_rounded, size: 16, color: _accent),
        const SizedBox(width: 6),
        Text(
          '($x, $y)',
          style: _noDeco.copyWith(
            fontSize: 15,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: _accent,
          ),
        ),
      ],
    );
  }

  Widget _waitForElementBody(ThemeData theme) {
    final t = step.params['text']?.toString() ?? '';
    final d = step.params['desc']?.toString() ?? '';
    final id = step.params['viewId']?.toString() ?? '';
    final appearText = step.appearText;

    String target = '';
    String chipLabel = '';
    Color chipColor = _accent;

    if (t.isNotEmpty) {
      target = t;
      chipLabel = 'نص';
      chipColor = const Color(0xFF6C5CE7);
    } else if (d.isNotEmpty) {
      target = d;
      chipLabel = 'وصف';
      chipColor = const Color(0xFFFFB84D);
    } else if (id.isNotEmpty) {
      target = id.split('/').last;
      chipLabel = 'id';
      chipColor = const Color(0xFF00D2FF);
    } else {
      target = '(بدون هدف)';
    }

    String appear = '';
    IconData appearIcon = Icons.check_circle_outline_rounded;
    if (step.onAppear == OnAppearAction.click) {
      appear = 'ثم اضغط عليه';
      appearIcon = Icons.touch_app_rounded;
    } else if (step.onAppear == OnAppearAction.type) {
      appear = 'ثم اكتب: $appearText';
      appearIcon = Icons.keyboard_rounded;
    }

    String notFoundLabel = '';
    Color notFoundColor = const Color(0xFFFF6B6B);
    switch (step.onNotFound) {
      case NotFoundAction.skip:
        notFoundLabel = 'لو ما ظهرش: تخطي';
        notFoundColor = const Color(0xFFFFB84D);
        break;
      case NotFoundAction.stop:
        notFoundLabel = 'لو ما ظهرش: وقف';
        break;
      case NotFoundAction.clickAlt:
        notFoundLabel = 'لو ما ظهرش: اضغط بديل';
        notFoundColor = const Color(0xFF00D2FF);
        break;
      case NotFoundAction.typeAlt:
        notFoundLabel = 'لو ما ظهرش: اكتب';
        notFoundColor = const Color(0xFF6C5CE7);
        break;
      case NotFoundAction.back:
        notFoundLabel = 'لو ما ظهرش: رجوع';
        notFoundColor = const Color(0xFFE17055);
        break;
      case NotFoundAction.home:
        notFoundLabel = 'لو ما ظهرش: الرئيسية';
        notFoundColor = const Color(0xFF95A5A6);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                chipLabel,
                style: _noDeco.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: chipColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                target,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _noDeco.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (appear.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(appearIcon, size: 11, color: _accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  appear,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _noDeco.copyWith(
                    fontSize: 10.5,
                    color: _accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.help_outline_rounded,
                size: 11, color: notFoundColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                notFoundLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _noDeco.copyWith(
                  fontSize: 10.5,
                  color: notFoundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _swipeBody(ThemeData theme) {
    if (step.type == TaskStepType.swipeToFind) {
      final target = step.params['targetText']?.toString() ?? '';
      final direction = step.params['direction']?.toString() ?? 'down';
      final x1 = step.params['x1']?.toString() ?? '0';
      final y1 = step.params['y1']?.toString() ?? '0';
      final dist = step.params['distance']?.toString() ?? '400';
      final dirLabel = direction == 'up' ? '⬆️ فوق' : '⬇️ تحت';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (target.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.search_rounded, size: 12, color: _accent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'دور على: $target',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _noDeco.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Icon(Icons.location_on_rounded,
                  size: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '($x1, $y1) • $dirLabel • $dist بكسل',
                  style: _noDeco.copyWith(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.75),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final x1 = step.params['x1']?.toString() ?? '0';
    final y1 = step.params['y1']?.toString() ?? '0';
    final x2 = step.params['x2']?.toString() ?? '0';
    final y2 = step.params['y2']?.toString() ?? '0';

    return Row(
      children: [
        Expanded(
          child: Text(
            '($x1, $y1)',
            style: _noDeco.copyWith(
              fontSize: 11,
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        Icon(Icons.arrow_forward_rounded, size: 14, color: _accent),
        Expanded(
          child: Text(
            '($x2, $y2)',
            textAlign: TextAlign.right,
            style: _noDeco.copyWith(
              fontSize: 11,
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _navBody(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        step.typeLabel,
        textAlign: TextAlign.center,
        style: _noDeco.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _accent,
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (step.waitAfterMs > 0)
          _chip(theme, Icons.hourglass_top_rounded,
              'انتظار ${step.waitAfterMs}م', const Color(0xFF95A5A6)),
        if (step.isSearchStep && step.timeoutMs > 0)
          _chip(
              theme,
              Icons.timer_rounded,
              'مهلة ${(step.timeoutMs / 1000).toStringAsFixed(0)}ث',
              const Color(0xFFFFB84D)),
        if (step.speedMode)
          _chip(theme, Icons.bolt_rounded, 'بحث سريع',
              const Color(0xFFF39C12)),
      ],
    );
  }

  Widget _chip(
      ThemeData theme, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: _noDeco.copyWith(
              fontSize: 9.5,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: dragIndex,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 6),
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 20,
                color: theme.colorScheme.primary.withOpacity(0.6),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onToggleSpeed,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: step.speedMode
                      ? const Color(0xFFFFD93D).withOpacity(0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: step.speedMode
                      ? Border.all(
                          color: const Color(0xFFFFD93D),
                          width: 1.2,
                        )
                      : null,
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: step.speedMode
                      ? const Color(0xFFF39C12)
                      : theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionBtn(
                icon: Icons.edit_rounded,
                color: const Color(0xFF00D2FF),
                onTap: onEdit,
              ),
              const SizedBox(width: 3),
              _actionBtn(
                icon: Icons.close_rounded,
                color: const Color(0xFFFF6B6B),
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}