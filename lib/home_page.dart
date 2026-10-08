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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مرحباً 👋',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6))),
                        const SizedBox(height: 2),
                        Text('IMS',
                            style: theme.textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 30),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _BigCard(
                        title: 'الأرقام',
                        subtitle: 'حمّل وشغّل الأرقام',
                        icon: Icons.phone_android_rounded,
                        colors: const [
                          Color(0xFFFF6B6B),
                          Color(0xFFFF8E53)
                        ],
                        onTap: onOpenNumbers,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _BigCard(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _BigCard({
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
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.4),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const Spacer(),
              Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  )),
              const SizedBox(height: 10),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}