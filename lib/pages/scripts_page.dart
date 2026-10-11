import 'package:flutter/material.dart';
import '../firebase/firestore_service.dart';
import '../models.dart';
import '../widgets.dart';
import '../autofill_bridge.dart';
import '../tasks/task_model.dart';
import '../tasks/task_runner.dart';

class ScriptsPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onBack;
  final UserProfile profile;

  const ScriptsPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onBack,
    required this.profile,
  });

  @override
  State<ScriptsPage> createState() => _ScriptsPageState();
}

class _ScriptsPageState extends State<ScriptsPage>
    with WidgetsBindingObserver {
  static const _noDeco = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  final TaskRunner _runner = TaskRunner();
  final ValueNotifier<List<LogEntry>> _logs =
      ValueNotifier<List<LogEntry>>(<LogEntry>[]);
  String? _runningScriptId;
  ScriptDoc? _runningScript;
  bool _accessibilityOn = false;

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
  }

  Task _scriptToTask(ScriptDoc doc) {
    return Task(
      id: doc.id,
      name: doc.name,
      steps: doc.steps
          .map((s) => TaskStep.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      createdAt: doc.createdAt ?? DateTime.now(),
    );
  }

  Future<void> _runScript(ScriptDoc doc) async {
    if (_runner.running) return;
    if (!_accessibilityOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فعّل "إعدادات الوصول" الأول'),
          backgroundColor: Color(0xFFFFB84D),
        ),
      );
      return;
    }

    setState(() {
      _runningScriptId = doc.id;
      _runningScript = doc;
    });
    _logs.value = <LogEntry>[];

    try {
      final task = _scriptToTask(doc);
      await _runner.run(
        task,
        onLog: _addLog,
        numbers: const [],
        currentIndex: 0,
      );
    } finally {
      if (mounted) {
        setState(() {
          _runningScriptId = null;
          _runningScript = null;
        });
      }
    }
  }

  void _stopScript() => _runner.stop();

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
                          'السكربتات',
                          style: _noDeco.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        StreamBuilder<List<ScriptDoc>>(
                          stream: FirestoreService.userScriptsStream(
                              widget.profile.uid),
                          builder: (_, snap) {
                            final c = snap.data?.length ?? 0;
                            return Text(
                              '$c سكربت متاح',
                              style: _noDeco.copyWith(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                            );
                          },
                        ),
                      ],
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
              const SizedBox(height: 10),

              // ⭐ زر إعدادات الوصول
              _accessibilityCard(theme),
              const SizedBox(height: 10),

              if (_runner.running) _runningBar(theme),
              const SizedBox(height: 4),

              Expanded(
                child: StreamBuilder<List<ScriptDoc>>(
                  stream: FirestoreService.userScriptsStream(
                      widget.profile.uid),
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
                    final scripts = snap.data ?? [];
                    if (scripts.isEmpty) {
                      return _emptyView(theme);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: scripts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _scriptCard(theme, scripts[i]),
                    );
                  },
                ),
              ),

              if (_runner.running || _logs.value.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 160,
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

  // ⭐ كارت إعدادات الوصول (زي اللي في المهام)
  Widget _accessibilityCard(ThemeData theme) {
    final on = _accessibilityOn;
    final color = on ? const Color(0xFF00D68F) : const Color(0xFFFF6B6B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await AutoFillBridge.openAccessibilitySettings();
          await Future.delayed(const Duration(seconds: 1));
          _checkAccessibility();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.2),
                color.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  on
                      ? Icons.verified_user_rounded
                      : Icons.gpp_bad_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      on
                          ? 'إعدادات الوصول شغالة'
                          : 'اضغط لتفعيل إعدادات الوصول',
                      style: _noDeco.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      on
                          ? 'IMS AutoFill مفعّل'
                          : 'لازم تفعّلها عشان السكربت يشتغل',
                      style: _noDeco.copyWith(
                        fontSize: 10.5,
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _runningBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B894), Color(0xFF00D68F)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'جاري تشغيل: ${_runningScript?.name ?? ""}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _noDeco.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Material(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _stopScript,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stop_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text('إيقاف',
                        style: _noDeco.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scriptCard(ThemeData theme, ScriptDoc doc) {
    final isRunning = _runningScriptId == doc.id;
    final isAnyRunning = _runner.running;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface
            .withOpacity(widget.isDark ? 0.55 : 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRunning
              ? const Color(0xFF00D68F)
              : theme.colorScheme.primary.withOpacity(0.2),
          width: isRunning ? 2 : 1.2,
        ),
      ),
      child: Row(
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
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _noDeco.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${doc.steps.length} خطوة',
                  style: _noDeco.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: isAnyRunning ? null : () => _runScript(doc),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isAnyRunning
                      ? null
                      : const LinearGradient(
                          colors: [
                            Color(0xFF00D68F),
                            Color(0xFF00B894),
                          ],
                        ),
                  color: isAnyRunning
                      ? theme.colorScheme.onSurface.withOpacity(0.15)
                      : null,
                ),
                child: Icon(
                  isRunning
                      ? Icons.hourglass_top_rounded
                      : Icons.play_arrow_rounded,
                  color: isAnyRunning
                      ? theme.colorScheme.onSurface.withOpacity(0.4)
                      : Colors.white,
                  size: 22,
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
            Icons.auto_awesome_outlined,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'مفيش سكربتات',
            style: _noDeco.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'الأدمن لسه مرفعلكش أي سكربت',
            style: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}