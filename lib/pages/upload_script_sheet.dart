import 'package:flutter/material.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore_service.dart';
import '../tasks/task_model.dart';

const _noDeco = TextStyle(
  decoration: TextDecoration.none,
  decorationColor: Colors.transparent,
);

Future<bool?> showUploadScriptSheet(
  BuildContext context, {
  required bool isDark,
  required Task task,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _UploadScriptSheet(
      isDark: isDark,
      task: task,
    ),
  );
}

class _UploadScriptSheet extends StatefulWidget {
  final bool isDark;
  final Task task;
  const _UploadScriptSheet({
    required this.isDark,
    required this.task,
  });

  @override
  State<_UploadScriptSheet> createState() => _UploadScriptSheetState();
}

class _UploadScriptSheetState extends State<_UploadScriptSheet> {
  bool _uploading = false;
  String? _error;

  Future<void> _upload() async {
    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final uid = AuthService.uid ?? '';
      final stepsJson =
          widget.task.steps.map((s) => s.toJson()).toList();

      // ⭐ ارفع بدون تحديد مستخدمين
      await FirestoreService.uploadScript(
        name: widget.task.name,
        steps: stepsJson,
        assignedTo: const [],   // ← فاضي
        createdBy: uid,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(16),
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
                    Icons.cloud_upload_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رفع سكربت',
                        style: _noDeco.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.task.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _noDeco.copyWith(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00D2FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF00D2FF).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF00D2FF), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'السكربت هيتحفظ في صفحة "السكربتات" — تقدر تحدد المستخدمين بعدين من هناك',
                      style: _noDeco.copyWith(
                        fontSize: 11.5,
                        color: const Color(0xFF00D2FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: theme.colorScheme.error.withOpacity(0.35)),
                ),
                child: Text(
                  _error!,
                  style: _noDeco.copyWith(
                      fontSize: 12, color: theme.colorScheme.error),
                ),
              ),
            ],

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _uploading
                        ? null
                        : () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'إلغاء',
                      style: _noDeco.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: _uploading
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFF6C5CE7),
                                Color(0xFF00D2FF),
                              ],
                            ),
                      color: _uploading
                          ? theme.colorScheme.onSurface.withOpacity(0.1)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _uploading ? null : _upload,
                        child: Center(
                          child: _uploading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.cloud_upload_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'رفع',
                                      style: _noDeco.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}