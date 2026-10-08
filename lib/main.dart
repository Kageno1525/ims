import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ImsApp());
}

// ═══════════════════════════════════════════════════════════
//                           APP
// ═══════════════════════════════════════════════════════════

class ImsApp extends StatefulWidget {
  const ImsApp({super.key});
  @override
  State<ImsApp> createState() => _ImsAppState();
}

class _ImsAppState extends State<ImsApp> {
  ThemeMode _mode = ThemeMode.dark;

  void _toggle() => setState(
        () => _mode =
            _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IMS',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: AppShell(
        isDark: _mode == ThemeMode.dark,
        onToggleTheme: _toggle,
      ),
    );
  }
}

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6C5CE7),
    brightness: b,
  );
  final base =
      ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  return base.copyWith(
    scaffoldBackgroundColor:
        b == Brightness.dark ? const Color(0xFF0B0B14) : const Color(0xFFF5F6FB),
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: b == Brightness.dark
          ? Colors.white.withOpacity(0.04)
          : Colors.black.withOpacity(0.02),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
//                        CONSTANTS / JS
// ═══════════════════════════════════════════════════════════

const String _kLoginUrl = 'https://imssms.org/login';

/// يملّي اليوزر والباسورد ويضغط زرار الدخول (متوافق مع Vue)
const String _kFillJs = r'''
(function(){
  try {
    var U = %USER%, P = %PASS%;
    var u = document.querySelector('#app > div > form > div.login-body.classic-body > div:nth-child(3) > input[type=text]')
         || document.querySelector('form input[type=text]')
         || document.querySelector('input[type=text]');
    var p = document.querySelector('#app > div > form > div.login-body.classic-body > div.pill-input.has-reveal > input[type=password]')
         || document.querySelector('form input[type=password]')
         || document.querySelector('input[type=password]');
    var b = document.querySelector('#app > div > form > div.login-body.classic-body > button')
         || document.querySelector('form button[type=submit]')
         || document.querySelector('form button');
    if (!u || !p || !b) return 'not-ready';
    var setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    setter.call(u, U);
    u.dispatchEvent(new Event('input', {bubbles:true}));
    u.dispatchEvent(new Event('change', {bubbles:true}));
    setter.call(p, P);
    p.dispatchEvent(new Event('input', {bubbles:true}));
    p.dispatchEvent(new Event('change', {bubbles:true}));
    setTimeout(function(){ try { b.click(); } catch(e){} }, 60);
    return 'ok';
  } catch(e) { return 'err'; }
})()
''';

/// يقرأ عناصر .cstat-value ويرجّع نص مفصول بـ |
const String _kReadStatsJs = r'''
(function(){
  try {
    var els = document.querySelectorAll('.cstat-value');
    if (els.length >= 2) {
      var a = String(els[0].innerText || els[0].textContent || '').trim();
      var b = String(els[1].innerText || els[1].textContent || '').trim();
      return 'ok|' + a + '|' + b;
    }
    return 'no';
  } catch(e) { return 'err'; }
})()
''';

enum _Stage { login, dashboard }

// ═══════════════════════════════════════════════════════════
//                       APP SHELL
// ═══════════════════════════════════════════════════════════

class AppShell extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  const AppShell({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  InAppWebViewController? _web;
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _Stage _stage = _Stage.login;
  bool _busy = false;
  String? _error;
  int _today = 0;
  int _week = 0;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _unwrap(dynamic raw) {
    if (raw == null) return '';
    var s = raw.toString().trim();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1)
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\');
    }
    return s;
  }

  String _jsonStr(String s) {
    final esc = s
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    return '"$esc"';
  }

  Future<(int, int)?> _readStats() async {
    if (_web == null) return null;
    final raw = await _web!.evaluateJavascript(source: _kReadStatsJs);
    final s = _unwrap(raw);
    if (!s.startsWith('ok|')) return null;
    final parts = s.split('|');
    if (parts.length < 3) return null;
    final t = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final w = int.tryParse(parts[2].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return (t, w);
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // 1) استنى الـ webview يجهز
      final sw = Stopwatch()..start();
      while (_web == null && sw.elapsed < const Duration(seconds: 8)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (_web == null) throw Exception('webview not ready');

      // 2) جرّب تملّي الفورم لحد ما ينجح
      final js = _kFillJs
          .replaceAll('%USER%', _jsonStr(_userCtrl.text.trim()))
          .replaceAll('%PASS%', _jsonStr(_passCtrl.text));
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 400));
        final res = _unwrap(await _web!.evaluateJavascript(source: js));
        if (res == 'ok') break;
      }

      // 3) استنى لحد ما القيم تظهر
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        final stats = await _readStats();
        if (stats != null) {
          setState(() {
            _today = stats.$1;
            _week = stats.$2;
            _busy = false;
            _stage = _Stage.dashboard;
          });
          return;
        }
      }
      throw Exception('timeout');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'مقدرناش نكمل تسجيل الدخول. تأكد من البيانات وجرب تاني.';
      });
    }
  }

  Future<void> _refresh() async {
    if (_web == null || _busy) return;
    setState(() => _busy = true);
    final stats = await _readStats();
    if (stats != null && mounted) {
      setState(() {
        _today = stats.$1;
        _week = stats.$2;
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _logout() async {
    try {
      await _web?.loadUrl(urlRequest: URLRequest(url: WebUri(_kLoginUrl)));
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _stage = _Stage.login;
      _today = 0;
      _week = 0;
      _error = null;
      _passCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          // WebView شغال في الخلفية
          Positioned.fill(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_kLoginUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                cacheEnabled: true,
                thirdPartyCookiesEnabled: true,
                sharedCookiesEnabled: true,
              ),
              onWebViewCreated: (c) => _web = c,
            ),
          ),
          // الواجهة القدامية (معتمة فوق الـ webview)
          Positioned.fill(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: _stage == _Stage.dashboard
                    ? _DashboardView(
                        key: const ValueKey('dash'),
                        isDark: widget.isDark,
                        onToggleTheme: widget.onToggleTheme,
                        today: _today,
                        week: _week,
                        busy: _busy,
                        onRefresh: _refresh,
                        onLogout: _logout,
                      )
                    : _LoginView(
                        key: const ValueKey('login'),
                        isDark: widget.isDark,
                        onToggleTheme: widget.onToggleTheme,
                        userCtrl: _userCtrl,
                        passCtrl: _passCtrl,
                        formKey: _formKey,
                        busy: _busy,
                        error: _error,
                        onSubmit: _submit,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//                       LOGIN VIEW
// ═══════════════════════════════════════════════════════════

class _LoginView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final GlobalKey<FormState> formKey;
  final bool busy;
  final String? error;
  final Future<void> Function() onSubmit;

  const _LoginView({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.userCtrl,
    required this.passCtrl,
    required this.formKey,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnimatedBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: _IconBtn(
                      icon: isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      onTap: onToggleTheme,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLogo(theme),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface
                          .withOpacity(isDark ? 0.55 : 0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'تسجيل الدخول',
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ادخل بياناتك للوصول لإحصائيات الرسائل',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: userCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'من فضلك ادخل اسم المستخدم'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: passCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'من فضلك ادخل كلمة المرور'
                                : null,
                            onFieldSubmitted: (_) => onSubmit(),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            child: error == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.error
                                            .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: theme.colorScheme.error
                                              .withOpacity(0.35),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline_rounded,
                                            color: theme.colorScheme.error,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              error!,
                                              style: TextStyle(
                                                color: theme.colorScheme.error,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 22),
                          _SubmitButton(
                            busy: busy,
                            onTap: busy ? null : () => onSubmit(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'IMS SMS',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(ThemeData theme) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.7, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.elasticOut,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: const Icon(Icons.sms_rounded,
                color: Colors.white, size: 48),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'لوحة تحكم الرسائل',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'تابع إحصائياتك بسهولة',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//                     SUBMIT BUTTON
// ═══════════════════════════════════════════════════════════

class _SubmitButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onTap;
  const _SubmitButton({required this.busy, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: busy
                  ? const SizedBox(
                      key: ValueKey('spin'),
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      key: ValueKey('txt'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'دخول',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//                     DASHBOARD VIEW
// ═══════════════════════════════════════════════════════════

class _DashboardView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final int today;
  final int week;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;

  const _DashboardView({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.today,
    required this.week,
    required this.busy,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnimatedBackground(
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
                        Text(
                          'مرحباً 👋',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'لوحة الرسائل',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  _IconBtn(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    onTap: onToggleTheme,
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: Icons.refresh_rounded,
                    spinning: busy,
                    onTap: busy ? null : () => onRefresh(),
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: Icons.logout_rounded,
                    onTap: () => onLogout(),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  color: theme.colorScheme.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      _StatCard(
                        title: 'رسائل اليوم',
                        value: today,
                        icon: Icons.today_rounded,
                        colors: const [
                          Color(0xFF6C5CE7),
                          Color(0xFF8E7CFF)
                        ],
                        delay: 0,
                      ),
                      const SizedBox(height: 18),
                      _StatCard(
                        title: 'رسائل هذا الأسبوع',
                        value: week,
                        icon: Icons.calendar_view_week_rounded,
                        colors: const [
                          Color(0xFF00D2FF),
                          Color(0xFF3A7BD5)
                        ],
                        delay: 120,
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'اسحب للأسفل للتحديث',
                          style: TextStyle(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
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
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final List<Color> colors;
  final int delay;

  const _StatCard({
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
      builder: (context, t, child) {
        return Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: Opacity(opacity: t, child: child),
        );
      },
      child: Container(
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
              width: 60,
              height: 60,
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
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AnimatedCounter(
                    value: value,
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
    );
  }
}

class _AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const _AnimatedCounter({required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutExpo,
      builder: (_, v, __) => Text('${v.toInt()}', style: style),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//                       ICON BUTTON
// ═══════════════════════════════════════════════════════════

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool spinning;
  const _IconBtn({required this.icon, this.onTap, this.spinning = false});

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
                  width: 20,
                  height: 20,
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

// ═══════════════════════════════════════════════════════════
//                   ANIMATED BACKGROUND
// ═══════════════════════════════════════════════════════════

class _AnimatedBackground extends StatefulWidget {
  final Widget child;
  const _AnimatedBackground({required this.child});

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
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

  Widget _orb(Color color, double size, double dx, double dy) {
    return Positioned(
      left: dx,
      top: dy,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withOpacity(0)],
            ),
          ),
        ),
      ),
    );
  }
}