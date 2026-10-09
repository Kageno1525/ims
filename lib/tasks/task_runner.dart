import 'dart:async';
import 'package:flutter/foundation.dart';
import 'task_model.dart';
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

  List<StepResult> get results => List.unmodifiable(_results);
  bool get running => _running;
  int get currentIndex => _currentIndex;

  Future<bool> run(Task task, {required Function(LogEntry) onLog}) async {
    if (_running) return false;
    _running = true;
    _results.clear();
    for (final s in task.steps) {
      _results.add(StepResult(stepId: s.id, status: StepStatus.pending));
    }
    _currentIndex = 0;
    notifyListeners();

    bool allOk = true;
    int i = 0;
    while (i < task.steps.length) {
      if (!_running) {
        onLog(LogEntry('🛑 تم الإيقاف', DateTime.now(), LogLevel.info));
        allOk = false;
        break;
      }
      _currentIndex = i;
      _results[i] = StepResult(
          stepId: task.steps[i].id, status: StepStatus.running);
      notifyListeners();

      final step = task.steps[i];
      onLog(LogEntry(
        '▶️ خطوة ${i + 1}/${task.steps.length}: ${step.typeLabel}',
        DateTime.now(),
        LogLevel.info,
      ));

      final ok = await _executeStepWithTimeout(step, onLog);

      if (ok) {
        _results[i] = StepResult(stepId: step.id, status: StepStatus.ok);
        notifyListeners();
        onLog(LogEntry(
          '✅ خطوة ${i + 1} نجحت',
          DateTime.now(),
          LogLevel.ok,
        ));

        if (step.waitAfterMs > 0) {
          await Future.delayed(Duration(milliseconds: step.waitAfterMs));
        }
        i++;
      } else {
        if (step.onFail == FailureAction.skip) {
          _results[i] = StepResult(
            stepId: step.id,
            status: StepStatus.skipped,
            message: 'اتخطت',
          );
          notifyListeners();
          onLog(LogEntry(
            '⏭️ تخطي الخطوة ${i + 1} والاستمرار',
            DateTime.now(),
            LogLevel.wait,
          ));
          if (step.waitAfterMs > 0) {
            await Future.delayed(Duration(milliseconds: step.waitAfterMs));
          }
          i++;
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
          allOk = false;
          break;
        }
      }
    }

    _running = false;
    _currentIndex = -1;
    notifyListeners();
    onLog(LogEntry(
      allOk ? '🎉 المهمة خلصت بنجاح' : '⚠️ المهمة توقفت',
      DateTime.now(),
      allOk ? LogLevel.ok : LogLevel.error,
    ));
    return allOk;
  }

  void stop() {
    _running = false;
    notifyListeners();
  }

  Future<bool> _executeStepWithTimeout(
      TaskStep step, Function(LogEntry) onLog) async {
    if (!step.isSearchStep || step.timeoutMs <= 0) {
      return await _executeStep(step, onLog);
    }

    final deadline =
        DateTime.now().add(Duration(milliseconds: step.timeoutMs));
    int attempt = 0;

    while (DateTime.now().isBefore(deadline)) {
      if (!_running) return false;
      attempt++;

      if (attempt > 1) {
        onLog(LogEntry(
          '🔄 محاولة $attempt…',
          DateTime.now(),
          LogLevel.wait,
        ));
      }

      final ok = await _executeStep(step, onLog);
      if (ok) {
        if (attempt > 1) {
          onLog(LogEntry(
            '✅ نجحت بعد $attempt محاولة',
            DateTime.now(),
            LogLevel.ok,
          ));
        }
        return true;
      }

      final delay = (100 * attempt).clamp(100, 900);
      final remaining = deadline.difference(DateTime.now()).inMilliseconds;
      if (remaining <= 0) break;
      await Future.delayed(Duration(milliseconds: delay.clamp(0, remaining)));
    }

    onLog(LogEntry(
      '⏱️ انتهت المهلة (${step.timeoutMs} مللي، $attempt محاولة)',
      DateTime.now(),
      LogLevel.error,
    ));
    return false;
  }

  Future<bool> _executeStep(TaskStep step, Function(LogEntry) onLog) async {
    try {
      switch (step.type) {
        case TaskStepType.openApp:
          final pkg = step.params['package']?.toString() ?? '';
          if (pkg.isEmpty) return false;
          return await AutoFillBridge.openApp(pkg);

        case TaskStepType.wait:
          final ms =
              int.tryParse(step.params['ms']?.toString() ?? '1000') ?? 1000;
          await Future.delayed(Duration(milliseconds: ms));
          return true;

        case TaskStepType.typeText:
          final text = step.params['text']?.toString() ?? '';
          return await AutoFillBridge.typeText(text);

        case TaskStepType.clickByText:
          final text = step.params['text']?.toString() ?? '';
          if (text.isEmpty) return false;
          return await AutoFillBridge.clickByText(text);

        case TaskStepType.clickByDesc:
          final desc = step.params['desc']?.toString() ?? '';
          if (desc.isEmpty) return false;
          return await AutoFillBridge.clickByDesc(desc);

        case TaskStepType.clickById:
          final viewId = step.params['viewId']?.toString() ?? '';
          if (viewId.isEmpty) return false;
          return await AutoFillBridge.clickById(viewId);

        case TaskStepType.clickAt:
          final x = int.tryParse(step.params['x']?.toString() ?? '0') ?? 0;
          final y = int.tryParse(step.params['y']?.toString() ?? '0') ?? 0;
          return await AutoFillBridge.clickAt(x, y);

        case TaskStepType.swipe:
          final x1 = int.tryParse(step.params['x1']?.toString() ?? '0') ?? 0;
          final y1 = int.tryParse(step.params['y1']?.toString() ?? '0') ?? 0;
          final x2 = int.tryParse(step.params['x2']?.toString() ?? '0') ?? 0;
          final y2 = int.tryParse(step.params['y2']?.toString() ?? '0') ?? 0;
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