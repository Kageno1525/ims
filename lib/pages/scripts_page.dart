import 'package:flutter/material.dart';
import '../csv_reader.dart';
import '../firebase/firestore_service.dart';
import '../firebase/user_prefs_service.dart';
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

  final Map<String, ScriptUserPrefs> _prefs = {};

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

  Future<ScriptUserPrefs> _loadPrefs(String scriptId) async {
    if (_prefs.containsKey(scriptId)) return _prefs[scriptId]!;
    final p = await UserPrefsService.load(scriptId);
    _prefs[scriptId] = p;
    return p;
  }

  // ⭐⭐⭐ حوار القواعد — فيه كل الخيارات الجديدة
  Future<void> _showRulesDialog(ScriptDoc doc) async {
    final prefs = await _loadPrefs(doc.id);
    final rules = doc.rules;

    // لو مفيش حاجة مسموح بيها
    if (!rules.allowRunCount &&
        !rules.allowRange &&
        !rules.askUseFile &&
        !rules.allowAdvanceRow &&
        !rules.allowFileRepeats) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مفيش قواعد قابلة للتعديل في السكربت ده'),
          backgroundColor: Color(0xFFFFB84D),
        ),
      );
      return;
    }

    // قيم اليوزر
    int currentRunCount = prefs.runCount > 0
        ? prefs.runCount
        : rules.defaultRunCount;
    bool currentUseFile = prefs.useFile;
    bool currentAdvanceRow = prefs.advanceRow;
    int currentFileRepeats = prefs.fileRepeats > 0
        ? prefs.fileRepeats
        : rules.defaultFileRepeats;
    String currentRange = prefs.rangeName.isNotEmpty
        ? prefs.rangeName
        : rules.defaultRange;

    final runCountCtrl =
        TextEditingController(text: currentRunCount.toString());
    final fileRepeatsCtrl =
        TextEditingController(text: currentFileRepeats.toString());

    // جيب الرنجات
    List<CsvFile> ranges = [];
    if (rules.allowRange) {
      try {
        ranges = await CsvReader.listFiles();
      } catch (_) {}
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.rule_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'قواعد السكربت',
                    style: _noDeco.copyWith(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      doc.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _noDeco.copyWith(
                        fontSize: 12,
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ═══ عدد المرات ═══
                    if (rules.allowRunCount) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7)
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF6C5CE7)
                                  .withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.repeat_rounded,
                                    size: 16,
                                    color: Color(0xFF6C5CE7)),
                                const SizedBox(width: 6),
                                Text(
                                  'عدد المرات',
                                  style: _noDeco.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF6C5CE7),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'حتى ${rules.maxRunCount}',
                                  style: _noDeco.copyWith(
                                    fontSize: 10,
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: runCountCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: _noDeco.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                              onChanged: (v) {
                                final n = int.tryParse(v) ?? 1;
                                if (n >= 1 && n <= rules.maxRunCount) {
                                  setModal(
                                      () => currentRunCount = n);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ═══ استخدام ملف ═══
                    if (rules.askUseFile) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: currentUseFile
                              ? const Color(0xFF00D68F)
                                  .withOpacity(0.08)
                              : Theme.of(ctx)
                                  .colorScheme
                                  .surface
                                  .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: currentUseFile
                                ? const Color(0xFF00D68F)
                                    .withOpacity(0.3)
                                : Theme.of(ctx)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.file_present_rounded,
                                size: 16, color: Color(0xFF00D68F)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'يستخدم ملف؟',
                                    style: _noDeco.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    currentUseFile
                                        ? 'هيشتغل بملف CSV'
                                        : 'هيشتغل بدون ملف',
                                    style: _noDeco.copyWith(
                                      fontSize: 10,
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: currentUseFile,
                              onChanged: (v) =>
                                  setModal(() => currentUseFile = v),
                              activeColor: const Color(0xFF00D68F),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ═══ الرنج ═══
                    if (rules.allowRange && currentUseFile) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D68F)
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF00D68F)
                                  .withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.folder_rounded,
                                    size: 16,
                                    color: Color(0xFF00D68F)),
                                const SizedBox(width: 6),
                                Text(
                                  'الرنج',
                                  style: _noDeco.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00D68F),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (ranges.isEmpty)
                              Text(
                                'مفيش ملفات في Download/ranges',
                                style: _noDeco.copyWith(
                                  fontSize: 11.5,
                                  color: const Color(0xFFFFB84D),
                                ),
                              )
                            else
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .surface
                                      .withOpacity(0.5),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child:
                                    DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: currentRange.isEmpty
                                        ? null
                                        : currentRange,
                                    isExpanded: true,
                                    dropdownColor: Theme.of(ctx)
                                        .colorScheme
                                        .surface,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    style: _noDeco.copyWith(
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    hint: Text('اختر رنج',
                                        style: _noDeco.copyWith(
                                            fontSize: 12)),
                                    items: ranges
                                        .map((f) =>
                                            DropdownMenuItem<String>(
                                              value: f.name,
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                      Icons
                                                          .folder_rounded,
                                                      size: 14,
                                                      color: Color(
                                                          0xFF00D68F)),
                                                  const SizedBox(
                                                      width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      f.name,
                                                      overflow:
                                                          TextOverflow
                                                              .ellipsis,
                                                      style: _noDeco
                                                          .copyWith(
                                                              fontSize:
                                                                  13),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setModal(
                                            () => currentRange = v);
                                      }
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ═══ صف جديد كل دورة ═══
                    if (rules.allowAdvanceRow && currentUseFile) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: currentAdvanceRow
                              ? const Color(0xFF00D2FF)
                                  .withOpacity(0.08)
                              : Theme.of(ctx)
                                  .colorScheme
                                  .surface
                                  .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: currentAdvanceRow
                                ? const Color(0xFF00D2FF)
                                    .withOpacity(0.3)
                                : Theme.of(ctx)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.trending_down_rounded,
                                size: 16, color: Color(0xFF00D2FF)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'صف جديد كل دورة؟',
                                    style: _noDeco.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    currentAdvanceRow
                                        ? 'كل دورة تاخد صف جديد'
                                        : 'نفس الصف كل مرة',
                                    style: _noDeco.copyWith(
                                      fontSize: 10,
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: currentAdvanceRow,
                              onChanged: (v) => setModal(
                                  () => currentAdvanceRow = v),
                              activeColor: const Color(0xFF00D2FF),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ═══ عدد مرات إعادة الملف ═══
                    if (rules.allowFileRepeats && currentUseFile) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB84D)
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFFFB84D)
                                  .withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.replay_rounded,
                                    size: 16,
                                    color: Color(0xFFFFB84D)),
                                const SizedBox(width: 6),
                                Text(
                                  'عدد مرات إعادة الملف',
                                  style: _noDeco.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFFB84D),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'لو خلص، نرجع للأول كام مرة',
                              style: _noDeco.copyWith(
                                fontSize: 10,
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.55),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: fileRepeatsCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: _noDeco.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFFB84D),
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                              onChanged: (v) {
                                final n = int.tryParse(v) ?? 1;
                                if (n >= 1) {
                                  setModal(
                                      () => currentFileRepeats = n);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('إلغاء', style: _noDeco),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'حفظ',
                  style: _noDeco.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00D68F),
                  ),
                ),
              ),
            ],
          );
        });
      },
    );

    runCountCtrl.dispose();
    fileRepeatsCtrl.dispose();

    if (result == true && mounted) {
      final newPrefs = ScriptUserPrefs(
        runCount: rules.allowRunCount
            ? (currentRunCount == rules.defaultRunCount
                ? 0
                : currentRunCount)
            : 0,
        rangeName: rules.allowRange ? currentRange : '',
        useFile: currentUseFile,
        advanceRow: currentAdvanceRow,
        fileRepeats: rules.allowFileRepeats
            ? (currentFileRepeats == rules.defaultFileRepeats
                ? 0
                : currentFileRepeats)
            : 0,
      );

      await UserPrefsService.save(doc.id, newPrefs);
      _prefs[doc.id] = newPrefs;

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ القواعد'),
            backgroundColor: Color(0xFF00D68F),
          ),
        );
      }
    }
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

    final prefs = await _loadPrefs(doc.id);
    final rules = doc.rules;

    // عدد المرات
    int effectiveRunCount = 1;
    if (rules.allowRunCount) {
      effectiveRunCount = prefs.runCount > 0
          ? prefs.runCount
          : rules.defaultRunCount;
    }

    // يستخدم ملف؟
    bool effectiveUseFile = rules.askUseFile
        ? prefs.useFile
        : rules.defaultUseFile;

    // الرنج
    String effectiveRange = '';
    if (rules.allowRange) {
      effectiveRange = prefs.rangeName.isNotEmpty
          ? prefs.rangeName
          : rules.defaultRange;
    } else {
      effectiveRange = rules.defaultRange;
    }

    // صف جديد كل دورة؟
    bool effectiveAdvance = rules.allowAdvanceRow
        ? prefs.advanceRow
        : rules.defaultAdvanceRow;

    // عدد مرات إعادة الملف
    int effectiveRepeats = 1;
    if (rules.allowFileRepeats) {
      effectiveRepeats = prefs.fileRepeats > 0
          ? prefs.fileRepeats
          : rules.defaultFileRepeats;
    } else {
      effectiveRepeats = rules.defaultFileRepeats;
    }

    setState(() {
      _runningScriptId = doc.id;
      _runningScript = doc;
    });
    _logs.value = <LogEntry>[];

    try {
      // ⭐ نجهز الأرقام لو محتاجين
      List<String> numbers = [];
      if (effectiveUseFile && effectiveRange.isNotEmpty) {
        try {
          final ranges = await CsvReader.listFiles();
          final file = ranges.firstWhere(
            (f) => f.name == effectiveRange,
            orElse: () => CsvFile(name: '', path: '', count: 0),
          );
          if (file.path.isNotEmpty) {
            numbers = await CsvReader.readColumnC(file.path);
            _addLog(LogEntry(
              '📄 حمّلت $effectiveRange (${numbers.length} رقم)',
              DateTime.now(),
              LogLevel.info,
            ));
          }
        } catch (_) {}
      }

      // ⭐⭐⭐ لو صف جديد كل دورة → نعمل task لكل صف
      if (effectiveAdvance && numbers.isNotEmpty) {
        // الدورات = عدد الأرقام × مرات الإعادة
        final totalRounds = numbers.length * effectiveRepeats;
        _addLog(LogEntry(
          '🔁 هيتم تشغيل السكربت $totalRounds مرة (صف جديد كل مرة)',
          DateTime.now(),
          LogLevel.info,
        ));

        int runCount = 0;
        bool allOk = true;
        for (int repeat = 0; repeat < effectiveRepeats; repeat++) {
          if (!_runner.running && runCount > 0) break;
          if (repeat > 0) {
            _addLog(LogEntry(
              '🔁 إعادة الملف رقم ${repeat + 1}/$effectiveRepeats',
              DateTime.now(),
              LogLevel.info,
            ));
          }
          for (int rowIdx = 0; rowIdx < numbers.length; rowIdx++) {
            if (_runningScriptId == null) {
              allOk = false;
              break;
            }
            final task = _scriptToTask(doc).copyWith(
              repeatCount: 1,
            );
            _addLog(LogEntry(
              '▶️ صف ${rowIdx + 1}/${numbers.length} — رقم: ${numbers[rowIdx]}',
              DateTime.now(),
              LogLevel.info,
            ));
            final ok = await _runner.run(
              task,
              onLog: _addLog,
              numbers: [numbers[rowIdx]],
              currentIndex: 0,
            );
            if (!ok) {
              allOk = false;
              break;
            }
            runCount++;
            if (runCount >= effectiveRunCount * numbers.length * effectiveRepeats) {
              break;
            }
          }
          if (!allOk) break;
        }
      } else if (effectiveAdvance) {
        // مفيش ملف بس advanceRow مفعّل
        _addLog(LogEntry(
          '⚠️ مفيش ملف — مش هينفع صف جديد',
          DateTime.now(),
          LogLevel.wait,
        ));
        final task = _scriptToTask(doc).copyWith(
          repeatCount: effectiveRunCount,
        );
        await _runner.run(
          task,
          onLog: _addLog,
          numbers: numbers,
          currentIndex: 0,
        );
      } else {
        // ⭐ كل الدورات في مرة واحدة (نفس الصف)
        final task = _scriptToTask(doc).copyWith(
          repeatCount: effectiveRunCount,
        );
        await _runner.run(
          task,
          onLog: _addLog,
          numbers: numbers,
          currentIndex: 0,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _runningScriptId = null;
          _runningScript = null;
        });
      }
    }
  }

  void _stopScript() {
    _runner.stop();
    if (mounted) {
      setState(() {
        _runningScriptId = null;
        _runningScript = null;
      });
    }
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

              _accessibilityCard(theme),
              const SizedBox(height: 10),

              if (_runner.running) _runningBar(theme),
              const SizedBox(height: 4),

              Expanded(
                child: StreamBuilder<List<ScriptDoc>>(
                  stream: FirestoreService.userScriptsStream(
                      widget.profile.uid),
                  builder: (context, snap) {
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
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
    final rules = doc.rules;
    final hasRules = rules.allowRunCount ||
        rules.allowRange ||
        rules.askUseFile ||
        rules.allowAdvanceRow ||
        rules.allowFileRepeats;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap:
                      isAnyRunning ? null : () => _runScript(doc),
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
                          ? theme.colorScheme.onSurface
                              .withOpacity(0.15)
                          : null,
                    ),
                    child: Icon(
                      isRunning
                          ? Icons.hourglass_top_rounded
                          : Icons.play_arrow_rounded,
                      color: isAnyRunning
                          ? theme.colorScheme.onSurface
                              .withOpacity(0.4)
                          : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (hasRules) ...[
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showRulesDialog(doc),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF6C5CE7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            const Color(0xFF6C5CE7).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.rule_rounded,
                          size: 16, color: Color(0xFF6C5CE7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'القواعد',
                          style: _noDeco.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6C5CE7),
                          ),
                        ),
                      ),
                      Text(
                        _prefsSummary(doc),
                        style: _noDeco.copyWith(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.settings_rounded,
                          size: 14, color: Color(0xFF6C5CE7)),
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

  String _prefsSummary(ScriptDoc doc) {
    final prefs = _prefs[doc.id];
    final rules = doc.rules;
    final parts = <String>[];

    if (rules.allowRunCount) {
      final c = prefs?.runCount ?? 0;
      final effective = c > 0 ? c : rules.defaultRunCount;
      parts.add('$effective×');
    }

    if (rules.allowRange) {
      final r = prefs?.rangeName ?? '';
      final effective =
          r.isNotEmpty ? r : rules.defaultRange;
      if (effective.isNotEmpty) {
        parts.add(effective);
      }
    }

    if (rules.askUseFile) {
      final u = prefs?.useFile ?? rules.defaultUseFile;
      parts.add(u ? '📄 ملف' : 'بدون ملف');
    }

    return parts.join(' • ');
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