import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets.dart';
import '../autofill_bridge.dart';
import 'task_model.dart';
import 'task_storage.dart';
import 'task_editor_page.dart';
import 'task_runner.dart';

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

class _TasksPageState extends State<TasksPage> {
  static const _noDeco = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  List<Task> _tasks = [];
  bool _loading = true;
  Task? _runningTask;
  final TaskRunner _runner = TaskRunner();
  final ValueNotifier<List<LogEntry>> _logs =
      ValueNotifier<List<LogEntry>>(<LogEntry>[]);

  @override
  void initState() {
    super.initState();
    _load();
    _runner.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _runner.dispose();
    _logs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await TaskStorage.loadAll();
    if (!mounted) return;
    setState(() {
      _tasks = list;
      _loading = false;
    });
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
      await TaskStorage.upsert(result);
      await _load();
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
      await TaskStorage.upsert(result);
      await _load();
    }
  }

  Future<void> _deleteTask(Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
      await TaskStorage.delete(task.id);
      await _load();
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
    await TaskStorage.upsert(task.copyWith(lastRunAt: DateTime.now()));
    await _load();
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
                    child: Column(
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
                          '${_tasks.length} مهمة محفوظة',
                          style: _noDeco.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconBtn(
                    icon: Icons.settings_rounded,
                    onTap: () =>
                        AutoFillBridge.openAccessibilitySettings(),
                  ),
                  const SizedBox(width: 8),
                  IconBtn(
                    icon: widget.isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    onTap: widget.onToggleTheme,
                  ),
                ],
              ),
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _tasks.isEmpty
                        ? _emptyView(theme)
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: _tasks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _taskCard(theme, _tasks[i]),
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
            child: Text(
              'جاري تشغيل: ${_runningTask?.name ?? ""}',
              style: _noDeco.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stop_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'إيقاف',
                      style: _noDeco.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
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
          Icon(
            Icons.auto_awesome_rounded,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
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
            'اضغط "مهمة جديدة" وابدأ تبني أول أتمتة',
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
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: _noDeco.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${task.steps.length} خطوة',
                      style: _noDeco.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 30,
                ),
                color: const Color(0xFF00D68F),
                onPressed: _runner.running ? null : () => _runTask(task),
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(task.steps.length, (i) {
                Color c;
                IconData? ic;
                if (i >= status.length) {
                  c = theme.colorScheme.onSurface.withOpacity(0.2);
                  ic = null;
                } else {
                  switch (status[i].status) {
                    case StepStatus.ok:
                      c = const Color(0xFF00D68F);
                      ic = null;
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
                      ic = null;
                      break;
                    default:
                      c = theme.colorScheme.onSurface.withOpacity(0.2);
                      ic = null;
                  }
                }
                return Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                  ),
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
                onTap: _runner.running ? null : () => _deleteTask(task),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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