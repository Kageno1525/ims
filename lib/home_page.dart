import 'package:flutter/material.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenNumbers;
  final VoidCallback onOpenTasks;

  const HomePage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onOpenNumbers,
    required this.onOpenTasks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ═══ Header ═══
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IMS',
                            style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2)),
                        const SizedBox(height: 2),
                        Text('لوحة التحكم',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.55))),
                      ],
                    ),
                  ),
                  IconBtn(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    onTap: onToggleTheme,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ═══ الكروت الرئيسية (صف أفقي) ═══
              Row(
                children: [
                  Expanded(
                    child: _MainCard(
                      title: 'الأرقام',
                      subtitle: 'حمّل وشغّل',
                      icon: Icons.phone_android_rounded,
                      colors: const [
                        Color(0xFFFF6B6B),
                        Color(0xFFFF8E53)
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
                        Color(0xFF00D2FF)
                      ],
                      onTap: onOpenTasks,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ═══ قسم المعلومات السريعة ═══
              Text('معلومات سريعة',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.7))),
              const SizedBox(height: 12),
              _quickInfo(
                theme,
                icon: Icons.tips_and_updates_rounded,
                color: const Color(0xFFFFB84D),
                title: 'الكتابة التلقائية',
                subtitle:
                    'فعّل الـ Accessibility من الإعدادات عشان الأرقام تتكتب تلقائياً',
              ),
              const SizedBox(height: 10),
              _quickInfo(
                theme,
                icon: Icons.folder_rounded,
                color: const Color(0xFF00D2FF),
                title: 'ملفات CSV',
                subtitle:
                    'الملفات المحمّلة بتتحفظ في Download/ranges',
              ),
              const Spacer(),

              // ═══ Footer ═══
              Center(
                child: Text('IMS • v1.0',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                        fontSize: 11,
                        letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickInfo(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.55))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════ الكارت الرئيسي - صغير وأنضف ═══════
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
          padding: const EdgeInsets.all(16),
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}