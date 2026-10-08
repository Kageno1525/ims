import 'package:flutter/material.dart';
import '../widgets.dart';
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

  String _uid() =>
      DateTime.now().microsecondsSinceEpoch.toString();

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

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسم المهمة')),
      );
      return;
    }
    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ضيف خطوة على الأقل')),
      );
      return;
    }

    final task = Task(
      id: widget.initialTask?.id ?? _uid(),
      name: name,
      steps: _steps,
      createdAt: widget.initialTask?.createdAt ?? DateTime.now(),
      lastRunAt: widget.initialTask?.lastRunAt,
    );
    Navigator.pop(context, task);
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
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconBtn(
                    icon: widget.isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    onTap: widget.onToggleTheme,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم المهمة',
                  prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.list_alt_rounded,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('الخطوات (${_steps.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _steps.isEmpty
                    ? Center(
                        child: Text('مفيش خطوات — ضيف خطوة تحت',
                            style: TextStyle(
                                color:
                                    theme.colorScheme.onSurface.withOpacity(0.5))),
                      )
                    : ListView.separated(
                        itemCount: _steps.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _stepCard(theme, i),
                      ),
              ),
              const SizedBox(height: 10),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(widget.isDark ? 0.55 : 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('${i + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.typeLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                if (step.summary.isNotEmpty)
                  Text(step.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.6))),
                Text('انتظار: ${step.waitAfterMs} مللي',
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withOpacity(0.4))),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    onPressed: i == 0 ? null : () => _moveStep(i, -1),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    onPressed:
                        i == _steps.length - 1 ? null : () => _moveStep(i, 1),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.edit_rounded),
                    color: const Color(0xFF00D2FF),
                    onPressed: () => _editStep(i),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: const Color(0xFFFF6B6B),
                    onPressed: () => _removeStep(i),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════ اختيار نوع الخطوة ═══════
class _StepTypePicker extends StatelessWidget {
  final bool isDark;
  final Function(TaskStepType) onPick;
  const _StepTypePicker({required this.isDark, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <TaskStepType, IconData>{
      TaskStepType.openApp: Icons.apps_rounded,
      TaskStepType.typeText: Icons.keyboard_rounded,
      TaskStepType.clickByText: Icons.touch_app_rounded,
      TaskStepType.clickByDesc: Icons.description_rounded,
      TaskStepType.clickById: Icons.tag_rounded,
      TaskStepType.clickAt: Icons.my_location_rounded,
      TaskStepType.swipe: Icons.swipe_rounded,
      TaskStepType.wait: Icons.hourglass_top_rounded,
      TaskStepType.back: Icons.arrow_back_rounded,
      TaskStepType.home: Icons.home_rounded,
      TaskStepType.recents: Icons.view_carousel_rounded,
    };
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(16),
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
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.entries.map((e) {
              final label = TaskStep(
                      id: '', type: e.key, params: {}, waitAfterMs: 0)
                  .typeLabel;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onPick(e.key),
                  child: Container(
                    width: 100,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.surface.withOpacity(isDark ? 0.55 : 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.25)),
                    ),
                    child: Column(
                      children: [
                        Icon(e.value,
                            size: 26, color: theme.colorScheme.primary),
                        const SizedBox(height: 6),
                        Text(label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
  late Map<String, TextEditingController> _ctrls;
  late int _waitAfter;

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
        return ['text'];
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
        return 'اسم الحزمة (مثال: com.whatsapp)';
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
        return 'المدة (مللي ثانية)';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.step.typeLabel;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ..._ctrls.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: e.value,
                      keyboardType:
                          int.tryParse(e.value.text) != null
                              ? TextInputType.number
                              : TextInputType.text,
                      decoration: InputDecoration(labelText: _labelFor(e.key)),
                    ),
                  )),
              const SizedBox(height: 4),
              Text('الانتظار بعد الخطوة: $_waitAfter مللي',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              Slider(
                value: _waitAfter.toDouble(),
                min: 0,
                max: 5000,
                divisions: 50,
                label: '$_waitAfter',
                onChanged: (v) =>
                    setState(() => _waitAfter = v.round()),
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