import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';

// ═══════════════════ خلفية سريعة جداً ═══════════════════
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
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          // الخلفية: RepaintBoundary يمنع إعادة الرسم
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: RotationTransition(
                  // دوران بطيء جداً (30 ثانية للفة كاملة)
                  turns: _c,
                  alignment: Alignment.center,
                  child: CustomPaint(
                    painter: _BlobsPainter(
                      c1: theme.colorScheme.primary.withOpacity(0.28),
                      c2: theme.colorScheme.secondary.withOpacity(0.22),
                      c3: theme.colorScheme.tertiary.withOpacity(0.16),
                    ),
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

// ═══════════════════ رسم البقع الثلاثة مرة واحدة فقط ═══════════════════
class _BlobsPainter extends CustomPainter {
  final Color c1, c2, c3;
  _BlobsPainter({required this.c1, required this.c2, required this.c3});

  @override
  void paint(Canvas canvas, Size size) {
    // نرسم في مربع أكبر عشان الدوران ميبانش فيه فراغ
    final w = size.width * 1.8;
    final h = size.height * 1.8;
    final ox = -size.width * 0.4;
    final oy = -size.height * 0.4;

    _blob(canvas, Offset(ox + w * 0.25, oy + h * 0.2), 320, c1);
    _blob(canvas, Offset(ox + w * 0.75, oy + h * 0.55), 360, c2);
    _blob(canvas, Offset(ox + w * 0.5, oy + h * 0.85), 260, c3);
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

// ═══════════════════ StatCard (بدون TweenAnimationBuilder دائم) ═══════════════════
class StatCard extends StatefulWidget {
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
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _animated = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) setState(() => _animated = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      offset: _animated ? Offset.zero : const Offset(0, 0.15),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: _animated ? 1 : 0,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: widget.colors.first.withOpacity(0.4),
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
                child: Icon(widget.icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 8),
                    // عدّاد بسيط بدون TweenAnimationBuilder متكرر
                    _AnimatedValue(
                      value: widget.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        height: 1,
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

class _AnimatedValue extends StatefulWidget {
  final int value;
  final TextStyle? style;
  const _AnimatedValue({required this.value, this.style});
  @override
  State<_AnimatedValue> createState() => _AnimatedValueState();
}

class _AnimatedValueState extends State<_AnimatedValue> {
  int _display = 0;

  @override
  void initState() {
    super.initState();
    _display = widget.value;
  }

  @override
  void didUpdateWidget(_AnimatedValue old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _display = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Text('$_display', style: widget.style);
  }
}

// ═══════════════════ LogPanel ═══════════════════
class LogPanel extends StatelessWidget {
  final List<LogEntry> logs;
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
              if (logs.isNotEmpty)
                Text('${logs.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    )),
            ],
          ),
          const SizedBox(height: 8),
          if (logs.isEmpty)
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
                    children: logs.take(6).map((l) => _tile(theme, l)).toList(),
                  )
                : Expanded(
                    child: ListView.builder(
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