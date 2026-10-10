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
              const Spacer(),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Kageno',
                    style: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 12,
                      letterSpacing: 3,
                      fontWeight: FontWeight.bold,
                    ),
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
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniBtn(
                  theme,
                  icon: Icons.people_alt_rounded,
                  label: 'تحديد المستخدمين',
                  color: const Color(0xFF00D2FF),
                  onTap: () => _showAssignDialog(doc),
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

  // ⭐ نافذة تحديد المستخدمين
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
}