import 'package:flutter/material.dart';
import '../csv_reader.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore_service.dart';
import '../models.dart';
import '../tasks/task_model.dart';

const _noDeco = TextStyle(
  decoration: TextDecoration.none,
  decorationColor: Colors.transparent,
);

Future<bool?> showUploadScriptSheet(
  BuildContext context, {
  required bool isDark,
  required Task task,
  ScriptRules? initialRules,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _UploadScriptSheet(
      isDark: isDark,
      task: task,
      initialRules: initialRules,
    ),
  );
}

class _UploadScriptSheet extends StatefulWidget {
  final bool isDark;
  final Task task;
  final ScriptRules? initialRules;
  const _UploadScriptSheet({
    required this.isDark,
    required this.task,
    this.initialRules,
  });

  @override
  State<_UploadScriptSheet> createState() => _UploadScriptSheetState();
}

class _UploadScriptSheetState extends State<_UploadScriptSheet> {
  bool _uploading = false;
  String? _error;

  // ⭐ Rules state
  late bool _allowRunCount;
  late int _defaultRunCount;
  late int _maxRunCount;
  late bool _allowRange;
  late String _defaultRange;

  // ⭐ Ranges
  List<CsvFile> _ranges = [];
  bool _loadingRanges = true;

  late TextEditingController _runCountCtrl;
  late TextEditingController _maxRunCountCtrl;

  @override
  void initState() {
    super.initState();

    final r = widget.initialRules;
    _allowRunCount = r?.allowRunCount ?? false;
    _defaultRunCount = r?.defaultRunCount ?? 1;
    _maxRunCount = r?.maxRunCount ?? 100;
    _allowRange = r?.allowRange ?? false;
    _defaultRange = r?.defaultRange ?? '';

    _runCountCtrl =
        TextEditingController(text: _defaultRunCount.toString());
    _maxRunCountCtrl =
        TextEditingController(text: _maxRunCount.toString());

    _loadRanges();
  }

  @override
  void dispose() {
    _runCountCtrl.dispose();
    _maxRunCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRanges() async {
    try {
      final list = await CsvReader.listFiles();
      if (!mounted) return;
      setState(() {
        _ranges = list;
        _loadingRanges = false;
        if (list.isNotEmpty && _defaultRange.isEmpty) {
          _defaultRange = list.first.name;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingRanges = false);
      }
    }
  }

  Future<void> _upload() async {
    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final uid = AuthService.uid ?? '';
      final stepsJson =
          widget.task.steps.map((s) => s.toJson()).toList();

      final rules = ScriptRules(
        allowRunCount: _allowRunCount,
        defaultRunCount: _defaultRunCount,
        maxRunCount: _maxRunCount,
        allowRange: _allowRange,
        defaultRange: _defaultRange,
      );

      await FirestoreService.uploadScript(
        name: widget.task.name,
        steps: stepsJson,
        assignedTo: const [],
        createdBy: uid,
        rules: rules,
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
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

              _sectionTitle(theme, Icons.rule_rounded, 'قواعد السكربت',
                  const Color(0xFF6C5CE7)),
              const SizedBox(height: 10),

              _ruleCard(
                theme,
                icon: Icons.repeat_rounded,
                title: 'السماح بتغيير عدد المرات',
                subtitle: _allowRunCount
                    ? 'اليوزر يقدر يختار العدد (1 - $_maxRunCount)'
                    : 'اليوزر يستخدم القيمة الافتراضية ($_defaultRunCount)',
                color: const Color(0xFF6C5CE7),
                value: _allowRunCount,
                onChanged: (v) => setState(() => _allowRunCount = v),
              ),

              if (_allowRunCount) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _smallField(
                        theme,
                        controller: _runCountCtrl,
                        label: 'الافتراضي',
                        onChanged: (v) {
                          final n = int.tryParse(v) ?? 1;
                          if (n >= 1) {
                            setState(() => _defaultRunCount = n);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _smallField(
                        theme,
                        controller: _maxRunCountCtrl,
                        label: 'الحد الأقصى',
                        onChanged: (v) {
                          final n = int.tryParse(v) ?? 100;
                          if (n >= 1) {
                            setState(() => _maxRunCount = n);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              _ruleCard(
                theme,
                icon: Icons.folder_rounded,
                title: 'السماح بتغيير الرنج',
                subtitle: _allowRange
                    ? 'اليوزر يقدر يختار رنج مختلف'
                    : 'اليوزر يستخدم الرنج الثابت',
                color: const Color(0xFF00D68F),
                value: _allowRange,
                onChanged: (v) => setState(() => _allowRange = v),
              ),

              const SizedBox(height: 10),

              _rangePicker(theme),

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
                        gradient: _uploading
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF6C5CE7),
                                  Color(0xFF00D2FF),
                                ],
                              ),
                        color: _uploading
                            ? theme.colorScheme.onSurface
                                .withOpacity(0.1)
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
      ),
    );
  }

  Widget _sectionTitle(
      ThemeData theme, IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: _noDeco.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _ruleCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: value
            ? color.withOpacity(0.12)
            : theme.colorScheme.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? color
              : theme.colorScheme.primary.withOpacity(0.15),
          width: value ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: value
                  ? color
                  : theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _noDeco.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: value
                        ? color
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: _noDeco.copyWith(
                    fontSize: 10.5,
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  Widget _smallField(
    ThemeData theme, {
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: _noDeco.copyWith(
          fontSize: 16, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _noDeco.copyWith(fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 14),
      ),
      onChanged: onChanged,
    );
  }

  Widget _rangePicker(ThemeData theme) {
    if (_loadingRanges) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('جاري تحميل الرنجات…',
                style: _noDeco.copyWith(fontSize: 12)),
          ],
        ),
      );
    }

    if (_ranges.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB84D).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFFFB84D).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFFB84D), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'مفيش ملفات في Download/ranges — نزّل من صفحة الأرقام الأول',
                style: _noDeco.copyWith(
                  fontSize: 11.5,
                  color: const Color(0xFFFFB84D),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF00D68F).withOpacity(0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _defaultRange.isEmpty ? null : _defaultRange,
          isExpanded: true,
          dropdownColor: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          style: _noDeco.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600),
          hint: Text('الرنج الافتراضي',
              style: _noDeco.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5))),
          items: _ranges
              .map((f) => DropdownMenuItem<String>(
                    value: f.name,
                    child: Row(
                      children: [
                        const Icon(Icons.folder_rounded,
                            size: 16, color: Color(0xFF00D68F)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f.name,
                            overflow: TextOverflow.ellipsis,
                            style: _noDeco.copyWith(fontSize: 13),
                          ),
                        ),
                        Text(
                          '${f.count}',
                          style: _noDeco.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _defaultRange = v);
          },
        ),
      ),
    );
  }
}