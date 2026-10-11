import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../firebase/auth_service.dart';
import '../firebase/security_service.dart';
import '../widgets.dart';

class NotificationsPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onBack;

  const NotificationsPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onBack,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  static const _noDeco = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    // ⭐ عند فتح الصفحة — علّم كل الإشعارات كمقروءة
    Future.microtask(() => SecurityService.markAllSeen());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

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
                    child: Text(
                      'الإشعارات الأمنية',
                      style: _noDeco.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      theme.colorScheme.onSurface.withOpacity(0.6),
                  labelStyle: _noDeco.copyWith(
                      fontSize: 12.5, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(height: 42, text: 'محاولات الدخول'),
                    Tab(height: 42, text: 'الأجهزة المحظورة'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Content
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _eventsTab(theme),
                    _bannedTab(theme),
                  ],
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

  // ═══════ Tab 1: الأحداث الأمنية ═══════
  Widget _eventsTab(ThemeData theme) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SecurityService.securityEventsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final events = snap.data ?? [];
        if (events.isEmpty) {
          return _emptyView(
            theme,
            icon: Icons.security_rounded,
            title: 'مفيش أحداث أمنية',
            subtitle: 'كل حاجة تمام لحد دلوقتي',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _eventCard(theme, events[i]),
        );
      },
    );
  }

  Widget _eventCard(ThemeData theme, Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    final hwid = event['hwid']?.toString() ?? 'unknown';
    final ip = event['ip']?.toString() ?? 'unknown';
    final deviceModel = event['deviceModel']?.toString() ?? 'unknown';
    final deviceName = event['deviceName']?.toString() ?? 'unknown';
    final attemptedUsername =
        event['attemptedUsername']?.toString() ?? '';
    final targetName = event['targetAccountName']?.toString() ?? '';
    final seen = event['seen'] == true;

    DateTime? ts;
    try {
      final t = event['timestamp'];
      if (t != null) {
        ts = (t as dynamic).toDate();
      }
    } catch (_) {}

    String typeLabel = 'محاولة مشبوهة';
    Color typeColor = const Color(0xFFFF6B6B);
    IconData typeIcon = Icons.warning_amber_rounded;

    if (type == 'admin_login_attempt') {
      typeLabel = 'محاولة فتح حساب أدمن';
      typeColor = const Color(0xFFFF6B6B);
      typeIcon = Icons.gpp_maybe_rounded;
    } else if (type == 'admin_role_after_login') {
      typeLabel = 'تغيير دور لحساب أدمن';
      typeColor = const Color(0xFFFFB84D);
      typeIcon = Icons.security_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface
            .withOpacity(widget.isDark ? 0.55 : 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: typeColor.withOpacity(seen ? 0.2 : 0.5),
          width: seen ? 1 : 1.8,
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
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 22),
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
                            typeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _noDeco.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                        ),
                        if (!seen)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D2FF)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'جديد',
                              style: _noDeco.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00D2FF),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (ts != null)
                      Text(
                        _formatTime(ts),
                        style: _noDeco.copyWith(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(theme, Icons.person_rounded, 'الحساب المستهدف',
              targetName.isEmpty ? attemptedUsername : targetName),
          if (attemptedUsername.isNotEmpty)
            _infoRow(theme, Icons.account_circle_rounded, 'اسم المستخدم',
                attemptedUsername),
          _infoRow(theme, Icons.fingerprint_rounded, 'HWID', hwid,
              mono: true),
          _infoRow(theme, Icons.public_rounded, 'IP', ip, mono: true),
          _infoRow(theme, Icons.phone_android_rounded, 'الجهاز',
              deviceModel),
          _infoRow(theme, Icons.devices_rounded, 'المعرف',
              deviceName, mono: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  theme,
                  icon: Icons.content_copy_rounded,
                  label: 'نسخ HWID',
                  color: const Color(0xFF00D2FF),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: hwid));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('📋 تم نسخ الـ HWID')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  theme,
                  icon: Icons.block_rounded,
                  label: 'حظر الجهاز',
                  color: const Color(0xFFFF6B6B),
                  onTap: () => _confirmBan(
                    hwid: hwid,
                    deviceModel: deviceModel,
                    username: attemptedUsername,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value,
      {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 8),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: _noDeco.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: _noDeco.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                fontFamily: mono ? 'monospace' : null,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════ Tab 2: الأجهزة المحظورة ═══════
  Widget _bannedTab(ThemeData theme) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SecurityService.bannedDevicesStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final devices = snap.data ?? [];
        if (devices.isEmpty) {
          return _emptyView(
            theme,
            icon: Icons.verified_user_rounded,
            title: 'مفيش أجهزة محظورة',
            subtitle: 'كل الأجهزة مسموح لها',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: devices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _bannedCard(theme, devices[i]),
        );
      },
    );
  }

  Widget _bannedCard(ThemeData theme, Map<String, dynamic> device) {
    final hwid = device['hwid']?.toString() ?? '';
    final deviceModel = device['deviceModel']?.toString() ?? 'unknown';
    final lastUsername = device['lastUsername']?.toString() ?? '';
    final reason = device['reason']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface
            .withOpacity(widget.isDark ? 0.55 : 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withOpacity(0.4),
          width: 1.5,
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
                  color: const Color(0xFFFF6B6B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.gpp_bad_rounded,
                    color: Color(0xFFFF6B6B), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceModel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _noDeco.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (lastUsername.isNotEmpty)
                      Text(
                        lastUsername,
                        style: _noDeco.copyWith(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(theme, Icons.fingerprint_rounded, 'HWID', hwid,
              mono: true),
          if (reason.isNotEmpty)
            _infoRow(theme, Icons.info_outline_rounded, 'السبب', reason),
          const SizedBox(height: 12),
          _actionBtn(
            theme,
            icon: Icons.lock_open_rounded,
            label: 'رفع الحظر',
            color: const Color(0xFF00D68F),
            onTap: () => _confirmUnban(hwid),
          ),
        ],
      ),
    );
  }

  Widget _emptyView(ThemeData theme,
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 70, color: theme.colorScheme.primary.withOpacity(0.3)),
          const SizedBox(height: 14),
          Text(
            title,
            style: _noDeco.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: _noDeco.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
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
              const SizedBox(width: 6),
              Text(
                label,
                style: _noDeco.copyWith(
                  fontSize: 11.5,
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

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'من ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'من ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'من ${diff.inDays} يوم';
    final d = t.day.toString().padLeft(2, '0');
    final m = t.month.toString().padLeft(2, '0');
    final y = t.year;
    final h = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    return '$d/$m/$y • $h:$mi';
  }

  Future<void> _confirmBan({
    required String hwid,
    required String deviceModel,
    required String username,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.gpp_bad_rounded,
                color: Color(0xFFFF6B6B), size: 24),
            const SizedBox(width: 8),
            Text('حظر الجهاز',
                style: _noDeco.copyWith(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'هيتم حظر الجهاز ده خالص — صاحبه مش هيقدر يفتح التطبيق من الجهاز ده تاني.',
          style: _noDeco.copyWith(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: _noDeco),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('حظر',
                style: _noDeco.copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SecurityService.banHwid(
        hwid: hwid,
        bannedBy: AuthService.uid ?? '',
        deviceModel: deviceModel,
        lastUsername: username,
        reason: 'محاولة فتح حساب أدمن',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚫 تم حظر الجهاز'),
            backgroundColor: Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  Future<void> _confirmUnban(String hwid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('رفع الحظر',
            style: _noDeco.copyWith(fontWeight: FontWeight.bold)),
        content: Text('هيسمح للجهاز ده يستخدم التطبيق تاني.',
            style: _noDeco.copyWith(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: _noDeco),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('رفع',
                style: _noDeco.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00D68F))),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SecurityService.unbanHwid(hwid);
    }
  }
}