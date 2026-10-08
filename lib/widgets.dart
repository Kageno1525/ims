import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});
  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 2 * math.pi;
          return ClipRect(
            child: Stack(
              children: [
                _orb(theme.colorScheme.primary.withOpacity(0.35), 340,
                    -100 + 40 * math.sin(t), -80 + 60 * math.cos(t)),
                _orb(theme.colorScheme.secondary.withOpacity(0.30), 380,
                    200 + 50 * math.sin(t + 1.5), 400 + 60 * math.cos(t + 0.5)),
                _orb(theme.colorScheme.tertiary.withOpacity(0.20), 260,
                    100 + 40 * math.cos(t * 0.8), 200 + 50 * math.sin(t * 0.8)),
                widget.child,
              ],
            ),
          );
        },
      ),
    );
  }
  Widget _orb(Color color, double size, double dx, double dy) => Positioned(
        left: dx, top: dy,
        child: IgnorePointer(
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
            ),
          ),
        ),
      );
}

class IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool spinning;
  const IconBtn({super.key, required this.icon, this.onTap, this.spinning = false});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withOpacity(0.6),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: spinning
              ? SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary))
              : Icon(icon, size: 20, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

class ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final bool busy;
  final VoidCallback? onTap;
  const ActionBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.busy,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: onTap == null
              ? [gradient.first.withOpacity(0.4), gradient.last.withOpacity(0.4)]
              : gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(onTap == null ? 0.1 : 0.4),
            blurRadius: 20, offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                else
                  Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final List<Color> colors;
  final int delay;
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.colors,
    this.delay = 0,
  });
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 700 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, 24 * (1 - t)),
        child: Opacity(opacity: t, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: colors.first.withOpacity(0.4), blurRadius: 28, offset: const Offset(0, 14))],
        ),
        child: Row(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value.toDouble()),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutExpo,
                    builder: (_, v, __) => Text('${v.toInt()}',
                        style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold, height: 1)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LogPanel extends StatelessWidget {
  final List<LogEntry> logs;
  final bool isDark;
  const LogPanel({super.key, required this.logs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(isDark ? 0.35 : 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.terminal_rounded, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('السجل',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold)),
              const Spacer(),
              if (logs.isNotEmpty)
                Text('${logs.length}',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.4))),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: logs.isEmpty
                ? Center(child: Text('لا يوجد سجل بعد',
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.3), fontSize: 12)))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (_, i) => _tile(theme, logs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tile(ThemeData theme, LogEntry l) {
    Color color;
    IconData icon;
    switch (l.level) {
      case LogLevel.ok:
        color = const Color(0xFF00D68F); icon = Icons.check_circle_rounded; break;
      case LogLevel.error:
        color = const Color(0xFFFF6B6B); icon = Icons.error_rounded; break;
      case LogLevel.wait:
        color = const Color(0xFFFFB84D); icon = Icons.hourglass_top_rounded; break;
      default:
        color = theme.colorScheme.primary; icon = Icons.info_rounded;
    }
    final hh = l.time.hour.toString().padLeft(2, '0');
    final mm = l.time.minute.toString().padLeft(2, '0');
    final ss = l.time.second.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text('$hh:$mm:$ss',
              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.4), fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Expanded(
            child: Text(l.msg,
                style: TextStyle(fontSize: 11.5, color: color, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}