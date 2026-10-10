import 'dart:async';
import 'package:flutter/foundation.dart';
import 'task_model.dart';
import 'template_resolver.dart';
import '../autofill_bridge.dart';
import '../models.dart';

enum StepStatus { pending, running, ok, failed, skipped }

class StepResult {
  final String stepId;
  final StepStatus status;
  final String? message;
  StepResult({required this.stepId, required this.status, this.message});
}

class TaskRunner extends ChangeNotifier {
  final List<StepResult> _results = [];
  bool _running = false;
  int _currentIndex = -1;
  int _currentTaskRound = 0;
  int _totalTaskRounds = 1;

  List<StepResult> get results => List.unmodifiable(_results);
  bool get running => _running;
  int get currentIndex => _currentIndex;
  int get currentTaskRound => _currentTaskRound;
  int get totalTaskRounds => _totalTaskRounds;

  Future<bool> run(
    Task task, {
    required Function(LogEntry) onLog,
    List<String> numbers = const [],
    int currentIndex = 0,
  }) async {
    if (_running) return false;
    _running = true;

    final totalRounds = task.repeatCount < 1 ? 1 : task.repeatCount;
    _totalTaskRounds = totalRounds;

    bool allOk = true;

    for (int round = 0; round < totalRounds; round++) {
      if (!_running) {
        allOk = false;
        break;
      }

      _currentTaskRound = round;

      if (totalRounds > 1) {
        onLog(LogEntry(
          '🔁 دورة ${round + 1}/$totalRounds',
          DateTime.now(),
          LogLevel.info,
        ));
      }

      _results.clear();
      for (final s in task.steps) {
        _results.add(StepResult(stepId: s.id, status: StepStatus.pending));
      }
      _currentIndex = 0;
      notifyListeners();

      final effectiveIndex = task.autoIncrement
          ? currentIndex + round
          : currentIndex;

      final roundOk = await _runSingleRound(
        task,
        onLog: onLog,
        numbers: numbers,
        currentIndex: effectiveIndex,
      );

      if (!roundOk) {
        allOk = false;
        break;
      }
    }

    _running = false;
    _currentIndex = -1;
    _currentTaskRound = 0;
    notifyListeners();

    onLog(LogEntry(
      allOk ? '🎉 المهمة خلصت بنجاح' : '⚠️ المهمة توقفت',
      DateTime.now(),
      allOk ? LogLevel.ok : LogLevel.error,
    ));
    return allOk;
  }

  Future<bool> _runSingleRound(
    Task task, {
    required Function(LogEntry) onLog,
    required List<String> numbers,
    required int currentIndex,
  }) async {
    int i = 0;

    while (i < task.steps.length) {
      if (!_running) return false;

      _currentIndex = i;
      _results[i] = StepResult(
        stepId: task.steps[i].id,
        status: StepStatus.running,
      );
      notifyListeners();

      final step = task.steps[i];
      onLog(LogEntry(
        '▶️ خطوة ${i + 1}/${task.steps.length}: ${step.typeLabel}'
        '${step.repeatCount > 1 ? " (×${step.repeatCount})" : ""}'
        '${step.speedMode ? " ⚡" : ""}',
        DateTime.now(),
        LogLevel.info,
      ));

      final resolved = _resolveStep(step, numbers, currentIndex);

      final stepRepeat = resolved.repeatCount < 1 ? 1 : resolved.repeatCount;
      bool stepOk = false;
      bool needSkip = false;
      int skipTotal = 0;

      for (int r = 0; r < stepRepeat; r++) {
        if (!_running) return false;

        if (stepRepeat > 1) {
          onLog(LogEntry(
            '  ↻ تكرار ${r + 1}/$stepRepeat',
            DateTime.now(),
            LogLevel.wait,
          ));
        }

        if (resolved.type == TaskStepType.waitForElement) {
          final outcome = await _runWaitForElement(
            resolved, i, task.steps.length, onLog, numbers, currentIndex,
          );

          if (outcome == _WaitOutcome.found) {
            stepOk = true;
          } else {
            final nfResult = await _handleNotFound(
              resolved, i, task.steps.length, onLog, numbers, currentIndex,
            );

            if (nfResult == _NotFoundOutcome.stop) {
              _results[i] = StepResult(
                stepId: step.id,
                status: StepStatus.failed,
                message: 'فشل',
              );
              notifyListeners();
              onLog(LogEntry(
                '❌ فشل الخطوة ${i + 1} - وقف المهمة',
                DateTime.now(),
                LogLevel.error,
              ));
              return false;
            } else if (nfResult == _NotFoundOutcome.skipped) {
              needSkip = true;
              skipTotal = 1 + resolved.skipCount;
              break;
            } else {
              stepOk = true;
              onLog(LogEntry(
                '⚠️ العنصر ما ظهرش — اتعمل إجراء بديل',
                DateTime.now(),
                LogLevel.wait,
              ));
            }
          }
        } else {
          final ok = await _executeStepWithTimeout(resolved, onLog);
          if (ok) {
            stepOk = true;
          } else {
            if (step.onFail == FailureAction.skip) {
              needSkip = true;
              skipTotal = 1 + step.skipCount;
              break;
            } else {
              _results[i] = StepResult(
                stepId: step.id,
                status: StepStatus.failed,
                message: 'فشل',
              );
              notifyListeners();
              onLog(LogEntry(
                '❌ فشل الخطوة ${i + 1} - وقف المهمة',
                DateTime.now(),
                LogLevel.error,
              ));
              return false;
            }
          }
        }
      }

      if (needSkip) {
        for (int k = 0;
            k < skipTotal && i + k < task.steps.length;
            k++) {
          _results[i + k] = StepResult(
            stepId: task.steps[i + k].id,
            status: StepStatus.skipped,
            message: k == 0 ? 'اتخطت' : 'تم تخطيها',
          );
        }
        notifyListeners();
        onLog(LogEntry(
          '⏭️ تخطي $skipTotal خطوة والاستمرار',
          DateTime.now(),
          LogLevel.wait,
        ));
        if (step.waitAfterMs > 0) {
          await Future.delayed(Duration(milliseconds: step.waitAfterMs));
        }
        i += skipTotal;
        continue;
      }

      if (stepOk) {
        _results[i] = StepResult(stepId: step.id, status: StepStatus.ok);
        notifyListeners();
        onLog(LogEntry(
            '✅ خطوة ${i + 1} نجحت', DateTime.now(), LogLevel.ok));
        // ⭐ الفاصل اللي المستخدم حطه — مش بنشيله
        if (step.waitAfterMs > 0) {
          await Future.delayed(Duration(milliseconds: step.waitAfterMs));
        }
        i++;
      }
    }

    return true;
  }

  TaskStep _resolveStep(
      TaskStep step, List<String> numbers, int currentIndex) {
    final newParams = <String, dynamic>{};
    for (final e in step.params.entries) {
      final v = e.value;
      if (v is String && TemplateResolver.hasVariables(v)) {
        newParams[e.key] = TemplateResolver.resolve(
          v,
          numbers: numbers,
          currentIndex: currentIndex,
        );
      } else {
        newParams[e.key] = v;
      }
    }
    String resolveStr(String s) {
      if (s.isEmpty || !TemplateResolver.hasVariables(s)) return s;
      return TemplateResolver.resolve(
        s,
        numbers: numbers,
        currentIndex: currentIndex,
      );
    }

    return step.copyWith(
      params: newParams,
      appearText: resolveStr(step.appearText),
      altText: resolveStr(step.altText),
      altDesc: resolveStr(step.altDesc),
      altViewId: resolveStr(step.altViewId),
      altTypeText: resolveStr(step.altTypeText),
    );
  }

  // ═══════════════ Wait For Element ═══════════════
  Future<_WaitOutcome> _runWaitForElement(
    TaskStep step,
    int stepIndex,
    int totalSteps,
    Function(LogEntry) onLog,
    List<String> numbers,
    int currentIndex,
  ) async {
    final text = step.params['text']?.toString() ?? '';
    final desc = step.params['desc']?.toString() ?? '';
    final viewId = step.params['viewId']?.toString() ?? '';
    final className = step.params['className']?.toString() ?? '';
    final idx = int.tryParse(
            step.params['elementIndex']?.toString() ?? '0') ??
        0;

    final timeout = step.timeoutMs > 0 ? step.timeoutMs : 5000;
    final deadline = DateTime.now().add(Duration(milliseconds: timeout));
    int attempt = 0;

    // ⭐ polling interval حسب وضع السرعة
    final pollMs = step.speedMode ? 20 : 100;

    while (DateTime.now().isBefore(deadline)) {
      if (!_running) return _WaitOutcome.notFound;
      attempt++;
      if (!step.speedMode && attempt > 1 && attempt % 5 == 0) {
        onLog(LogEntry('🔄 محاولة $attempt…', DateTime.now(),
            LogLevel.wait));
      }

      final found = await AutoFillBridge.findElement(
        text: text,
        desc: desc,
        viewId: viewId,
        className: className,
        index: idx,
      );

      if (found) {
        onLog(LogEntry('✅ العنصر ظهر!', DateTime.now(), LogLevel.ok));
        if (step.onAppear == OnAppearAction.click) {
          onLog(LogEntry('👆 اضغط عليه…', DateTime.now(), LogLevel.info));
          await AutoFillBridge.smartClick(
            text: text,
            desc: desc,
            viewId: viewId,
            className: className,
            index: idx,
            preferClickable: true,
          );
        } else if (step.onAppear == OnAppearAction.type) {
          onLog(LogEntry('⌨️ اكتب فيه "${step.appearText}"…',
              DateTime.now(), LogLevel.info));
          await AutoFillBridge.smartType(
            value: step.appearText,
            viewId: viewId,
            hint: step.params['hint']?.toString() ?? '',
            className: className,
            index: idx,
          );
        }
        return _WaitOutcome.found;
      }

      // ⭐ في وضع السرعة: 20ms ثابت
      // ⭐ في الوضع العادي: 100ms مع backoff أقصى 700ms
      int delay;
      if (step.speedMode) {
        delay = pollMs;
      } else {
        delay = (100 * attempt).clamp(100, 700);
      }

      final remaining =
          deadline.difference(DateTime.now()).inMilliseconds;
      if (remaining <= 0) break;
      await Future.delayed(
          Duration(milliseconds: delay.clamp(0, remaining)));
    }

    onLog(LogEntry(
      '⏱️ العنصر ما ظهرش بعد ${(timeout / 1000).toStringAsFixed(0)}ث ($attempt محاولة)',
      DateTime.now(),
      LogLevel.error,
    ));
    return _WaitOutcome.notFound;
  }

  Future<_NotFoundOutcome> _handleNotFound(
    TaskStep step,
    int stepIndex,
    int totalSteps,
    Function(LogEntry) onLog,
    List<String> numbers,
    int currentIndex,
  ) async {
    switch (step.onNotFound) {
      case NotFoundAction.stop:
        return _NotFoundOutcome.stop;
      case NotFoundAction.skip:
        return _NotFoundOutcome.skipped;
      case NotFoundAction.clickAlt:
        onLog(LogEntry('🖱️ اضغط على البديل', DateTime.now(),
            LogLevel.info));
        await AutoFillBridge.smartClick(
          text: step.altText,
          desc: step.altDesc,
          viewId: step.altViewId,
          preferClickable: true,
        );
        return _NotFoundOutcome.handled;
      case NotFoundAction.typeAlt:
        onLog(LogEntry('⌨️ اكتب البديل: "${step.altTypeText}"',
            DateTime.now(), LogLevel.info));
        await AutoFillBridge.typeText(step.altTypeText);
        return _NotFoundOutcome.handled;
      case NotFoundAction.back:
        onLog(LogEntry('⬅️ رجوع', DateTime.now(), LogLevel.info));
        await AutoFillBridge.globalBack();
        return _NotFoundOutcome.handled;
      case NotFoundAction.home:
        onLog(LogEntry('🏠 الرئيسية', DateTime.now(), LogLevel.info));
        await AutoFillBridge.globalHome();
        return _NotFoundOutcome.handled;
    }
  }

  void stop() {
    _running = false;
    notifyListeners();
  }

  // ═══════════════ Execute with timeout ═══════════════
  Future<bool> _executeStepWithTimeout(
      TaskStep step, Function(LogEntry) onLog) async {
    if (!step.isSearchStep || step.timeoutMs <= 0) {
      return await _executeStep(step, onLog);
    }
    final deadline =
        DateTime.now().add(Duration(milliseconds: step.timeoutMs));
    int attempt = 0;

    // ⭐ polling interval حسب وضع السرعة
    final baseDelay = step.speedMode ? 20 : 100;

    while (DateTime.now().isBefore(deadline)) {
      if (!_running) return false;
      attempt++;
      if (!step.speedMode && attempt > 1 && attempt % 3 == 0) {
        onLog(LogEntry('🔄 محاولة $attempt…', DateTime.now(),
            LogLevel.wait));
      }
      final ok = await _executeStep(step, onLog);
      if (ok) {
        if (attempt > 1) {
          onLog(LogEntry('✅ نجحت بعد $attempt محاولة',
              DateTime.now(), LogLevel.ok));
        }
        return true;
      }

      // ⭐ في وضع السرعة: 20ms ثابت
      // ⭐ في الوضع العادي: backoff أقصى 900ms
      int delay;
      if (step.speedMode) {
        delay = baseDelay;
      } else {
        delay = (100 * attempt).clamp(100, 900);
      }

      final remaining =
          deadline.difference(DateTime.now()).inMilliseconds;
      if (remaining <= 0) break;
      await Future.delayed(
          Duration(milliseconds: delay.clamp(0, remaining)));
    }
    onLog(LogEntry(
      '⏱️ انتهت المهلة (${step.timeoutMs} مللي، $attempt محاولة)',
      DateTime.now(),
      LogLevel.error,
    ));
    return false;
  }

  Future<bool> _executeStep(
      TaskStep step, Function(LogEntry) onLog) async {
    try {
      switch (step.type) {
        case TaskStepType.openApp:
          final pkg = step.params['package']?.toString() ?? '';
          if (pkg.isEmpty) return false;
          return await AutoFillBridge.openApp(pkg);

        case TaskStepType.clearAppData:
          final pkg = step.params['package']?.toString() ?? '';
          if (pkg.isEmpty) return false;
          return await AutoFillBridge.clearAppData(pkg);

        case TaskStepType.wait:
          final ms =
              int.tryParse(step.params['ms']?.toString() ?? '1000') ??
                  1000;
          await Future.delayed(Duration(milliseconds: ms));
          return true;

        case TaskStepType.typeText:
          final value = step.params['text']?.toString() ?? '';
          final viewId = step.params['viewId']?.toString() ?? '';
          final hint = step.params['hint']?.toString() ?? '';
          final className =
              step.params['className']?.toString() ?? '';
          final index = int.tryParse(
                  step.params['elementIndex']?.toString() ?? '0') ??
              0;
          if (viewId.isNotEmpty ||
              hint.isNotEmpty ||
              className.isNotEmpty
          ) {
            return await AutoFillBridge.smartType(
              value: value,
              viewId: viewId,
              hint: hint,
              className: className,
              index: index,
            );
          }
          return await AutoFillBridge.typeText(value);

        case TaskStepType.clickByText:
        case TaskStepType.clickByDesc:
        case TaskStepType.clickById:
          return await AutoFillBridge.smartClick(
            text: step.params['text']?.toString() ?? '',
            desc: step.params['desc']?.toString() ?? '',
            viewId: step.params['viewId']?.toString() ?? '',
            className: step.params['className']?.toString() ?? '',
            index: int.tryParse(
                    step.params['elementIndex']?.toString() ?? '0') ??
                0,
            preferClickable: step.params['preferClickable'] != false,
          );

        case TaskStepType.waitForElement:
          return await AutoFillBridge.findElement(
            text: step.params['text']?.toString() ?? '',
            desc: step.params['desc']?.toString() ?? '',
            viewId: step.params['viewId']?.toString() ?? '',
            className: step.params['className']?.toString() ?? '',
            index: int.tryParse(
                    step.params['elementIndex']?.toString() ?? '0') ??
                0,
          );

        case TaskStepType.clickAt:
          final x =
              int.tryParse(step.params['x']?.toString() ?? '0') ?? 0;
          final y =
              int.tryParse(step.params['y']?.toString() ?? '0') ?? 0;
          return await AutoFillBridge.clickAt(x, y);

        case TaskStepType.swipe:
          final x1 =
              int.tryParse(step.params['x1']?.toString() ?? '0') ?? 0;
          final y1 =
              int.tryParse(step.params['y1']?.toString() ?? '0') ?? 0;
          final x2 =
              int.tryParse(step.params['x2']?.toString() ?? '0') ?? 0;
          final y2 =
              int.tryParse(step.params['y2']?.toString() ?? '0') ?? 0;
          final d = int.tryParse(
                  step.params['duration']?.toString() ?? '300') ??
              300;
          return await AutoFillBridge.swipe(x1, y1, x2, y2, d);

        case TaskStepType.back:
          return await AutoFillBridge.globalBack();

        case TaskStepType.home:
          return await AutoFillBridge.globalHome();

        case TaskStepType.recents:
          return await AutoFillBridge.globalRecents();
      }
    } catch (e) {
      onLog(LogEntry('خطأ: $e', DateTime.now(), LogLevel.error));
      return false;
    }
  }
}

enum _WaitOutcome { found, notFound }
enum _NotFoundOutcome { stop, skipped, handled }