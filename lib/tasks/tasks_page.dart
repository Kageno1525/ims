import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets.dart';
import '../autofill_bridge.dart';
import '../firebase/firestore_service.dart';
import '../pages/upload_script_sheet.dart';
import 'task_model.dart';
import 'task_editor_page.dart';
import 'task_runner.dart';

// ⭐ فلاج الأدمن
const bool IS_ADMIN_APP = bool.fromEnvironment(
  'IS_ADMIN',
  defaultValue: true,
);

class TasksPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onBack;
  final Function(LogEntry) onLog;
  final List<String> currentNumbers;
  final int currentCsvIndex;

  const TasksPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onBack,
    required this.onLog,
    this.currentNumbers = const [],
    this.currentCsvIndex = 0,
  });

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with WidgetsBindingObserver {
  static const _noDeco = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  bool _accessibilityOn = false;
  Task? _runningTask;
  final TaskRunner _runner = TaskRunner();
  final ValueNotifier<List<LogEntry>> _logs =
      ValueNotifier<List<LogEntry>>(<LogEntry>[]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccessibility();
    _runner.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _runner.dispose();
    _logs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibility();
    }
  }

  Future<void> _checkAccessibility() async {
    final a = await AutoFillBridge.isAccessibilityEnabled();
    if (!mounted) return;
    setState(() => _accessibilityOn = a);
  }

  void _addLog(LogEntry e) {
    final cur = _logs.value;
    final upd = <LogEntry>[e, ...cur];
    if (upd.length > 100) upd.removeRange(100, upd.length);
    _logs.value = upd;
    widget.onLog(e);
  }

  Future<void> _createTask() async {
    final result = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskEditorPage(
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
    if (result != null) {
      // ⭐ احفظ في Firestore
      await FirestoreService.saveAdminTask(result);
    }
  }

  Future<void> _editTask(Task task) async {
    final result = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskEditorPage(
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
          initialTask: task,
        ),
      ),
    );
    if (result != null) {
      await FirestoreService.saveAdminTask(result);
    }
  }

  Future<void> _deleteTask(Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
          'حذف المهمة',
          style: _noDeco.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'متأكد إنك عايز تحذف "${task.name}"؟',
          style: _noDeco.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: _noDeco),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'حذف',
              style: _noDeco.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirestoreService.deleteAdminTask(task.id);
    }
  }

  Future<void> _uploadTask(Task task) async {
    if (_runner.running) return;

    final uploaded = await showUploadScriptSheet(
      context,
      isDark: widget.isDark,
      task: task,
    );

    if (uploaded == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم رفع السكربت'),
          backgroundColor: Color(0xFF00D68F),
        ),
      );
    }
  }

  Future<void> _runTask(Task task) async {
    if (_runner.running) return;
    setState(() => _runningTask = task);
    _logs.value = <LogEntry>[];
    await _runner.run(
      task,
      onLog: _addLog,
      numbers: widget.currentNumbers,
      currentIndex: widget.currentCsvIndex,
    );
    // ⭐ حدّث lastRunAt في Firestore
    await FirestoreService.saveAdminTask(
      task.copyWith(lastRunAt: DateTime.now()),
    );
    if (mounted) setState(() => _runningTask = null);
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
                    icon: Icons.arrow_back_rounded,
                    onTap: widget.onBack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StreamBuilder<List<Task>>(
                      stream: FirestoreService.adminTasksStream(),
                      builder: (_, snap) {
                        final c = snap.data?.length ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المهام',
                              style: _noDeco.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$c مهمة محفوظة',
                              style: _noDeco.copyWith(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                            ),
                          ],
                        );
                      },
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

              _accessibilityCard(theme),
              const SizedBox(height: 14),

              if (_runner.running)
                _runningBar(theme)
              else
                SizedBox(
                  width: double.infinity,
                  child: ActionBtn(
                    label: 'مهمة جديدة',
                    icon: Icons.add_rounded,
                    gradient: const [
                      Color(0xFF6C5CE7),
                      Color(0xFF00D2FF)
                    ],
                    busy: false,
                    onTap: _createTask,
                  ),
                ),
              const SizedBox(height: 14),

              Expanded(
                child: StreamBuilder<List<Task>>(
                  stream: FirestoreService.adminTasksStream(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                          child: Text('${snap.error}',
                              style: _noDeco.copyWith(fontSize: 12)));
                    }
                    final tasks = snap.data ?? [];
                    if (tasks.isEmpty) return _emptyView(theme);
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _taskCard(theme, tasks[i]),
                    );
                  },
                ),
              ),

              if (_runner.running || _logs.value.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 140,
                  child: LogPanel(
                    logs: _logs,
                    isDark: widget.isDark,
                    shrink: false,
                  ),
                ),
              ],

              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Kageno',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 11,
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

  Widget _accessibilityCard(ThemeData theme) {
    final on = _accessibilityOn;
    final color = on ? const Color(0xFF00D68F) : const Color(0xFFFF6B6B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await AutoFillBridge.openAccessibilitySettings();
          await Future.delayed(const Duration(seconds: 1));
          _checkAccessibility();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.25),
                color.withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color, width: 1.8),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: color.withOpacity(0.5), width: 1.5),
                ),
                child: Icon(
                  on
                      ? Icons.verified_user_rounded
                      : Icons.gpp_bad_rounded,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      on
                          ? 'إعدادات الوصول شغالة'
                          : 'إعدادات الوصول مقفولة',
                      style: _noDeco.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      on
                          ? 'IMS AutoFill مفعّل'
                          : 'اضغط هنا لتفعيل IMS AutoFill',
                      style: _noDeco.copyWith(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurface
                            .withOpacity(on ? 0.7 : 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  on ? 'ON' : 'OFF',
                  style: _noDeco.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _runningBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جاري تشغيل: ${_runningTask?.name ?? ""}',
                  style: _noDeco.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_runner.totalTaskRounds > 1)
                  Text(
                    'دورة ${_runner.currentTaskRound + 1}/${_runner.totalTaskRounds}',
                    style: _noDeco.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Material(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _runner.stop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stop_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text('إيقاف',
                        style: _noDeco.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'مفيش مهام بعد',
            style: _noDeco.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط "مهمة جديدة" وابدأ',
            style: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskCard(ThemeData theme, Task task) {
    final status = _runningTask?.id == task.id ? _runner.results : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface
            .withOpacity(widget.isDark ? 0.55 : 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _noDeco.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (task.repeatCount > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C5CE7)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '×${task.repeatCount}',
                              style: _noDeco.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6C5CE7),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${task.steps.length} خطوة',
                      style: _noDeco.copyWith(
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded,
                    size: 30),
                color: const Color(0xFF00D68F),
                onPressed:
                    _runner.running ? null : () => _runTask(task),
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(task.steps.length, (i) {
                Color c = theme.colorScheme.onSurface.withOpacity(0.2);
                IconData? ic;
                if (i < status.length) {
                  switch (status[i].status) {
                    case StepStatus.ok:
                      c = const Color(0xFF00D68F);
                      break;
                    case StepStatus.failed:
                      c = const Color(0xFFFF6B6B);
                      ic = Icons.close_rounded;
                      break;
                    case StepStatus.skipped:
                      c = const Color(0xFFFFB84D);
                      ic = Icons.skip_next_rounded;
                      break;
                    case StepStatus.running:
                      c = const Color(0xFF6C5CE7);
                      break;
                    default:
                      break;
                  }
                }
                return Container(
                  width: 22,
                  height: 22,
                  decoration:
                      BoxDecoration(color: c, shape: BoxShape.circle),
                  child: Center(
                    child: ic != null
                        ? Icon(ic, size: 12, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: _noDeco.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (IS_ADMIN_APP) ...[
                _miniBtn(
                  theme,
                  icon: Icons.cloud_upload_rounded,
                  label: 'رفع',
                  color: const Color(0xFF6C5CE7),
                  onTap: _runner.running
                      ? null
                      : () => _uploadTask(task),
                ),
                const SizedBox(width: 8),
              ],
              _miniBtn(
                theme,
                icon: Icons.edit_rounded,
                label: 'تعديل',
                color: const Color(0xFF00D2FF),
                onTap: _runner.running ? null : () => _editTask(task),
              ),
              const SizedBox(width: 8),
              _miniBtn(
                theme,
                icon: Icons.delete_outline_rounded,
                label: 'حذف',
                color: const Color(0xFFFF6B6B),
                onTap: _runner.running
                    ? null
                    : () => _deleteTask(task),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: _noDeco.copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}