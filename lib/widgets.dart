import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'models.dart';

// ═══════════════════ خلفية ثابتة وسريعة ═══════════════════
class AnimatedBackground extends StatelessWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _BlobsPainter(
                    c1: theme.colorScheme.primary.withOpacity(0.35),
                    c2: theme.colorScheme.secondary.withOpacity(0.25),
                    c3: theme.colorScheme.tertiary.withOpacity(0.18),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BlobsPainter extends CustomPainter {
  final Color c1, c2, c3;
  _BlobsPainter({required this.c1, required this.c2, required this.c3});

  @override
  void paint(Canvas canvas, Size size) {
    _blob(canvas, Offset(size.width * 0.1, size.height * 0.1), 320, c1);
    _blob(canvas, Offset(size.width * 0.95, size.height * 0.45), 360, c2);
    _blob(canvas, Offset(size.width * 0.4, size.height * 0.95), 260, c3);
  }

  void _blob(Canvas canvas, Offset center, double radius, Color color) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_BlobsPainter old) =>
      old.c1 != c1 || old.c2 != c2 || old.c3 != c3;
}

// ═══════════════════ IconBtn ═══════════════════
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
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : Icon(icon, size: 20, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

// ═══════════════════ ActionBtn ═══════════════════
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
    return Container(
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
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                  Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════ StatCard ═══════════════════
class StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final List<Color> colors;
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
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
                Text(title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 8),
                Text('$value',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════ LogPanel (يستخدم ValueListenable) ═══════════════════
class LogPanel extends StatelessWidget {
  final ValueListenable<List<LogEntry>> logs;
  final bool isDark;
  final bool shrink;
  const LogPanel({
    super.key,
    required this.logs,
    required this.isDark,
    this.shrink = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<LogEntry>>(
      valueListenable: logs,
      builder: (context, entries, _) {
        return _buildPanel(context, entries);
      },
    );
  }

  Widget _buildPanel(BuildContext context, List<LogEntry> entries) {
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
        mainAxisSize: shrink ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Row(
            children: [
              Icon(Icons.terminal_rounded, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('السجل',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                  )),
              const Spacer(),
              if (entries.isNotEmpty)
                Text('${entries.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    )),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('لا يوجد سجل بعد',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                      fontSize: 12,
                    )),
              ),
            )
          else
            shrink
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children:
                        entries.take(6).map((l) => _tile(theme, l)).toList(),
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (_, i) => _tile(theme, entries[i]),
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
        color = const Color(0xFF00D68F);
        icon = Icons.check_circle_rounded;
        break;
      case LogLevel.error:
        color = const Color(0xFFFF6B6B);
        icon = Icons.error_rounded;
        break;
      case LogLevel.wait:
        color = const Color(0xFFFFB84D);
        icon = Icons.hourglass_top_rounded;
        break;
      default:
        color = theme.colorScheme.primary;
        icon = Icons.info_rounded;
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
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontFamily: 'monospace',
              )),
          const SizedBox(width: 8),
          Expanded(
            child: Text(l.msg,
                style: TextStyle(
                  fontSize: 11.5,
                  color: color,
                  fontFamily: 'monospace',
                )),
          ),
        ],
      ),
    );
  }
}