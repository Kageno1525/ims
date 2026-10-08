import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'numbers_page.dart';
import 'models.dart';
import 'web_scripts.dart';

const String _kLoginUrl = 'https://imssms.org/login';
const String _kNumbersUrl = 'https://imssms.org/numbers';

enum Stage { login, dashboard, numbers }

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

  Stage _stage = Stage.login;
  bool _busy = false;
  bool _showWeb = false;
  bool _pageLoaded = false;

  String? _error;
  int _today = 0;
  int _week = 0;

  // Numbers
  List<String> _ranges = [];
  String? _selectedRange;
  int _selectedCount = 10;
  String _selectedType = 'full';
  bool _loadingRanges = false;
  final List<LogEntry> _logs = [];

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _log(String msg, [LogLevel level = LogLevel.info]) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, LogEntry(msg, DateTime.now(), level));
      if (_logs.length > 80) _logs.removeLast();
    });
  }

  String _unwrap(dynamic raw) {
    if (raw == null) return '';
    var s = raw.toString().trim();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1).replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    }
    return s;
  }

  Future<String> _eval(String js) async {
    if (_web == null) return 'no-web';
    try {
      return _unwrap(await _web!.evaluateJavascript(source: js));
    } catch (e) {
      return 'err:$e';
    }
  }

  String _js(String s) => jsonEncode(s);

  // ═══════ Login ═══════
  Future<(int, int)?> _readStats() async {
    final s = await _eval(WebScripts.readStats);
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
    setState(() { _busy = true; _error = null; });
    try {
      final sw = Stopwatch()..start();
      while (_web == null && sw.elapsed < const Duration(seconds: 20)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (_web == null) {
        setState(() { _busy = false; _error = 'الـ WebView مش جاهز'; });
        return;
      }
      while (!_pageLoaded && sw.elapsed < const Duration(seconds: 22)) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      final js = WebScripts.fillLogin
          .replaceAll('%USER%', _js(_userCtrl.text.trim()))
          .replaceAll('%PASS%', _js(_passCtrl.text));
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 400));
        final r = await _eval(js);
        if (r == 'ok' || r.startsWith('err:')) break;
      }
      final dl = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(dl)) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        final st = await _readStats();
        if (st != null) {
          setState(() {
            _today = st.$1; _week = st.$2; _busy = false;
            _stage = Stage.dashboard; _showWeb = false;
          });
          return;
        }
      }
      if (!mounted) return;
      setState(() { _busy = false; _showWeb = true; _error = 'الأوتو فشل. سجّل يدوي.'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _error = 'خطأ: $e'; });
    }
  }

  Future<void> _refresh() async {
    if (_web == null || _busy) return;
    setState(() => _busy = true);
    final st = await _readStats();
    if (st != null && mounted) {
      setState(() { _today = st.$1; _week = st.$2; _busy = false; });
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _logout() async {
    try { await _web?.loadUrl(urlRequest: URLRequest(url: WebUri(_kLoginUrl))); } catch (_) {}
    if (!mounted) return;
    setState(() {
      _stage = Stage.login; _today = 0; _week = 0; _error = null;
      _passCtrl.clear(); _pageLoaded = false; _showWeb = false;
    });
  }

  // ═══════ Numbers ═══════
  Future<void> _goToNumbers() async {
    setState(() {
      _stage = Stage.numbers;
      _logs.clear();
      _ranges.clear();
      _selectedRange = null;
      _loadingRanges = true;
    });
    _log('جاري فتح صفحة الأرقام…', LogLevel.wait);

    try {
      await _web?.loadUrl(urlRequest: URLRequest(url: WebUri(_kNumbersUrl)));
      final dl = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(dl)) {
        await Future.delayed(const Duration(milliseconds: 500));
        final d = await _eval(WebScripts.diag);
        if (d.contains('/numbers') && d.split('|')[1] != '0') break;
      }
      _log('اتفتحت صفحة الأرقام ✅', LogLevel.ok);
      await Future.delayed(const Duration(milliseconds: 1200));
      await _loadRanges();
    } catch (e) {
      _log('فشل فتح الصفحة: $e', LogLevel.error);
      setState(() => _loadingRanges = false);
    }
  }

  Future<void> _loadRanges() async {
    if (_web == null) return;
    setState(() => _loadingRanges = true);
    _log('جاري قراءة الرنجات…', LogLevel.wait);

    List<String>? found;
    for (int attempt = 0; attempt < 8; attempt++) {
      await _eval(WebScripts.openRanges);
      await Future.delayed(const Duration(milliseconds: 600));
      final raw = await _eval(WebScripts.readRanges);
      if (raw.startsWith('err')) continue;
      try {
        final list = (jsonDecode(raw) as List).cast<String>();
        if (list.isNotEmpty) { found = list; break; }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (found == null || found.isEmpty) {
      _log('مفيش رنجات ظهرت 😕', LogLevel.error);
      setState(() => _loadingRanges = false);
      return;
    }

    setState(() {
      _ranges = found!;
      _loadingRanges = false;
      if (_selectedRange == null || !found.contains(_selectedRange)) {
        _selectedRange = found.first;
      }
    });
    _log('تم تحميل ${found.length} رنج ✅', LogLevel.ok);
  }

  Future<bool> _ensureRangeSelected(String name) async {
    final current = await _eval(WebScripts.readRangeButton);
    if (current.contains(name)) return true;

    for (int attempt = 1; attempt <= 4; attempt++) {
      final isOpen = await _eval(WebScripts.isRangeDropdownOpen);
      if (!isOpen.contains('yes')) {
        await _eval(WebScripts.openRanges);
        await Future.delayed(const Duration(milliseconds: 700));
      }

      final sel = await _eval(WebScripts.selectRange.replaceAll('%NAME%', _js(name)));
      _log('محاولة $attempt: "$name" → $sel', sel == 'ok' ? LogLevel.info : LogLevel.wait);
      await Future.delayed(const Duration(milliseconds: 900));

      final after = await _eval(WebScripts.readRangeButton);
      if (after.contains(name)) {
        _log('الرنج "$name" اتحدد ✅', LogLevel.ok);
        return true;
      }
    }
    return false;
  }

  // ═══════ تطبيق الفلتر (الرنج بس) ═══════
  Future<void> _applyFilter() async {
    if (_selectedRange == null) {
      _log('اختار رنج الأول', LogLevel.error);
      return;
    }
    setState(() => _busy = true);
    _log('جاري تطبيق فلتر الرنج…', LogLevel.wait);

    try {
      final ok = await _ensureRangeSelected(_selectedRange!);
      if (!ok) {
        _log('فشل اختيار الرنج 😕', LogLevel.error);
        setState(() => _busy = false);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));

      final r = await _eval(WebScripts.clickFilter);
      _log('Filter: $r', r == 'ok' ? LogLevel.ok : LogLevel.error);
      await Future.delayed(const Duration(milliseconds: 2500));

      _log('الفلتر اتطبق ✅ دلوقتي حدد العدد والنوع واضغط تحميل', LogLevel.ok);
    } catch (e) {
      _log('خطأ: $e', LogLevel.error);
    }
    if (mounted) setState(() => _busy = false);
  }

  // ═══════ تحميل CSV ═══════
  Future<void> _downloadCsv() async {
    if (_selectedRange == null) {
      _log('اختار رنج الأول', LogLevel.error);
      return;
    }
    setState(() => _busy = true);
    _log('جاري تجهيز التحميل…', LogLevel.wait);

    try {
      // 1) اضبط العدد والنوع
      final setJs = WebScripts.setFilters
          .replaceAll('%COUNT%', _selectedCount.toString())
          .replaceAll('%TYPE%', _selectedType);
      final rOpt = await _eval(setJs);
      _log('إرسال الضبط: $rOpt', LogLevel.info);

      // 2) استنى Vue يعمل re-render
      await Future.delayed(const Duration(milliseconds: 800));

      // 3) تحقق من القيم الحقيقية
      final vRaw = await _eval(WebScripts.verifyFilters);
      _log('تحقق: $vRaw', LogLevel.info);

      bool cOk = false, tOk = false;
      if (vRaw.startsWith('{')) {
        try {
          final m = jsonDecode(vRaw) as Map;
          final c = (m['c'] ?? '').toString();
          final t = (m['t'] ?? '').toString();
          final wc = (m['wantC'] ?? '').toString();
          final wt = (m['wantT'] ?? '').toString();
          cOk = c == wc;
          tOk = t == wt;
          _log(
            'العدد: $c (مطلوب $wc) ${cOk ? "✅" : "❌"} | النوع: $t (مطلوب $wt) ${tOk ? "✅" : "❌"}',
            cOk && tOk ? LogLevel.ok : LogLevel.error,
          );
        } catch (e) {
          _log('فشل تحليل التحقق', LogLevel.error);
        }
      }

      if (!cOk || !tOk) {
        _log('مقدرناش نظبط العدد/النوع 😕', LogLevel.error);
        setState(() => _busy = false);
        return;
      }

      await Future.delayed(const Duration(milliseconds: 400));

      // 4) صفّر الـ blob القديم
      await _eval(WebScripts.clearBlob);

      // 5) اضغط CSV
      final r = await _eval(WebScripts.clickCsv);
      _log('ضغط CSV: $r', r == 'ok' ? LogLevel.ok : LogLevel.error);
      if (r != 'ok') {
        setState(() => _busy = false);
        return;
      }

      // 6) استنى المحتوى
      String? content;
      final dl = DateTime.now().add(const Duration(seconds: 25));
      while (DateTime.now().isBefore(dl)) {
        await Future.delayed(const Duration(milliseconds: 700));
        final raw = await _eval(WebScripts.readBlob);
        if (raw.startsWith('no-blob') || raw.startsWith('err')) continue;
        try {
          final m = jsonDecode(raw) as Map;
          content = m['content'] as String?;
          if (content != null && content.isNotEmpty) break;
        } catch (_) {}
      }

      if (content == null || content.isEmpty) {
        _log('مقدرناش نلقط محتوى الـ CSV 😕', LogLevel.error);
        setState(() => _busy = false);
        return;
      }
      _log('تم التقاط المحتوى (${content.length} حرف)', LogLevel.ok);

      // 7) احفظ باسم الرنج
      final saved = await _saveCsv(_selectedRange!, content);
      if (saved == null) {
        _log('فشل حفظ الملف 😕', LogLevel.error);
      } else {
        _log('✅ اتحفظ: $saved', LogLevel.ok);
      }
    } catch (e) {
      _log('خطأ: $e', LogLevel.error);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<String?> _saveCsv(String name, String content) async {
    try {
      Directory? base;
      if (Platform.isAndroid) {
        for (final p in ['/storage/emulated/0/Download', '/sdcard/Download']) {
          try {
            final d = Directory(p);
            if (await d.exists()) {
              final t = File('${d.path}/.ims_test');
              await t.writeAsString('x');
              await t.delete();
              base = d;
              break;
            }
          } catch (_) {}
        }
      }
      base ??= await getDownloadsDirectory();
      base ??= await getExternalStorageDirectory();
      base ??= await getApplicationDocumentsDirectory();

      final dir = Directory('${base.path}/ranges');
      if (!await dir.exists()) await dir.create(recursive: true);

      final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final file = File('${dir.path}/$safe.csv');
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  Future<void> _backToDashboard() async {
    setState(() {
      _stage = Stage.dashboard;
      _logs.clear();
      _ranges.clear();
      _selectedRange = null;
    });
    try {
      await _web?.loadUrl(urlRequest: URLRequest(url: WebUri('https://imssms.org/')));
      await Future.delayed(const Duration(seconds: 2));
      await _refresh();
    } catch (_) {}
  }

  // ═══════ Build ═══════
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
                mediaPlaybackRequiresUserGesture: false,
              ),
              initialUserScripts: UnmodifiableListView<UserScript>([
                UserScript(
                  source: WebScripts.blobCapture,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              onWebViewCreated: (c) => _web = c,
              onLoadStart: (c, url) { if (mounted) setState(() => _pageLoaded = false); },
              onLoadStop: (c, url) async {
                if (mounted) setState(() => _pageLoaded = true);
              },
            ),
          ),
          if (_showWeb)
            Positioned(
              top: 40, right: 16,
              child: SafeArea(
                child: Material(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => setState(() => _showWeb = false),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_off_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('إخفاء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _buildStage(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case Stage.numbers:
        return NumbersPage(
          key: const ValueKey('numbers'),
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
          ranges: _ranges,
          selectedRange: _selectedRange,
          selectedCount: _selectedCount,
          selectedType: _selectedType,
          loadingRanges: _loadingRanges,
          busy: _busy,
          logs: _logs,
          onBack: _backToDashboard,
          onRefreshRanges: _loadRanges,
          onSelectRange: (r) => setState(() => _selectedRange = r),
          onSelectCount: (c) => setState(() => _selectedCount = c),
          onSelectType: (t) => setState(() => _selectedType = t),
          onApplyFilter: _applyFilter,
          onDownloadCsv: _downloadCsv,
        );
      case Stage.dashboard:
        return DashboardPage(
          key: const ValueKey('dash'),
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
          today: _today,
          week: _week,
          busy: _busy,
          onRefresh: _refresh,
          onLogout: _logout,
          onOpenNumbers: _goToNumbers,
        );
      case Stage.login:
        return LoginPage(
          key: const ValueKey('login'),
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
          userCtrl: _userCtrl,
          passCtrl: _passCtrl,
          formKey: _formKey,
          busy: _busy,
          error: _error,
          onSubmit: _submit,
          onToggleWeb: () => setState(() => _showWeb = !_showWeb),
        );
    }
  }
}