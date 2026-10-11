import 'package:flutter/material.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore_service.dart';
import '../models.dart';
import '../tasks/task_model.dart';

const _noDeco = TextStyle(
  decoration: TextDecoration.none,
  decorationColor: Colors.transparent,
);

/// Bottom sheet لاختيار المستخدمين اللي هيتعرضلهم السكربت
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
  Set<String> _selected = {};
  bool _uploading = false;
  bool _loading = true;
  List<UserProfile> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final snap = await FirestoreService.allUsersStream().first;
      if (!mounted) return;
      setState(() {
        _users = snap.where((u) => !u.isAdmin && !u.isBanned).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختار مستخدم واحد على الأقل'),
        ),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      final uid = AuthService.uid ?? '';
      final stepsJson =
          widget.task.steps.map((s) => s.toJson()).toList();

      await FirestoreService.uploadScript(
        name: widget.task.name,
        steps: stepsJson,
        assignedTo: _selected.toList(),
        createdBy: uid,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الرفع: $e')),
      );
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
            // شريط السحب
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

            // العنوان
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

            // ملاحظة
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00D2FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF00D2FF).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF00D2FF), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'السكربت ده هيظهر في تطبيق Users للمستخدمين اللي هتختارهم',
                      style: _noDeco.copyWith(
                        fontSize: 11,
                        color: const Color(0xFF00D2FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // قائمة المستخدمين
            Row(
              children: [
                Text(
                  'المستخدمين',
                  style: _noDeco.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                if (_loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_users.length}',
                      style: _noDeco.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                const Spacer(),
                // اختار الكل
                TextButton(
                  onPressed: _users.isEmpty
                      ? null
                      : () {
                          setState(() {
                            if (_selected.length == _users.length) {
                              _selected.clear();
                            } else {
                              _selected =
                                  _users.map((u) => u.uid).toSet();
                            }
                          });
                        },
                  child: Text(
                    _selected.length == _users.length && _users.isNotEmpty
                        ? 'إلغاء الكل'
                        : 'اختار الكل',
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

            // القائمة
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 50,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.3),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'مفيش مستخدمين عاديين',
                                style: _noDeco.copyWith(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'ضيف مستخدمين من صفحة التحكم',
                                style: _noDeco.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _users.length,
                          itemBuilder: (_, i) {
                            final user = _users[i];
                            final isOn = _selected.contains(user.uid);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setState(() {
                                      if (isOn) {
                                        _selected.remove(user.uid);
                                      } else {
                                        _selected.add(user.uid);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isOn
                                          ? const Color(0xFF00D68F)
                                              .withOpacity(0.12)
                                          : theme.colorScheme.surface
                                              .withOpacity(0.4),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isOn
                                            ? const Color(0xFF00D68F)
                                            : theme.colorScheme.primary
                                                .withOpacity(0.15),
                                        width: isOn ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isOn
                                              ? Icons
                                                  .check_box_rounded
                                              : Icons
                                                  .check_box_outline_blank_rounded,
                                          color: isOn
                                              ? const Color(0xFF00D68F)
                                              : theme.colorScheme.onSurface
                                                  .withOpacity(0.4),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.name.isEmpty
                                                    ? user.email
                                                    : user.name,
                                                maxLines: 1,
                                                overflow: TextOverflow
                                                    .ellipsis,
                                                style: _noDeco.copyWith(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                              if (user.name.isNotEmpty)
                                                Text(
                                                  user.email,
                                                  maxLines: 1,
                                                  overflow: TextOverflow
                                                      .ellipsis,
                                                  style: _noDeco.copyWith(
                                                    fontSize: 10.5,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(
                                                            0.5),
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

            // الأزرار
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _uploading
                        ? null
                        : () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
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
                      gradient: _uploading || _selected.isEmpty
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFF6C5CE7),
                                Color(0xFF00D2FF),
                              ],
                            ),
                      color: _uploading || _selected.isEmpty
                          ? theme.colorScheme.onSurface.withOpacity(0.1)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _uploading || _selected.isEmpty
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF6C5CE7)
                                    .withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _uploading || _selected.isEmpty
                            ? null
                            : _upload,
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
                                      'رفع (${_selected.length})',
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