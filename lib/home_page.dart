import 'package:flutter/material.dart';
import 'firebase/auth_service.dart';
import 'firebase/firestore_service.dart';
import 'models.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final UserProfile profile;
  final VoidCallback onOpenNumbers;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenControl;
  final VoidCallback onOpenScripts;

  const HomePage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.profile,
    required this.onOpenNumbers,
    required this.onOpenTasks,
    required this.onOpenControl,
    required this.onOpenScripts,
  });

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(
              fontWeight: FontWeight.bold, decoration: TextDecoration.none),
        ),
        content: const Text(
          'متأكد إنك عايز تسجّل خروج؟',
          style: TextStyle(fontSize: 14, decoration: TextDecoration.none),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء',
                style: TextStyle(decoration: TextDecoration.none)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('خروج',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final uid = AuthService.uid;
      if (uid != null) {
        await FirestoreService.clearSession(uid);
      }
      await AuthService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = profile.isAdmin;

    return AnimatedBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAdmin ? 'IMS Admin' : 'IMS',
                          style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'أهلاً ${profile.name.isNotEmpty ? profile.name : profile.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.55)),
                        ),
                      ],
                    ),
                  ),
                  IconBtn(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    onTap: onToggleTheme,
                  ),
                  const SizedBox(width: 8),
                  IconBtn(
                    icon: Icons.logout_rounded,
                    onTap: () => _logout(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // كارت معلومات المستخدم
              _profileCard(theme, isAdmin),
              const SizedBox(height: 20),

              // الكروت الرئيسية
              if (isAdmin) ...[
                Row(
                  children: [
                    Expanded(
                      child: _MainCard(
                        title: 'الأرقام',
                        subtitle: 'حمّل وشغّل',
                        icon: Icons.phone_android_rounded,
                        colors: const [
                          Color(0xFFFF6B6B),
                          Color(0xFFFF8E53),
                        ],
                        onTap: onOpenNumbers,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _MainCard(
                        title: 'المهام',
                        subtitle: 'أتمتة التطبيقات',
                        icon: Icons.auto_awesome_rounded,
                        colors: const [
                          Color(0xFF6C5CE7),
                          Color(0xFF00D2FF),
                        ],
                        onTap: onOpenTasks,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MainCard(
                        title: 'السكربتات',
                        subtitle: 'إدارة السكربتات',
                        icon: Icons.folder_special_rounded,
                        colors: const [
                          Color(0xFF00D2FF),
                          Color(0xFF3A7BD5),
                        ],
                        onTap: onOpenScripts,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _MainCard(
                        title: 'التحكم',
                        subtitle: 'إدارة المستخدمين',
                        icon: Icons.admin_panel_settings_rounded,
                        colors: const [
                          Color(0xFF00B894),
                          Color(0xFF00D68F),
                        ],
                        onTap: onOpenControl,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // المستخدم: الأرقام (اختياري) + السكربتات
                if (profile.showNumbers) ...[
                  _wideCard(
                    title: 'الأرقام',
                    subtitle: 'حمّل وشغّل',
                    icon: Icons.phone_android_rounded,
                    colors: const [
                      Color(0xFFFF6B6B),
                      Color(0xFFFF8E53),
                    ],
                    onTap: onOpenNumbers,
                  ),
                  const SizedBox(height: 14),
                ],
                _wideCard(
                  title: 'السكربتات',
                  subtitle: 'شغّل السكربتات المساحة لك',
                  icon: Icons.auto_awesome_rounded,
                  colors: const [
                    Color(0xFF6C5CE7),
                    Color(0xFF00D2FF),
                  ],
                  onTap: onOpenScripts,
                ),
              ],

              const Spacer(),

              // Footer
              Center(
                child: Text(
                  'Kageno',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 13,
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

  Widget _profileCard(ThemeData theme, bool isAdmin) {
    final color = isAdmin
        ? const Color(0xFF6C5CE7)
        : const Color(0xFF00D2FF);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAdmin
                    ? const [Color(0xFF6C5CE7), Color(0xFF8E7CFF)]
                    : const [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAdmin
                  ? Icons.admin_panel_settings_rounded
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
                // ⭐ الأدمن يشوف الدور، اليوزر يشوف اسمه
                Text(
                  isAdmin ? 'أدمن' : profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                // ⭐ الأدمن يشوف الإيميل، اليوزر يشوف الـ username
                Text(
                  isAdmin ? profile.email : '@${profile.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wideCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        )),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _MainCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  )),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}