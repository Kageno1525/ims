import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String _kLoginUrl = 'https://imssms.org/login';

/// ملء الفورم + الضغط على الدخول بشكل متوافق مع Vue 3
const String _kFillJs = r'''
(function(){
  try {
    var U = %USER%, P = %PASS%;
    var root = document.querySelector('#app') || document;

    var u = root.querySelector('input[type=text]')
         || root.querySelector('input[type=email]')
         || root.querySelector('input[name=username]')
         || root.querySelector('input[name=email]');
    var p = root.querySelector('input[type=password]')
         || root.querySelector('input[name=password]');
    var b = root.querySelector('button[type=submit]')
         || root.querySelector('form button')
         || root.querySelector('button');

    if (!u || !p || !b) {
      return 'not-ready|' + (u?'u':'-') + (p?'p':'-') + (b?'b':'-');
    }

    var proto = Object.getPrototypeOf(u);
    var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
    if (!setter) {
      setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    }

    function fire(el, val){
      el.focus();
      el.dispatchEvent(new Event('focus', {bubbles:true}));
      try { setter.call(el, val); } catch(e){ el.value = val; }
      ['input','change','keyup','keydown','blur'].forEach(function(ev){
        el.dispatchEvent(new Event(ev, {bubbles:true}));
      });
      el.dispatchEvent(new Event('focusout', {bubbles:true}));
    }

    fire(u, U);
    fire(p, P);

    setTimeout(function(){
      try { b.focus(); } catch(e){}
      var rect = b.getBoundingClientRect();
      var cx = rect.left + rect.width/2;
      var cy = rect.top + rect.height/2;
      var opts = {bubbles:true, cancelable:true, view:window, clientX:cx, clientY:cy};
      try { b.dispatchEvent(new PointerEvent('pointerdown', opts)); } catch(e){}
      try { b.dispatchEvent(new MouseEvent('mousedown', opts)); } catch(e){}
      try { b.dispatchEvent(new PointerEvent('pointerup', opts)); } catch(e){}
      try { b.dispatchEvent(new MouseEvent('mouseup', opts)); } catch(e){}
      try { b.dispatchEvent(new MouseEvent('click', opts)); } catch(e){}
      try { b.click(); } catch(e){}
    }, 120);

    return 'ok';
  } catch(e) {
    return 'err:' + (e && e.message ? e.message : 'unknown');
  }
})()
''';

/// تشخيص: يرجع معلومات عن الصفحة الحالية
const String _kDiagJs = r'''
(function(){
  try {
    var url = location.href;
    var inputs = document.querySelectorAll('input').length;
    var buttons = document.querySelectorAll('button').length;
    var stats = document.querySelectorAll('.cstat-value').length;
    var bodyLen = (document.body && document.body.innerText) ? document.body.innerText.length : 0;
    var hasLoginForm = !!document.querySelector('input[type=password]');
    return [url, inputs, buttons, stats, bodyLen, hasLoginForm?1:0].join('|');
  } catch(e){ return 'err:' + e.message; }
})()
''';

/// قراءة الإحصائيات — يدعم أكثر من صيغة
const String _kReadStatsJs = r'''
(function(){
  try {
    var els = document.querySelectorAll('.cstat-value');
    if (els.length >= 2) {
      var t = (els[0].innerText || els[0].textContent || '').trim();
      var w = (els[1].innerText || els[1].textContent || '').trim();
      return 'ok|' + t + '|' + w;
    }
    var h4 = document.querySelectorAll('h4');
    if (h4.length >= 2) {
      var nums = [];
      h4.forEach(function(x){
        var v = (x.innerText || '').trim();
        if (/^\d+$/.test(v)) nums.push(v);
      });
      if (nums.length >= 2) return 'ok|' + nums[0] + '|' + nums[1];
    }
    return 'no';
  } catch(e){ return 'err:' + e.message; }
})()
''';

enum _Stage { login, dashboard }

class AppShell extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  const AppShell({super.key, required this.isDark, required this.onToggleTheme});
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
  bool _showWeb = false;
  bool _pageLoaded = false;
  bool _webReady = false;
  String _diag = '—';
  String _lastJs = '—';
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

  Future<String> _eval(String js) async {
    if (_web == null) return 'no-web';
    try {
      final raw = await _web!.evaluateJavascript(source: js);
      return _unwrap(raw);
    } catch (e) {
      return 'err:$e';
    }
  }

  Future<(int, int)?> _readStats() async {
    final s = await _eval(_kReadStatsJs);
    _lastJs = 'READ: $s';
    if (!s.startsWith('ok|')) return null;
    final parts = s.split('|');
    if (parts.length < 3) return null;
    final t = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final w = int.tryParse(parts[2].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return (t, w);
  }

  Future<void> _updateDiag() async {
    final d = await _eval(_kDiagJs);
    if (mounted) setState(() => _diag = d);
  }

  String _jsonStr(String s) {
    final esc = s
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    return '"$esc"';
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _lastJs = 'بدء…';
    });

    try {
      final sw = Stopwatch()..start();
      while (_web == null && sw.elapsed < const Duration(seconds: 10)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (_web == null) {
        setState(() {
          _busy = false;
          _error = 'الـ WebView مش جاهز';
          _lastJs = 'webview==null';
        });
        return;
      }

      while (!_pageLoaded && sw.elapsed < const Duration(seconds: 22)) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      setState(() => _lastJs = 'الصفحة اتحمّلت: $_pageLoaded');
      await _updateDiag();

      final js = _kFillJs
          .replaceAll('%USER%', _jsonStr(_userCtrl.text.trim()))
          .replaceAll('%PASS%', _jsonStr(_passCtrl.text));
      String fillRes = '';
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 400));
        fillRes = await _eval(js);
        setState(() => _lastJs = 'FILL[$i]: $fillRes');
        if (fillRes == 'ok') break;
        if (fillRes.startsWith('err:')) break;
      }

      final deadline = DateTime.now().add(const Duration(seconds: 30));
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
            _showWeb = false;
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _busy = false;
        _showWeb = true;
        _error = 'الأوتو فشل. سجّل يدوي من الشاشة وبياناتك محفوظة.';
        _lastJs = 'TIMEOUT. FILL=$fillRes';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'خطأ: $e';
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
        _busy = false;
      });
      return;
    }
    if (mounted) {
      final parts = _diag.split('|');
      final hasStats = parts.length >= 4 && parts[3] != '0';
      if (hasStats) {
        setState(() {
          _stage = _Stage.dashboard;
          _showWeb = false;
          _busy = false;
        });
      } else {
        setState(() => _busy = false);
      }
    }
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
      _pageLoaded = false;
      _showWeb = false;
      _diag = '—';
      _lastJs = '—';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
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
                useHybridComposition: true,
                transparentBackground: false,
              ),
              onWebViewCreated: (c) {
                _web = c;
                _webReady = true;
              },
              onLoadStart: (c, url) {
                _pageLoaded = false;
              },
              onLoadStop: (c, url) async {
                _pageLoaded = true;
                await Future.delayed(const Duration(milliseconds: 500));
                await _updateDiag();
              },
              onReceivedError: (c, req, err) {
                _lastJs = 'webview error: ${err.description}';
              },
            ),
          ),

          if (_showWeb)
            Positioned(
              top: 40,
              right: 16,
              child: SafeArea(
                child: Material(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => setState(() => _showWeb = false),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_off_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('إخفاء',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (!_showWeb)
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
                              begin: const Offset(0, 0.05), end: Offset.zero)
                          .animate(anim),
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
                          diag: _diag,
                          lastJs: _lastJs,
                          pageLoaded: _pageLoaded,
                          webReady: _webReady,
                          onSubmit: _submit,
                          onToggleWeb: () =>
                              setState(() => _showWeb = !_showWeb),
                          onRetryDiag: () async {
                            await _updateDiag();
                            await _refresh();
                          },
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Login View ───────────────────────────

class _LoginView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final GlobalKey<FormState> formKey;
  final bool busy;
  final String? error;
  final String diag;
  final String lastJs;
  final bool pageLoaded;
  final bool webReady;
  final Future<void> Function() onSubmit;
  final VoidCallback onToggleWeb;
  final Future<void> Function() onRetryDiag;

  const _LoginView({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.userCtrl,
    required this.passCtrl,
    required this.formKey,
    required this.busy,
    required this.error,
    required this.diag,
    required this.lastJs,
    required this.pageLoaded,
    required this.webReady,
    required this.onSubmit,
    required this.onToggleWeb,
    required this.onRetryDiag,
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
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _IconBtn(
                        icon: Icons.visibility_rounded,
                        onTap: onToggleWeb,
                      ),
                      const SizedBox(width: 8),
                      _IconBtn(
                        icon: isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        onTap: onToggleTheme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildLogo(theme),
                  const SizedBox(height: 24),
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
                          const SizedBox(height: 14),
                          _StatusChip(
                            webReady: webReady,
                            pageLoaded: pageLoaded,
                          ),
                          const SizedBox(height: 10),
                          _DiagBox(
                            diag: diag,
                            lastJs: lastJs,
                            onRetry: onRetryDiag,
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
                  const SizedBox(height: 16),
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
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child:
                const Icon(Icons.sms_rounded, color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'لوحة تحكم الرسائل',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ─────────────────────────── Status + Diag ───────────────────────────

class _StatusChip extends StatelessWidget {
  final bool webReady;
  final bool pageLoaded;
  const _StatusChip({required this.webReady, required this.pageLoaded});

  @override
  Widget build(BuildContext context) {
    Widget dot(bool ok, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: ok ? Colors.green : Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        );
    return Wrap(
      spacing: 14,
      children: [
        dot(webReady, 'WebView'),
        dot(pageLoaded, 'تحميل الصفحة'),
      ],
    );
  }
}

class _DiagBox extends StatelessWidget {
  final String diag;
  final String lastJs;
  final Future<void> Function() onRetry;
  const _DiagBox({
    required this.diag,
    required this.lastJs,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_rounded,
                  size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              const Text('تشخيص',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              const Spacer(),
              GestureDetector(
                onTap: () => onRetry(),
                child: const Text('تحديث',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.blueAccent,
                        decoration: TextDecoration.underline)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            diag,
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 4),
          SelectableText(
            lastJs,
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Submit button ───────────────────────────

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

// ─────────────────────────── Dashboard View ───────────────────────────

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
                        colors: const [Color(0xFF6C5CE7), Color(0xFF8E7CFF)],
                        delay: 0,
                      ),
                      const SizedBox(height: 18),
                      _StatCard(
                        title: 'رسائل هذا الأسبوع',
                        value: week,
                        icon: Icons.calendar_view_week_rounded,
                        colors: const [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
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

// ─────────────────────────── Animated Background ───────────────────────────

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