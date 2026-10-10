import 'package:flutter/material.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore_service.dart';
import '../models.dart';
import '../widgets.dart';

class ControlPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onBack;
  final UserProfile adminProfile;

  const ControlPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onBack,
    required this.adminProfile,
  });

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
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
              // Header
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
                          'التحكم',
                          style: _noDeco.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        StreamBuilder<List<UserProfile>>(
                          stream: FirestoreService.allUsersStream(),
                          builder: (_, snap) {
                            final count = snap.data?.length ?? 0;
                            return Text(
                              '$count مستخدم',
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
                    icon: Icons.person_add_rounded,
                    onTap: () => _showAddUserDialog(context),
                  ),
                  const SizedBox(width: 6),
                  IconBtn(
                    icon: widget.isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    onTap: widget.onToggleTheme,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Stream للأدمن: يُحدّث تلقائياً
              Expanded(
                child: StreamBuilder<List<UserProfile>>(
                  stream: FirestoreService.allUsersStream(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return _errorView(theme, '${snap.error}');
                    }
                    final users = snap.data ?? [];
                    if (users.isEmpty) {
                      return _emptyView(theme);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: users.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _userCard(theme, users[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userCard(ThemeData theme, UserProfile user) {
    final isAdmin = user.isAdmin;
    final isBanned = user.isBanned;

    Color borderColor;
    if (isBanned) {
      borderColor = const Color(0xFFFF6B6B);
    } else if (isAdmin) {
      borderColor = const Color(0xFF6C5CE7);
    } else {
      borderColor = theme.colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(
            widget.isDark ? 0.55 : 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الصف الأول: الأيقونة + الاسم + الإيميل
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isAdmin
                        ? const [Color(0xFF6C5CE7), Color(0xFF8E7CFF)]
                        : isBanned
                            ? const [Color(0xFFFF6B6B), Color(0xFFFF8E53)]
                            : const [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAdmin
                      ? Icons.admin_panel_settings_rounded
                      : isBanned
                          ? Icons.block_rounded
                          : Icons.person_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name.isEmpty ? '(بدون اسم)' : user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _noDeco.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isAdmin)
                          _badge(theme, 'أدمن', const Color(0xFF6C5CE7)),
                        if (isBanned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _badge(
                                theme, 'محظور', const Color(0xFFFF6B6B)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _noDeco.copyWith(
                        fontSize: 11.5,
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // الشارات الإضافية
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _infoChip(
                theme,
                Icons.numbers_rounded,
                user.showNumbers ? 'الأرقام مفعّلة' : 'الأرقام مقفولة',
                user.showNumbers
                    ? const Color(0xFF00D68F)
                    : const Color(0xFF95A5A6),
              ),
              _infoChip(
                theme,
                Icons.auto_awesome_rounded,
                '${user.allowedScripts.length} سكربت',
                const Color(0xFF00D2FF),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // أزرار التحكم
          Row(
            children: [
              Expanded(
                child: _smallBtn(
                  theme,
                  icon: Icons.edit_rounded,
                  label: 'تعديل',
                  color: const Color(0xFF00D2FF),
                  onTap: () => _showEditDialog(context, user),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _smallBtn(
                  theme,
                  icon: user.isBanned
                      ? Icons.lock_open_rounded
                      : Icons.block_rounded,
                  label: user.isBanned ? 'رفع الحظر' : 'حظر',
                  color: user.isBanned
                      ? const Color(0xFF00D68F)
                      : const Color(0xFFFFB84D),
                  onTap: () => _toggleBan(user),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _smallBtn(
                  theme,
                  icon: Icons.delete_outline_rounded,
                  label: 'حذف',
                  color: const Color(0xFFFF6B6B),
                  onTap: () => _confirmDelete(context, user),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(ThemeData theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: _noDeco.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
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

  Widget _smallBtn(
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
            Icons.people_outline_rounded,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'مفيش مستخدمين',
            style: _noDeco.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 60, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: _noDeco.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════ DIALOGS ═══════

  Future<void> _toggleBan(UserProfile user) async {
    await FirestoreService.setUserBanned(user.uid, !user.isBanned);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(user.isBanned
            ? 'تم رفع الحظر عن ${user.name}'
            : 'تم حظر ${user.name}'),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, UserProfile user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
          'حذف المستخدم',
          style: _noDeco.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'متأكد إنك عايز تحذف "${user.name}"؟\n'
          'ده هيمسح البروفايل من Firestore (الحساب نفسه في Firebase Auth مش هيتأثر).',
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
      await FirestoreService.deleteUser(user.uid);
    }
  }

  Future<void> _showEditDialog(
      BuildContext context, UserProfile user) async {
    final nameCtrl = TextEditingController(text: user.name);
    bool showNumbers = user.showNumbers;

    // اجيب كل السكربتات لتحديد المسموح
    final allScriptsSnap =
        await FirestoreService.allScriptsStream().first;
    final allowed = Set<String>.from(user.allowedScripts);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text('تعديل ${user.email}',
                style: _noDeco.copyWith(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: _noDeco.copyWith(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'الاسم',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('إظهار صفحة الأرقام',
                          style: _noDeco.copyWith(fontSize: 14)),
                      value: showNumbers,
                      onChanged: (v) => setModal(() => showNumbers = v),
                    ),
                    const Divider(),
                    Text(
                      'السكربتات المسموح بها',
                      style: _noDeco.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    if (allScriptsSnap.isEmpty)
                      Text(
                        'مفيش سكربتات مرفوعة',
                        style: _noDeco.copyWith(
                            fontSize: 12,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5)),
                      )
                    else
                      ...allScriptsSnap.map((s) {
                        final isOn = allowed.contains(s.id);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(s.name,
                              style: _noDeco.copyWith(fontSize: 13)),
                          value: isOn,
                          onChanged: (v) {
                            setModal(() {
                              if (v == true) {
                                allowed.add(s.id);
                              } else {
                                allowed.remove(s.id);
                              }
                            });
                          },
                        );
                      }),
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
                  await FirestoreService.updateUser(user.uid, {
                    'name': nameCtrl.text.trim(),
                    'showNumbers': showNumbers,
                    'allowedScripts': allowed.toList(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
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

    nameCtrl.dispose();
  }

  Future<void> _showAddUserDialog(BuildContext context) async {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool showNumbers = true;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('إضافة مستخدم',
            style: _noDeco.copyWith(
                fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB84D).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFFB84D).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Color(0xFFFFB84D), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'لازم تنشئ الحساب يدوياً في Firebase Console → Authentication → Users',
                        style: _noDeco.copyWith(
                          fontSize: 10.5,
                          color: const Color(0xFFFFB84D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                style: _noDeco.copyWith(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'الإيميل',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                style: _noDeco.copyWith(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                style: _noDeco.copyWith(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Firebase UID',
                  helperText: 'من Firebase Console → Users',
                  helperStyle: TextStyle(fontSize: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('إظهار صفحة الأرقام',
                    style: _noDeco.copyWith(fontSize: 13)),
                value: showNumbers,
                onChanged: (v) => setState(() => showNumbers = v),
              ),
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
              final uid = passCtrl.text.trim();
              final email = emailCtrl.text.trim();
              final name = nameCtrl.text.trim();
              if (uid.isEmpty || email.isEmpty) return;
              await FirestoreService.upsertUserProfile(
                uid: uid,
                email: email,
                name: name.isEmpty ? email.split('@').first : name,
                showNumbers: showNumbers,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('إضافة',
                style: _noDeco.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00D68F))),
          ),
        ],
      ),
    );

    emailCtrl.dispose();
    nameCtrl.dispose();
    passCtrl.dispose();
  }
}