import 'package:flutter/material.dart';
import '../widgets.dart';
import '../autofill_bridge.dart';
import '../csv_reader.dart';
import '../models.dart' show InstalledApp, CsvFile;
import 'task_model.dart';
import 'task_pickers.dart';

const _noDeco = TextStyle(
  decoration: TextDecoration.none,
  decorationColor: Colors.transparent,
);

Future<TaskStep?> showStepConfigSheet(
  BuildContext context, {
  required bool isDark,
  required TaskStep step,
}) {
  return showModalBottomSheet<TaskStep>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _StepConfigSheet(isDark: isDark, step: step),
  );
}

class _StepConfigSheet extends StatefulWidget {
  final bool isDark;
  final TaskStep step;
  const _StepConfigSheet({required this.isDark, required this.step});

  @override
  State<_StepConfigSheet> createState() => _StepConfigSheetState();
}

class _StepConfigSheetState extends State<_StepConfigSheet> {
  late Map<String, TextEditingController> _ctrls;
  late TaskStepType _currentType;
  late int _waitAfter;
  late int _timeoutMs;
  late int _repeatCount;
  late FailureAction _onFail;
  late int _skipCount;
  late OnAppearAction _onAppear;
  late NotFoundAction _onNotFound;
  late bool _speedMode;
  late String _swipeDirection;
  late TextEditingController _timeoutCtrl;
  late TextEditingController _skipCountCtrl;
  late TextEditingController _repeatCtrl;
  late TextEditingController _appearTextCtrl;
  late TextEditingController _altTextCtrl;
  late TextEditingController _altDescCtrl;
  late TextEditingController _altViewIdCtrl;
  late TextEditingController _altTypeCtrl;
  late TextEditingController _cyclesCtrl;
  late TextEditingController _maxSwipesCtrl;
  String? _selectedAppName;
  String? _selectedCsvName;
  String? _lastHint;
  List<CsvFile> _csvFiles = [];

  @override
  void initState() {
    super.initState();
    _ctrls = {};
    _currentType = widget.step.type;
    _waitAfter = widget.step.waitAfterMs;
    _timeoutMs = widget.step.timeoutMs;
    _repeatCount = widget.step.repeatCount;
    _onFail = widget.step.onFail;
    _skipCount = widget.step.skipCount;
    _onAppear = widget.step.onAppear;
    _onNotFound = widget.step.onNotFound;
    _speedMode = widget.step.speedMode;
    _swipeDirection =
        widget.step.params['direction']?.toString() ?? 'down';
    _timeoutCtrl = TextEditingController(text: _timeoutMs.toString());
    _skipCountCtrl = TextEditingController(text: _skipCount.toString());
    _repeatCtrl = TextEditingController(text: _repeatCount.toString());
    _appearTextCtrl =
        TextEditingController(text: widget.step.appearText);
    _altTextCtrl = TextEditingController(text: widget.step.altText);
    _altDescCtrl = TextEditingController(text: widget.step.altDesc);
    _altViewIdCtrl =
        TextEditingController(text: widget.step.altViewId);
    _altTypeCtrl =
        TextEditingController(text: widget.step.altTypeText);
    _cyclesCtrl = TextEditingController(
        text: (widget.step.params['cycles']?.toString() ?? '1'));
    _maxSwipesCtrl = TextEditingController(
        text: (widget.step.params['maxSwipes']?.toString() ?? '20'));
    _selectedCsvName = widget.step.params['csvName']?.toString();

    final keys = _fieldKeysFor(_currentType);
    for (final k in keys) {
      _ctrls[k] = TextEditingController(
        text: widget.step.params[k]?.toString() ??
            _defaultValueFor(_currentType, k),
      );
    }

    if (_currentType == TaskStepType.numberFromFile) {
      Future.microtask(_loadCsvFiles);
    }
  }

  Future<void> _loadCsvFiles() async {
    final list = await CsvReader.listFiles();
    if (!mounted) return;
    setState(() {
      _csvFiles = list;
      if ((_selectedCsvName == null || _selectedCsvName!.isEmpty) &&
          list.isNotEmpty) {
        _selectedCsvName = list.first.name;
      }
    });
  }

  // ⭐⭐ التعديل الأول: ضيفنا 'text' لحقول typeText
  List<String> _fieldKeysFor(TaskStepType t) {
    switch (t) {
      case TaskStepType.openApp:
      case TaskStepType.clearAppData:
        return ['package'];
      case TaskStepType.typeText:
        return ['text', 'viewId', 'hint', 'className', 'elementIndex'];
      case TaskStepType.numberFromFile:
        return ['viewId', 'hint', 'className', 'elementIndex'];
      case TaskStepType.clickByText:
      case TaskStepType.clickByDesc:
      case TaskStepType.clickById:
      case TaskStepType.waitForElement:
        return ['text', 'desc', 'viewId', 'className', 'elementIndex'];
      case TaskStepType.clickAt:
        return ['x', 'y'];
      case TaskStepType.swipe:
        return ['x1', 'y1', 'x2', 'y2', 'duration'];
      case TaskStepType.swipeToFind:
        return ['targetText', 'x1', 'y1', 'duration', 'distance'];
      case TaskStepType.wait:
        return ['ms'];
      default:
        return [];
    }
  }

  String _defaultValueFor(TaskStepType t, String key) {
    if (t == TaskStepType.wait && key == 'ms') return '1000';
    if (t == TaskStepType.swipe && key == 'duration') return '300';
    if (t == TaskStepType.swipeToFind && key == 'duration') return '300';
    if (t == TaskStepType.swipeToFind && key == 'distance') return '400';
    if (key == 'elementIndex') return '0';
    return '';
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _timeoutCtrl.dispose();
    _skipCountCtrl.dispose();
    _repeatCtrl.dispose();
    _appearTextCtrl.dispose();
    _altTextCtrl.dispose();
    _altDescCtrl.dispose();
    _altViewIdCtrl.dispose();
    _altTypeCtrl.dispose();
    _cyclesCtrl.dispose();
    _maxSwipesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickApp() async {
    final app = await showAppPicker(context, isDark: widget.isDark);
    if (app != null && mounted) {
      setState(() {
        _ctrls['package']?.text = app.package;
        _selectedAppName = app.name;
      });
    }
  }

  Future<void> _pickCsv() async {
    if (_csvFiles.isEmpty) await _loadCsvFiles();
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CsvPickerSheet(
        files: _csvFiles,
        selected: _selectedCsvName,
        isDark: widget.isDark,
        onRefresh: _loadCsvFiles,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedCsvName = picked);
    }
  }

  Future<void> _changeType() async {
    final newType =
        await showStepTypePicker(context, isDark: widget.isDark);
    if (newType == null || !mounted) return;

    final oldValues = <String, String>{};
    for (final e in _ctrls.entries) {
      oldValues[e.key] = e.value.text;
    }

    final keys = _fieldKeysFor(newType);
    final newCtrls = <String, TextEditingController>{};
    for (final k in keys) {
      String v = oldValues[k] ?? '';
      if (v.isEmpty) v = _defaultValueFor(newType, k);
      newCtrls[k] = TextEditingController(text: v);
    }

    setState(() {
      for (final c in _ctrls.values) {
        c.dispose();
      }
      _ctrls = newCtrls;
      _currentType = newType;
      _lastHint = null;
    });

    if (newType == TaskStepType.numberFromFile && _csvFiles.isEmpty) {
      await _loadCsvFiles();
    }
  }

  Future<void> _inspectScreen() async {
    final captured = await showCountdownAndCapture(context);
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

    final picked = await showElementPicker(
      context,
      elements: captured,
      isDark: widget.isDark,
    );
    if (picked == null) return;

    int sameIdx = 0;
    for (final e in captured) {
      if (identical(e, picked)) break;
      if (e.sameSpecs(picked)) sameIdx++;
    }

    _applyPickedElement(picked, sameIdx);
  }

  Future<void> _captureElement({String purpose = 'start'}) async {
    final captured = await showCountdownAndCapture(context);
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

    final picked = await showElementPicker(
      context,
      elements: captured,
      isDark: widget.isDark,
    );
    if (picked == null) return;

    setState(() {
      _ctrls['x1']?.text = picked.x.toString();
      _ctrls['y1']?.text = picked.y.toString();
      _lastHint =
          'النقطة الثابتة: (${picked.x}, ${picked.y}) — ${picked.bestLabel}';
    });
  }

  void _applyPickedElement(ScreenElement picked, int sameIdx) {
    if (_currentType == TaskStepType.typeText ||
        _currentType == TaskStepType.numberFromFile) {
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
    } else if (_currentType == TaskStepType.clickByDesc &&
        !picked.hasDesc) {
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
        final lbl = TaskStep(
                id: '', type: newType, params: {}, waitAfterMs: 0)
            .typeLabel;
        _lastHint = 'تم تغيير النوع لـ $lbl';
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
      case TaskStepType.numberFromFile:
      case TaskStepType.waitForElement:
        return true;
      default:
        return false;
    }
  }

  // ⭐⭐ التعديل التاني: ضيفنا typeText في search steps
  bool get _isSearchStep {
    switch (_currentType) {
      case TaskStepType.clickByText:
      case TaskStepType.clickByDesc:
      case TaskStepType.clickById:
      case TaskStepType.clickAt:
      case TaskStepType.waitForElement:
      case TaskStepType.typeText:
        return true;
      default:
        return false;
    }
  }

  bool get _isWaitForElement =>
      _currentType == TaskStepType.waitForElement;

  bool get _isNumberFromFile =>
      _currentType == TaskStepType.numberFromFile;

  bool get _isSwipeToFind =>
      _currentType == TaskStepType.swipeToFind;

  void _save() {
    final params = <String, dynamic>{};
    for (final e in _ctrls.entries) {
      params[e.key] = e.value.text;
    }
    if (_isNumberFromFile) {
      params['csvName'] = _selectedCsvName ?? '';
      params['cycles'] = _cyclesCtrl.text;
    }
    if (_isSwipeToFind) {
      params['maxSwipes'] = _maxSwipesCtrl.text;
      params['direction'] = _swipeDirection;
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
        onAppear: _onAppear,
        onNotFound: _onNotFound,
        appearText: _appearTextCtrl.text,
        altText: _altTextCtrl.text,
        altDesc: _altDescCtrl.text,
        altViewId: _altViewIdCtrl.text,
        altTypeText: _altTypeCtrl.text,
        repeatCount: _repeatCount,
        speedMode: _speedMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = TaskStep(
            id: '', type: _currentType, params: {}, waitAfterMs: 0)
        .typeLabel;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: _noDeco.copyWith(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: _changeType,
                    icon: Icon(Icons.swap_horiz_rounded,
                        color: theme.colorScheme.primary),
                    tooltip: 'تغيير النوع',
                  ),
                ],
              ),
              const SizedBox(height: 4),

              if (_canInspect) _buildInspectButton(),
              if (_lastHint != null) _buildHintBox(),
              const SizedBox(height: 12),

              ..._buildContent(theme),

              if (_isSearchStep) ...[
                const SizedBox(height: 4),
                _buildSpeedSection(theme),
              ],

              const SizedBox(height: 14),
              _buildRepeatField(theme),

              const SizedBox(height: 12),
              _buildWaitSlider(theme),

              if (_isSearchStep) ..._buildTimeoutSection(theme),

              if (_isWaitForElement) ...[
                const SizedBox(height: 16),
                _buildOnAppearSection(theme),
                const SizedBox(height: 16),
                _buildOnNotFoundSection(theme),
              ],

              const SizedBox(height: 16),
              ActionBtn(
                label: 'تم',
                icon: Icons.check_rounded,
                gradient:
                    const [Color(0xFF00B894), Color(0xFF00D68F)],
                busy: false,
                onTap: _save,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedSection(ThemeData theme) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _speedMode
            ? const Color(0xFFFFD93D).withOpacity(0.12)
            : theme.colorScheme.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _speedMode
              ? const Color(0xFFFFD93D)
              : theme.colorScheme.primary.withOpacity(0.15),
          width: _speedMode ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded,
              size: 22, color: Color(0xFFF39C12)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'السرعة القصوى',
                  style: _noDeco.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _speedMode
                        ? const Color(0xFFF39C12)
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'polling كل 20ms + cache للعناصر',
                  style: _noDeco.copyWith(
                    fontSize: 10,
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _speedMode,
            onChanged: (v) => setState(() => _speedMode = v),
            activeColor: const Color(0xFFF39C12),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatField(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6C5CE7).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.repeat_rounded,
              size: 18, color: Color(0xFF6C5CE7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تكرار الخطوة',
                  style: _noDeco.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6C5CE7)),
                ),
                Text(
                  '1 = مرة واحدة • أكثر = يكررها N مرة',
                  style: _noDeco.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _repeatCtrl,
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
                if (n >= 1) setState(() => _repeatCount = n);
              },
            ),
          ),
        ],
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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  color: Colors.white, size: 22),
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
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF00D68F).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: const Color(0xFF00D68F).withOpacity(0.4)),
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
      ),
    );
  }

  List<Widget> _buildContent(ThemeData theme) {
    switch (_currentType) {
      case TaskStepType.openApp:
        return _buildAppSection(theme, warn: false);
      case TaskStepType.clearAppData:
        return _buildAppSection(theme, warn: true);
      case TaskStepType.wait:
        return [_buildMsField(theme)];
      case TaskStepType.typeText:
        return _buildTypeTextFields(theme);
      case TaskStepType.numberFromFile:
        return _buildNumberFromFileFields(theme);
      case TaskStepType.clickByText:
      case TaskStepType.clickByDesc:
      case TaskStepType.clickById:
      case TaskStepType.waitForElement:
        return _buildClickFields(theme);
      case TaskStepType.clickAt:
        return [_buildXYRow(theme)];
      case TaskStepType.swipe:
        return _buildSwipeFields(theme);
      case TaskStepType.swipeToFind:
        return _buildSwipeToFindFields(theme);
      case TaskStepType.back:
      case TaskStepType.home:
      case TaskStepType.recents:
        return [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'مفيش إعدادات للخطوة دي',
              textAlign: TextAlign.center,
              style: _noDeco.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ];
    }
  }

  List<Widget> _buildNumberFromFileFields(ThemeData theme) {
    return [
      _buildCsvPicker(theme),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.replay_rounded,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'عدد الدورات على الملف',
                    style: _noDeco.copyWith(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '1 = مرة واحدة • أكثر = يلف على الملف N مرة',
                    style: _noDeco.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface
                          .withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 60,
              child: TextField(
                controller: _cyclesCtrl,
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
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'الحقل اللي هيتكتب فيه الرقم — استخدم "التقاط الشاشة" لملئها',
          style: _noDeco.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _ctrls['viewId'],
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'الـ id (اختياري)',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.tag_rounded, size: 18),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _ctrls['hint'],
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'نص الإرشاد hint (اختياري)',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.lightbulb_outline_rounded,
              size: 18),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrls['className'],
              style: _noDeco.copyWith(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'className',
                labelStyle: _noDeco.copyWith(
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.6)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _ctrls['elementIndex'],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: _noDeco.copyWith(
                  fontSize: 14, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: '# ترتيب',
                labelStyle: _noDeco.copyWith(
                    color: theme.colorScheme.onSurface
                        .withOpacity(0.6),
                    fontSize: 11),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildCsvPicker(ThemeData theme) {
    final current = _selectedCsvName;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _pickCsv,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: current != null && current.isNotEmpty
                  ? const Color(0xFF00D68F).withOpacity(0.5)
                  : theme.colorScheme.primary.withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_rounded,
                  size: 22,
                  color: current != null && current.isNotEmpty
                      ? const Color(0xFF00D68F)
                      : theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الرنج / ملف الأرقام',
                      style: _noDeco.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current == null || current.isEmpty
                          ? 'اضغط لاختيار ملف من Download/ranges'
                          : current,
                      style: _noDeco.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: current == null || current.isEmpty
                            ? theme.colorScheme.onSurface
                                .withOpacity(0.5)
                            : const Color(0xFF00D68F),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSwipeToFindFields(ThemeData theme) {
    final hasPoint = (_ctrls['x1']?.text.isNotEmpty ?? false) &&
        (_ctrls['y1']?.text.isNotEmpty ?? false);

    return [
      TextField(
        controller: _ctrls['targetText'],
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'النص اللي بندور عليه',
          hintText: 'مثال: اسم شخص / عنصر',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          hintStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4)),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
        ),
      ),
      const SizedBox(height: 14),

      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _captureElement(purpose: 'start'),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPoint
                            ? 'تغيير النقطة الثابتة'
                            : 'اختر العنصر (نقطة التمركز)',
                        style: _noDeco.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'هيفضل يدوس على نفس النقطة دي كل مرة',
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
      ),
      const SizedBox(height: 10),

      if (hasPoint)
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF00D68F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF00D68F).withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 18, color: Color(0xFF00D68F)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'النقطة الثابتة: (${_ctrls['x1']?.text}, ${_ctrls['y1']?.text})',
                  style: _noDeco.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00D68F),
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 14),

      Row(
        children: [
          Icon(Icons.swap_vert_rounded,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'الاتجاه',
            style: _noDeco.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _directionBtn(
              theme,
              label: '⬆️ لـ فوق',
              value: 'up',
              color: const Color(0xFF00D2FF),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _directionBtn(
              theme,
              label: '⬇️ لـ تحت',
              value: 'down',
              color: const Color(0xFFFF8E53),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),

      TextField(
        controller: _ctrls['distance'],
        keyboardType: TextInputType.number,
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'المسافة (بكسل)',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.straighten_rounded, size: 18),
          helperText: '400 = سحبة قصيرة • 800 = سحبة طويلة',
          helperStyle: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.primary.withOpacity(0.7),
          ),
        ),
      ),
      const SizedBox(height: 12),

      TextField(
        controller: _ctrls['duration'],
        keyboardType: TextInputType.number,
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'مدة السحبة (مللي ثانية)',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.speed_rounded, size: 18),
          helperText: '300 = سريع، 800 = بطيء',
          helperStyle: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.primary.withOpacity(0.7),
          ),
        ),
      ),
      const SizedBox(height: 12),

      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.swipe_vertical_rounded,
                size: 18, color: Color(0xFFFF6B6B)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أقصى عدد سحبات',
                    style: _noDeco.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFF6B6B)),
                  ),
                  Text(
                    'لو النص مش ظهر، يوقف بعد العدد ده',
                    style: _noDeco.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface
                          .withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 60,
              child: TextField(
                controller: _maxSwipesCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: _noDeco.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF6B6B),
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _directionBtn(
    ThemeData theme, {
    required String label,
    required String value,
    required Color color,
  }) {
    final selected = _swipeDirection == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _swipeDirection = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.2)
                : theme.colorScheme.surface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color
                  : theme.colorScheme.primary.withOpacity(0.15),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: _noDeco.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: selected
                    ? color
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAppSection(ThemeData theme,
      {required bool warn}) {
    final pkg = _ctrls['package']?.text ?? '';
    final color =
        warn ? const Color(0xFFFF6B6B) : theme.colorScheme.primary;

    return [
      if (warn)
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFFF6B6B).withOpacity(0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF6B6B), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'سيتم مسح كل بيانات التطبيق — الطريقة تختلف حسب الجهاز',
                  style: _noDeco.copyWith(
                      fontSize: 11,
                      color: const Color(0xFFFF6B6B),
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _pickApp,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: pkg.isEmpty
                  ? color.withOpacity(0.15)
                  : theme.colorScheme.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.apps_rounded, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg.isEmpty
                            ? 'اضغط لاختيار تطبيق'
                            : (_selectedAppName ?? 'تطبيق مختار'),
                        style: _noDeco.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      if (pkg.isNotEmpty)
                        Text(
                          pkg,
                          style: _noDeco.copyWith(
                            fontSize: 10.5,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.5),
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
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _ctrls['package'],
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'اسم الحزمة (أو اختار من فوق)',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.tag_rounded),
        ),
      ),
    ];
  }

  Widget _buildMsField(ThemeData theme) {
    return TextField(
      controller: _ctrls['ms'],
      style: _noDeco.copyWith(fontSize: 15),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'المدة (مللي ثانية)',
        labelStyle: _noDeco.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6)),
        prefixIcon: const Icon(Icons.timer_rounded),
        helperText: '1000 = ثانية واحدة',
        helperStyle: TextStyle(
          fontSize: 10,
          color: theme.colorScheme.primary.withOpacity(0.7),
        ),
      ),
    );
  }

  List<Widget> _buildTypeTextFields(ThemeData theme) {
    return [
      TextField(
        controller: _ctrls['text'],
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'النص / القيمة',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.keyboard_rounded),
          helperText:
              'يدعم: {num} = الرقم الحالي • {num:0} = أول رقم • {date} • {time}',
          helperStyle: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.primary.withOpacity(0.7),
          ),
          helperMaxLines: 3,
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'الحقول التالية اختيارية — استخدم "التقاط الشاشة" لملئها تلقائياً',
          style: _noDeco.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _ctrls['viewId'],
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'الـ id (اختياري)',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.tag_rounded, size: 18),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _ctrls['hint'],
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'نص الإرشاد hint (اختياري)',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.lightbulb_outline_rounded,
              size: 18),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrls['className'],
              style: _noDeco.copyWith(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'className',
                labelStyle: _noDeco.copyWith(
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.6)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _ctrls['elementIndex'],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: _noDeco.copyWith(
                  fontSize: 14, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: '# ترتيب',
                labelStyle: _noDeco.copyWith(
                    color: theme.colorScheme.onSurface
                        .withOpacity(0.6),
                    fontSize: 11),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildClickFields(ThemeData theme) {
    return [
      TextField(
        controller: _ctrls['text'],
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'النص',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.text_fields_rounded, size: 18),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _ctrls['desc'],
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'الوصف (content description)',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon:
              const Icon(Icons.description_rounded, size: 18),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _ctrls['viewId'],
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'الـ id',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.tag_rounded, size: 18),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrls['className'],
              style: _noDeco.copyWith(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'className',
                labelStyle: _noDeco.copyWith(
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.6)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _ctrls['elementIndex'],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: _noDeco.copyWith(
                  fontSize: 14, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: '# ترتيب',
                labelStyle: _noDeco.copyWith(
                    color: theme.colorScheme.onSurface
                        .withOpacity(0.6),
                    fontSize: 11),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildOnAppearSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF00B894).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: const Color(0xFF00B894).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 18, color: Color(0xFF00B894)),
                  const SizedBox(width: 6),
                  Text(
                    'لو العنصر ظهر',
                    style: _noDeco.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00B894),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _appearChoice(
                theme,
                value: OnAppearAction.none,
                icon: Icons.arrow_forward_rounded,
                label: 'متابعة عادية',
                subtitle: 'يكمل للخطوة التالية',
                color: const Color(0xFF00B894),
              ),
              const SizedBox(height: 6),
              _appearChoice(
                theme,
                value: OnAppearAction.click,
                icon: Icons.touch_app_rounded,
                label: 'اضغط عليه',
                subtitle: 'يضغط على العنصر أوتوماتيك',
                color: const Color(0xFF00D2FF),
              ),
              const SizedBox(height: 6),
              _appearChoice(
                theme,
                value: OnAppearAction.type,
                icon: Icons.keyboard_rounded,
                label: 'اكتب فيه',
                subtitle: 'يكتب نص في العنصر',
                color: const Color(0xFF6C5CE7),
              ),
              if (_onAppear == OnAppearAction.type) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _appearTextCtrl,
                  style: _noDeco.copyWith(fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'النص اللي هيتكتب',
                    labelStyle: _noDeco.copyWith(
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.6)),
                    prefixIcon:
                        const Icon(Icons.edit_rounded, size: 18),
                    helperText: 'يدعم: {num} • {date} • {time}',
                    helperStyle: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _appearChoice(
    ThemeData theme, {
    required OnAppearAction value,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    final selected = _onAppear == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _onAppear = value),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.15)
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
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? color
                    : theme.colorScheme.onSurface.withOpacity(0.4),
                size: 20,
              ),
              const SizedBox(width: 10),
              Icon(icon,
                  size: 18,
                  color: selected
                      ? color
                      : theme.colorScheme.onSurface.withOpacity(0.5)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: _noDeco.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? color
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: _noDeco.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnNotFoundSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFFFF6B6B).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_outline_rounded,
                      size: 18, color: Color(0xFFFF6B6B)),
                  const SizedBox(width: 6),
                  Text(
                    'لو العنصر ما ظهرش',
                    style: _noDeco.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF6B6B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _notFoundChoice(
                theme,
                value: NotFoundAction.skip,
                icon: Icons.skip_next_rounded,
                label: 'تخطي خطوات',
                subtitle: 'يتخطى N خطوة ويكمل',
                color: const Color(0xFFFFB84D),
              ),
              const SizedBox(height: 6),
              _notFoundChoice(
                theme,
                value: NotFoundAction.clickAlt,
                icon: Icons.touch_app_rounded,
                label: 'اضغط على عنصر بديل',
                subtitle: 'اضغط عنصر تاني تحدد',
                color: const Color(0xFF00D2FF),
              ),
              const SizedBox(height: 6),
              _notFoundChoice(
                theme,
                value: NotFoundAction.typeAlt,
                icon: Icons.keyboard_rounded,
                label: 'اكتب نص',
                subtitle: 'يكتب نص في أي حقل',
                color: const Color(0xFF6C5CE7),
              ),
              const SizedBox(height: 6),
              _notFoundChoice(
                theme,
                value: NotFoundAction.back,
                icon: Icons.arrow_back_rounded,
                label: 'رجوع',
                subtitle: 'يرجع للخلف',
                color: const Color(0xFFE17055),
              ),
              const SizedBox(height: 6),
              _notFoundChoice(
                theme,
                value: NotFoundAction.home,
                icon: Icons.home_rounded,
                label: 'الرئيسية',
                subtitle: 'يروح للشاشة الرئيسية',
                color: const Color(0xFF95A5A6),
              ),
              const SizedBox(height: 6),
              _notFoundChoice(
                theme,
                value: NotFoundAction.stop,
                icon: Icons.stop_rounded,
                label: 'وقف المهمة',
                subtitle: 'يوقف كل حاجة',
                color: const Color(0xFFFF6B6B),
              ),

              if (_onNotFound == NotFoundAction.skip) ...[
                const SizedBox(height: 12),
                _buildSkipCount(theme),
              ],

              if (_onNotFound == NotFoundAction.clickAlt) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _altTextCtrl,
                  style: _noDeco.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'نص العنصر البديل',
                    labelStyle: _noDeco.copyWith(
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.6)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _altDescCtrl,
                  style: _noDeco.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'وصف العنصر البديل (اختياري)',
                    labelStyle: _noDeco.copyWith(
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.6)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _altViewIdCtrl,
                  style: _noDeco.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'id العنصر البديل (اختياري)',
                    labelStyle: _noDeco.copyWith(
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.6)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ],

              if (_onNotFound == NotFoundAction.typeAlt) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _altTypeCtrl,
                  style: _noDeco.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'النص اللي هيتكتب',
                    labelStyle: _noDeco.copyWith(
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.6)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    helperText: 'يدعم: {num} • {date} • {time}',
                    helperStyle: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkipCount(ThemeData theme) {
    return Container(
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
                  'خطوات إضافية للتخطي',
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
                if (n >= 0) setState(() => _skipCount = n);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _notFoundChoice(
    ThemeData theme, {
    required NotFoundAction value,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    final selected = _onNotFound == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _onNotFound = value),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.15)
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
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? color
                    : theme.colorScheme.onSurface.withOpacity(0.4),
                size: 20,
              ),
              const SizedBox(width: 10),
              Icon(icon,
                  size: 18,
                  color: selected
                      ? color
                      : theme.colorScheme.onSurface.withOpacity(0.5)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: _noDeco.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? color
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: _noDeco.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildXYRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrls['x'],
            keyboardType: TextInputType.number,
            style: _noDeco.copyWith(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'X',
              labelStyle: _noDeco.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6)),
              prefixIcon: const Icon(Icons.my_location_rounded, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _ctrls['y'],
            keyboardType: TextInputType.number,
            style: _noDeco.copyWith(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Y',
              labelStyle: _noDeco.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6)),
              prefixIcon: const Icon(Icons.my_location_rounded, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSwipeFields(ThemeData theme) {
    return [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrls['x1'],
              keyboardType: TextInputType.number,
              style: _noDeco.copyWith(fontSize: 15),
              decoration: InputDecoration(
                labelText: 'X البداية',
                labelStyle: _noDeco.copyWith(
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.6)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrls['y1'],
              keyboardType: TextInputType.number,
              style: _noDeco.copyWith(fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Y البداية',
                labelStyle: _noDeco.copyWith(
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.6)),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrls['x2'],
              keyboardType: TextInputType.number,
              style: _noDeco.copyWith(fontSize: 15),
              decoration: InputDecoration(
                labelText: 'X النهاية',
                labelStyle: _noDeco.copyWith(
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.6)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrls['y2'],
              keyboardType: TextInputType.number,
              style: _noDeco.copyWith(fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Y النهاية',
                labelStyle: _noDeco.copyWith(
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.6)),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _ctrls['duration'],
        keyboardType: TextInputType.number,
        style: _noDeco.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: 'المدة (مللي ثانية)',
          labelStyle: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          helperText: '300 = سريع، 1500 = بطيء',
          helperStyle: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.primary.withOpacity(0.7),
          ),
        ),
      ),
    ];
  }

  Widget _buildWaitSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }

  List<Widget> _buildTimeoutSection(ThemeData theme) {
    return [
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
            _timeoutMs == 0
                ? 'بدون'
                : '${(_timeoutMs / 1000).toStringAsFixed(1)}ث',
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
                if (n >= 0) setState(() => _timeoutMs = n);
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
      if (!_isWaitForElement) ...[
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
          _buildSkipCount(theme),
        ],
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
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                        : theme.colorScheme.onSurface
                            .withOpacity(0.6),
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

// ═══════════ CSV Picker Sheet ═══════════
class _CsvPickerSheet extends StatefulWidget {
  final List<CsvFile> files;
  final String? selected;
  final bool isDark;
  final Future<void> Function() onRefresh;

  const _CsvPickerSheet({
    required this.files,
    required this.selected,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  State<_CsvPickerSheet> createState() => _CsvPickerSheetState();
}

class _CsvPickerSheetState extends State<_CsvPickerSheet> {
  late List<CsvFile> _files;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _files = widget.files;
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await widget.onRefresh();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void didUpdateWidget(_CsvPickerSheet old) {
    super.didUpdateWidget(old);
    if (old.files != widget.files) {
      setState(() => _files = widget.files);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'اختر ملف من Download/ranges',
                style: _noDeco.copyWith(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _refresh,
                icon: Icon(Icons.refresh_rounded,
                    size: 20, color: theme.colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_off_rounded,
                                size: 60,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'مفيش ملفات في Download/ranges',
                              style: _noDeco.copyWith(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _files.length,
                        itemBuilder: (_, i) {
                          final f = _files[i];
                          final sel = f.name == widget.selected;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            child: Material(
                              color: sel
                                  ? theme.colorScheme.primary
                                      .withOpacity(0.15)
                                  : theme.colorScheme.surface
                                      .withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    Navigator.pop(context, f.name),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  child: Row(
                                    children: [
                                      Icon(
                                        sel
                                            ? Icons
                                                .radio_button_checked_rounded
                                            : Icons
                                                .radio_button_unchecked_rounded,
                                        color: sel
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface
                                                .withOpacity(0.4),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              f.name,
                                              style: _noDeco.copyWith(
                                                fontSize: 14,
                                                fontWeight: sel
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${f.count} رقم',
                                              style: _noDeco.copyWith(
                                                fontSize: 11,
                                                color: theme.colorScheme
                                                    .onSurface
                                                    .withOpacity(0.5),
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
                        },
                      ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}