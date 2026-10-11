import 'package:flutter/material.dart';
import '../firebase/firestore_service.dart';
import '../models.dart';
import '../widgets.dart';

class AdminScriptsPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onBack;

  const AdminScriptsPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onBack,
  });

  @override
  State<AdminScriptsPage> createState() => _AdminScriptsPageState();
}

class _AdminScriptsPageState extends State<AdminScriptsPage> {
  static const _noDeco = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

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
                        Text('السكربتات',
                            style: _noDeco.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            )),
                        StreamBuilder<List<ScriptDoc>>(
                          stream: FirestoreService.allScriptsStream(),
                          builder: (_, snap) {
                            final c = snap.data?.length ?? 0;
                            return Text(
                              '$c سكربت',
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
              const SizedBox(height: 14),
              Expanded(
                child: StreamBuilder<List<ScriptDoc>>(
                  stream: FirestoreService.allScriptsStream(),
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

  Widget _scriptCard(ThemeData theme, ScriptDoc doc) {
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_special_rounded,
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
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doc.steps.length} خطوة',
                      style: _noDeco.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _infoChip(
                theme,
                Icons.people_rounded,
                '${doc.assignedTo.length} مستخدم',
                doc.assignedTo.isEmpty
                    ? const Color(0xFF95A5A6)
                    : const Color(0xFF00D68F),
              ),
              // ⭐ chips للقواعد
              if (doc.rules.allowRunCount)
                _infoChip(
                  theme,
                  Icons.repeat_rounded,
                  'عدد المرات (${doc.rules.defaultRunCount}-${doc.rules.maxRunCount})',
                  const Color(0xFF6C5CE7),
                ),
              if (doc.rules.allowRange)
                _infoChip(
                  theme,
                  Icons.folder_rounded,
                  'الرنج متغير',
                  const Color(0xFF00D2FF),
                ),
              if (!doc.rules.allowRunCount && !doc.rules.allowRange)
                _infoChip(
                  theme,
                  Icons.lock_rounded,
                  'بدون قواعد',
                  const Color(0xFF95A5A6),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniBtn(
                  theme,
                  icon: Icons.people_alt_rounded,
                  label: 'المستخدمين',
                  color: const Color(0xFF00D2FF),
                  onTap: () => _showAssignDialog(doc),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniBtn(
                  theme,
                  icon: Icons.rule_rounded,
                  label: 'القواعد',
                  color: const Color(0xFF6C5CE7),
                  onTap: () => _showRulesDialog(doc),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniBtn(
                  theme,
                  icon: Icons.delete_outline_rounded,
                  label: 'حذف',
                  color: const Color(0xFFFF6B6B),
                  onTap: () => _confirmDelete(doc),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(
      ThemeData theme, IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: _noDeco.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: _noDeco.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off_rounded,
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
            'ارفع سكربت من صفحة المهام',
            style: _noDeco.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(ScriptDoc doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('حذف السكربت',
            style: _noDeco.copyWith(fontWeight: FontWeight.bold)),
        content: Text(
          'متأكد إنك عايز تحذف "${doc.name}"؟\nهيتشال من كل المستخدمين.',
          style: _noDeco.copyWith(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: _noDeco),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('حذف',
                style: _noDeco.copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirestoreService.deleteScript(doc.id);
    }
  }

  Future<void> _showAssignDialog(ScriptDoc doc) async {
    final allUsersSnap =
        await FirestoreService.allUsersStream().first;
    final users =
        allUsersSnap.where((u) => !u.isAdmin && !u.isBanned).toList();
    final selected = Set<String>.from(doc.assignedTo);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.people_alt_rounded,
                    color: Color(0xFF00D2FF), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    doc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _noDeco.copyWith(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('حدد المستخدمين اللي عايز السكربت يظهر عندهم',
                      style: _noDeco.copyWith(
                          fontSize: 12,
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6))),
                  const SizedBox(height: 12),
                  if (users.isEmpty)
                    Text('مفيش مستخدمين',
                        style: _noDeco.copyWith(
                            fontSize: 13,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5)))
                  else
                    ...users.map((u) {
                      final isOn = selected.contains(u.uid);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          u.name.isEmpty ? u.username : u.name,
                          style: _noDeco.copyWith(fontSize: 13),
                        ),
                        subtitle: Text('@${u.username}',
                            style: _noDeco.copyWith(
                                fontSize: 10,
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5))),
                        value: isOn,
                        onChanged: (v) {
                          setModal(() {
                            if (v == true) {
                              selected.add(u.uid);
                            } else {
                              selected.remove(u.uid);
                            }
                          });
                        },
                      );
                    }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: _noDeco),
              ),
              TextButton(
                onPressed: () async {
                  await FirestoreService.updateScript(doc.id, {
                    'assignedTo': selected.toList(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text('حفظ (${selected.length})',
                    style: _noDeco.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00D68F))),
              ),
            ],
          );
        });
      },
    );
  }

  // ⭐ حوار قواعد السكربت — الأدمن يعدّلها
  Future<void> _showRulesDialog(ScriptDoc doc) async {
    bool allowRunCount = doc.rules.allowRunCount;
    bool allowRange = doc.rules.allowRange;

    final defaultRunCtrl = TextEditingController(
        text: doc.rules.defaultRunCount.toString());
    final maxRunCtrl = TextEditingController(
        text: doc.rules.maxRunCount.toString());
    String defaultRange = doc.rules.defaultRange;

    // جيب الرنجات المتاحة
    List<String> availableRanges = [];
    try {
      final scripts = await FirestoreService.allScriptsStream().first;
      // ملاحظة: الرنجات بتيجي من الملفات المحلية على جهاز اليوزر
      // هنا في الأدمن بس بنحفظ اسم الرنج
    } catch (_) {}

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
                  child: Text('قواعد السكربت',
                      style: _noDeco.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 15)),
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
                    Text(doc.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _noDeco.copyWith(
                            fontSize: 12,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6))),
                    const SizedBox(height: 14),

                    // عدد المرات
                    _ruleSwitch(
                      theme: Theme.of(ctx),
                      icon: Icons.repeat_rounded,
                      title: 'السماح بتغيير عدد المرات',
                      subtitle: 'اليوزر يقدر يختار عدد مرات تشغيل السكربت',
                      color: const Color(0xFF6C5CE7),
                      value: allowRunCount,
                      onChanged: (v) =>
                          setModal(() => allowRunCount = v),
                    ),

                    if (allowRunCount) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: defaultRunCtrl,
                              keyboardType: TextInputType.number,
                              style:
                                  _noDeco.copyWith(fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'الافتراضي',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: maxRunCtrl,
                              keyboardType: TextInputType.number,
                              style:
                                  _noDeco.copyWith(fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'الحد الأقصى',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),

                    // الرنج
                    _ruleSwitch(
                      theme: Theme.of(ctx),
                      icon: Icons.folder_rounded,
                      title: 'السماح بتغيير الرنج',
                      subtitle:
                          'اليوزر يقدر يختار ملف أرقام مختلف',
                      color: const Color(0xFF00D68F),
                      value: allowRange,
                      onChanged: (v) =>
                          setModal(() => allowRange = v),
                    ),

                    const SizedBox(height: 10),

                    // الرنج الافتراضي (دايماً ظاهر)
                    TextField(
                      controller: TextEditingController(
                          text: defaultRange),
                      style: _noDeco.copyWith(fontSize: 13),
                      onChanged: (v) => defaultRange = v,
                      decoration: const InputDecoration(
                        labelText: 'اسم الرنج الافتراضي',
                        hintText: 'مثال: r1',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: _noDeco),
              ),
              TextButton(
                onPressed: () async {
                  final rules = ScriptRules(
                    allowRunCount: allowRunCount,
                    defaultRunCount:
                        int.tryParse(defaultRunCtrl.text) ?? 1,
                    maxRunCount:
                        int.tryParse(maxRunCtrl.text) ?? 100,
                    allowRange: allowRange,
                    defaultRange: defaultRange.trim(),
                  );
                  await FirestoreService.updateScriptRules(
                      doc.id, rules);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: Text('حفظ',
                    style: _noDeco.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00D68F))),
              ),
            ],
          );
        });
      },
    );

    defaultRunCtrl.dispose();
    maxRunCtrl.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ القواعد'),
          backgroundColor: Color(0xFF00D68F),
        ),
      );
    }
  }

  Widget _ruleSwitch({
    required ThemeData theme,
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
              size: 18,
              color: value
                  ? color
                  : theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: _noDeco.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: value
                            ? color
                            : theme.colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: _noDeco.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.55))),
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
}