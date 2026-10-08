import 'package:flutter/material.dart';
import 'widgets.dart';

class DashboardPage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final int today;
  final int week;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;
  final VoidCallback onOpenNumbers;

  const DashboardPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.today,
    required this.week,
    required this.busy,
    required this.onRefresh,
    required this.onLogout,
    required this.onOpenNumbers,
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
                        Text('لوحة الرسائل',
                            style: theme.textTheme.titleLarge
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
                  const SizedBox(width: 8),
                  IconBtn(
                    icon: Icons.refresh_rounded,
                    spinning: busy,
                    onTap: busy ? null : () => onRefresh(),
                  ),
                  const SizedBox(width: 8),
                  IconBtn(
                      icon: Icons.logout_rounded,
                      onTap: () => onLogout()),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  color: theme.colorScheme.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    children: [
                      StatCard(
                        title: 'رسائل اليوم',
                        value: today,
                        icon: Icons.today_rounded,
                        colors: const [
                          Color(0xFF6C5CE7),
                          Color(0xFF8E7CFF)
                        ],
                      ),
                      const SizedBox(height: 18),
                      StatCard(
                        title: 'رسائل هذا الأسبوع',
                        value: week,
                        icon: Icons.calendar_view_week_rounded,
                        colors: const [
                          Color(0xFF00D2FF),
                          Color(0xFF3A7BD5)
                        ],
                      ),
                      const SizedBox(height: 18),
                      _numbersCard(),
                      const SizedBox(height: 24),
                      Center(
                        child: Text('اسحب للأسفل للتحديث',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.4),
                              fontSize: 12,
                            )),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numbersCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onOpenNumbers,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.4),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Icon(Icons.phone_android_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('الأرقام',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        )),
                    SizedBox(height: 4),
                    Text('استعرض وحمّل الأرقام من الرنجات',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}