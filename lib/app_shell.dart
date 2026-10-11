import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'numbers_page.dart';
import 'models.dart';
import 'web_scripts.dart';
import 'csv_reader.dart';
import 'autofill_bridge.dart';
import 'tasks/tasks_page.dart';
import 'pages/control_page.dart';
import 'pages/scripts_page.dart';
import 'pages/admin_scripts_page.dart';
import 'pages/notifications_page.dart';

const String _kLoginUrl = 'https://imssms.org/login';
const String _kNumbersUrl = 'https://imssms.org/numbers';

enum Stage {
  home,
  login,
  numbers,
  tasks,
  control,
  scripts,
  adminScripts,
  notifications
}

class AppShell extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final UserProfile userProfile;

  const AppShell({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.userProfile,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  InAppWebViewController? _web;
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Widget? _webViewWidget;

  Stage _stage = Stage.home;
  Stage _beforeLogin = Stage.home;
  bool _busy = false;
  bool _pageLoaded = false;
  bool _isLoggedIn = false;
  bool _webViewInitialized = false;

  String? _error;
  int _today = 0;
  int _week = 0;

  List<String> _ranges = [];
  String? _selectedRange;
  int _selectedCount = 10;
  String _selectedType = 'full';
  bool _loadingRanges = false;

  final ValueNotifier<List<LogEntry>> _logs =
      ValueNotifier<List<LogEntry>>(<LogEntry>[]);

  List<CsvFile> _csvFiles = [];
  String? _selectedCsvName;
  List<String> _currentNumbers = [];
  int _currentIndex = 0;
  bool _infinite = false;
  int _repeatCount = 1;
  int _completedRounds = 0;
  bool _autoTypeEnabled = true;
  bool _volumeEnabled = false;
  bool _floatingEnabled = false;
  bool _accessibilityOn = false;
  bool _overlayOn = false;

  bool _running = false;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    AutoFillBridge.setListener(
      onVolume: (action) async {
        if (!_running || !_volumeEnabled) return;
        if (action == 'vol_up') {
          await _advanceNumber(forward: true, source: 'Volume Up');
        } else if (action == 'vol_down') {
          await _advanceNumber(forward: false, source: 'Volume Down');
        }
      },
      onFloatingClick: () async {
        if (!_running || !_floatingEnabled) return;
        await _advanceNumber(forward: true, source: 'أيقونة عائمة');
      },
    );

    Future.microtask(_bootstrap);

    _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      if (_stage == Stage.numbers && _isLoggedIn && !_busy) {
        _refresh(silent: true);
      }
    });
  }

  // ⭐ مراقبة تغيير showNumbers — يطرد اليوزر من صفحة الأرقام
  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.userProfile.showNumbers !=
        oldWidget.userProfile.showNumbers) {
      if (!widget.userProfile.showNumbers && _stage == Stage.numbers) {
        _backToHome();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إلغاء صلاحية صفحة الأرقام'),
                backgroundColor: Color(0xFFFFB84D),
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _bootstrap() async {
    await _refreshPermissions();
    await _refreshFiles();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _userCtrl.dispose();
    _passCtrl.dispose();
    _logs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  void _initWebViewIfNeeded() {
    if (_webViewInitialized) return;
    _webViewInitialized = true;
    _webViewWidget = InAppWebView(
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
      onLoadStart: (c, url) {
        if (mounted) setState(() => _pageLoaded = false);
      },
      onLoadStop: (c, url) async {
        if (mounted) setState(() => _pageLoaded = true);
      },
    );
  }

  Future<void> _refreshPermissions() async {
    final a = await AutoFillBridge.isAccessibilityEnabled();
    final o = await AutoFillBridge.hasOverlayPermission();
    if (!mounted) return;
    if (a == _accessibilityOn && o == _overlayOn) return;
    setState(() {
      _accessibilityOn = a;
      _overlayOn = o;
    });
  }

  void _log(String msg, [LogLevel level = LogLevel.info]) {
    final cur = _logs.value;
    final updated = <LogEntry>[LogEntry(msg, DateTime.now(), level), ...cur];
    if (updated.length > 100) updated.removeRange(100, updated.length);
    _logs.value = updated;
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
      return _unwrap(await _web!.evaluateJavascript(source: js));
    } catch (e) {
      return 'err:$e';
    }
  }

  String _js(String s) => jsonEncode(s);

  Future<(int, int)?> _readStats() async {
    final s = await _eval(WebScripts.readStats);
    if (!s.startsWith('ok|')) return null;
    final parts = s.split('|');
    if (parts.length < 3) return null;
    final t = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final w = int.tryParse(parts[2].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return (t, w);
  }

  Future<void> _onOpenNumbers() async {
    if (_isLoggedIn) {
      await _goToNumbers();
    } else {
      _beforeLogin = Stage.numbers;
      setState(() {
        _stage = Stage.login;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    _initWebViewIfNeeded();
    setState(() {});

    try {
      final sw = Stopwatch()..start();
      while (_web == null && sw.elapsed < const Duration(seconds: 15)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (_web == null) {
        setState(() {
          _busy = false;
          _error = 'الـ WebView مش جاهز';
        });
        return;
      }
      while (!_pageLoaded && sw.elapsed < const Duration(seconds: 20)) {
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
            _today = st.$1;
            _week = st.$2;
            _busy = false;
            _isLoggedIn = true;
          });
          if (_beforeLogin == Stage.numbers) {
            await _goToNumbers();
          } else {
            setState(() => _stage = Stage.home);
          }
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'البيانات غلط أو الموقع بطيء. حاول تاني.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'خطأ: $e';
      });
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_web == null || !_isLoggedIn) return;
    if (!silent && _busy) return;
    if (!silent) setState(() => _busy = true);
    final st = await _readStats();
    if (st != null && mounted) {
      if (_today != st.$1 || _week != st.$2) {
        setState(() {
          _today = st.$1;
          _week = st.$2;
        });
      }
      if (!silent) setState(() => _busy = false);
      return;
    }
    if (!silent && mounted) setState(() => _busy = false);
  }

  Future<void> _logoutFromNumbers() async {
    setState(() {
      _isLoggedIn = false;
      _today = 0;
      _week = 0;
      _error = null;
      _passCtrl.clear();
      _stage = Stage.home;
      _ranges.clear();
      _selectedRange = null;
    });
    try {
      await _web?.loadUrl(urlRequest: URLRequest(url: WebUri(_kLoginUrl)));
    } catch (_) {}
  }

  Future<void> _backFromLogin() async {
    setState(() {
      _stage = Stage.home;
      _error = null;
      _busy = false;
    });
  }

  Future<void> _goToNumbers() async {
    _logs.value = <LogEntry>[];
    setState(() {
      _stage = Stage.numbers;
      _ranges.clear();
      _selectedRange = null;
      _loadingRanges = true;
    });
    _log('جاري فتح صفحة الأرقام…', LogLevel.wait);

    await _refreshFiles();

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
      await _refresh(silent: true);
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
        if (list.isNotEmpty) {
          found = list;
          break;
        }
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

      final sel = await _eval(
        WebScripts.selectRange.replaceAll('%NAME%', _js(name)),
      );
      _log(
        'محاولة $attempt: "$name" → $sel',
        sel == 'ok' ? LogLevel.info : LogLevel.wait,
      );
      await Future.delayed(const Duration(milliseconds: 900));

      final after = await _eval(WebScripts.readRangeButton);
      if (after.contains(name)) {
        _log('الرنج "$name" اتحدد ✅', LogLevel.ok);
        return true;
      }
    }
    return false;
  }

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
      _log('الفلتر اتطبق ✅', LogLevel.ok);
    } catch (e) {
      _log('خطأ: $e', LogLevel.error);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _downloadCsv() async {
    if (_selectedRange == null) {
      _log('اختار رنج الأول', LogLevel.error);
      return;
    }
    setState(() => _busy = true);
    _log('جاري تجهيز التحميل…', LogLevel.wait);

    try {
      final setJs = WebScripts.setFilters
          .replaceAll('%COUNT%', _selectedCount.toString())
          .replaceAll('%TYPE%', _selectedType);
      final rOpt = await _eval(setJs);
      _log('إرسال الضبط: $rOpt', LogLevel.info);

      await Future.delayed(const Duration(milliseconds: 800));
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
        } catch (_) {}
      }

      if (!cOk || !tOk) {
        _log('مقدرناش نظبط العدد/النوع 😕', LogLevel.error);
        setState(() => _busy = false);
        return;
      }

      await Future.delayed(const Duration(milliseconds: 400));
      await _eval(WebScripts.clearBlob);
      final r = await _eval(WebScripts.clickCsv);
      _log('ضغط CSV: $r', r == 'ok' ? LogLevel.ok : LogLevel.error);
      if (r != 'ok') {
        setState(() => _busy = false);
        return;
      }

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

      final saved = await _saveCsv(_selectedRange!, content);
      if (saved == null) {
        _log('فشل حفظ الملف 😕', LogLevel.error);
      } else {
        _log('✅ اتحفظ: $saved', LogLevel.ok);
        await _refreshFiles();
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
        for (final p in [
          '/storage/emulated/0/Download',
          '/sdcard/Download'
        ]) {
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

      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  Future<void> _refreshFiles() async {
    final list = await CsvReader.listFiles();
    if (!mounted) return;
    if (_csvFiles.length == list.length &&
        _csvFiles.every((f) =>
            list.any((g) => g.name == f.name && g.count == f.count))) {
      return;
    }
    setState(() {
      _csvFiles = list;
      if (_selectedCsvName == null && list.isNotEmpty) {
        _selectedCsvName = list.first.name;
      }
      if (_selectedCsvName != null &&
          !list.any((f) => f.name == _selectedCsvName)) {
        _selectedCsvName = list.isEmpty ? null : list.first.name;
      }
    });
    if (_selectedCsvName != null && _currentNumbers.isEmpty) {
      await _loadCsvNumbers(_selectedCsvName!);
    }
  }

  Future<void> _loadCsvNumbers(String name) async {
    final file = _csvFiles.firstWhere(
      (f) => f.name == name,
      orElse: () => CsvFile(name: '', path: '', count: 0),
    );
    if (file.path.isEmpty) return;
    final numbers = await CsvReader.readColumnC(file.path);
    if (!mounted) return;
    setState(() {
      _currentNumbers = numbers;
      _currentIndex = 0;
      _completedRounds = 0;
    });
    _log('تحميل "$name": ${numbers.length} رقم ✅', LogLevel.ok);
    if (_floatingEnabled) {
      await AutoFillBridge.updateFloatingText(_currentDisplay);
    }
  }

  String get _currentDisplay {
    if (_currentNumbers.isEmpty) return '—';
    if (_currentIndex < 0 || _currentIndex >= _currentNumbers.length) {
      return '—';
    }
    return _currentNumbers[_currentIndex];
  }

  Future<void> _advanceNumber({
    required bool forward,
    required String source,
  }) async {
    if (_currentNumbers.isEmpty) return;
    if (!_running) return;

    int next = _currentIndex + (forward ? 1 : -1);

    if (next >= _currentNumbers.length) {
      if (_infinite || _completedRounds < _repeatCount - 1) {
        next = 0;
        _completedRounds++;
        _log('🔁 دورة جديدة ($_completedRounds)', LogLevel.info);
      } else {
        _log('⏹️ خلصنا كل الدورات ($_repeatCount)', LogLevel.ok);
        return;
      }
    } else if (next < 0) {
      next = _currentNumbers.length - 1;
    }

    setState(() => _currentIndex = next);

    final num = _currentNumbers[next];
    _log('$source → $num', LogLevel.ok);

    if (_autoTypeEnabled) {
      final ok = await AutoFillBridge.typeText(num);
      if (ok) {
        _log('✅ الكتابة نجحت', LogLevel.ok);
      } else {
        _log('⚠️ الكتابة فشلت (جرب تاني)', LogLevel.error);
      }
    }

    if (_floatingEnabled) {
      await AutoFillBridge.updateFloatingText(num);
    }
  }

  Future<void> _prevNumber() =>
      _advanceNumber(forward: false, source: 'السابق');

  Future<void> _nextNumber() =>
      _advanceNumber(forward: true, source: 'التالي');

  Future<void> _copyCurrent() async {
    if (_currentNumbers.isEmpty) return;
    final num = _currentNumbers[_currentIndex];
    await Clipboard.setData(ClipboardData(text: num));
    _log('📋 اتنسخ: $num', LogLevel.ok);
  }

  Future<void> _typeCurrent() async {
    if (_currentNumbers.isEmpty) return;
    final num = _currentNumbers[_currentIndex];
    final ok = await AutoFillBridge.typeText(num);
    _log(
      ok ? '✅ اكتب: $num' : '⚠️ فشل الكتابة',
      ok ? LogLevel.ok : LogLevel.error,
    );
  }

  Future<void> _toggleRunning() async {
    final newVal = !_running;
    setState(() => _running = newVal);
    _log(
      newVal ? '🟢 التشغيل اتفعّل' : '🔴 التشغيل اتوقف',
      newVal ? LogLevel.ok : LogLevel.info,
    );
  }

  Future<void> _resetCounter() async {
    setState(() {
      _currentIndex = 0;
      _completedRounds = 0;
    });
    _log('🔄 تم إعادة التعيين', LogLevel.ok);
    if (_floatingEnabled) {
      await AutoFillBridge.updateFloatingText(_currentDisplay);
    }
  }

  Future<void> _toggleAutoType(bool v) async {
    setState(() => _autoTypeEnabled = v);
  }

  Future<void> _toggleVolume(bool v) async {
    if (v && !_accessibilityOn) {
      _log('فعّل Accessibility الأول', LogLevel.error);
      await AutoFillBridge.openAccessibilitySettings();
      return;
    }
    setState(() => _volumeEnabled = v);
    if (v) {
      await AutoFillBridge.startVolumeListener();
      _log('🎚️ أزرار الصوت اتفعّلت', LogLevel.ok);
    } else {
      await AutoFillBridge.stopVolumeListener();
      _log('🎚️ أزرار الصوت اتقفلت', LogLevel.info);
    }
  }

  Future<void> _toggleFloating(bool v) async {
    if (v && !_overlayOn) {
      _log('فعّل صلاحية الأيقونة العائمة', LogLevel.error);
      await AutoFillBridge.openOverlaySettings();
      return;
    }
    if (v) {
      final ok = await AutoFillBridge.showFloating();
      if (ok) {
        setState(() => _floatingEnabled = true);
        await AutoFillBridge.updateFloatingText(_currentDisplay);
        _log('🔵 الأيقونة العائمة ظهرت', LogLevel.ok);
      } else {
        _log('فشل ظهور الأيقونة', LogLevel.error);
      }
    } else {
      await AutoFillBridge.hideFloating();
      setState(() => _floatingEnabled = false);
      _log('🔵 الأيقونة العائمة اتقفلت', LogLevel.info);
    }
  }

  Future<void> _openAccessibility() async {
    await AutoFillBridge.openAccessibilitySettings();
  }

  Future<void> _openOverlay() async {
    await AutoFillBridge.openOverlaySettings();
  }

  Future<void> _backToHome() async {
    if (_volumeEnabled) await AutoFillBridge.stopVolumeListener();
    if (_floatingEnabled) await AutoFillBridge.hideFloating();

    setState(() {
      _stage = Stage.home;
      _ranges.clear();
      _selectedRange = null;
      _volumeEnabled = false;
      _floatingEnabled = false;
      _running = false;
    });
    _logs.value = <LogEntry>[];
  }

  void _openTasks() => setState(() => _stage = Stage.tasks);
  void _openControl() => setState(() => _stage = Stage.control);
  void _closeToHome() => setState(() => _stage = Stage.home);

  void _openScripts() {
    setState(() {
      _stage = widget.userProfile.isAdmin
          ? Stage.adminScripts
          : Stage.scripts;
    });
  }

  void _openNotifications() =>
      setState(() => _stage = Stage.notifications);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          if (_webViewInitialized && _webViewWidget != null)
            Positioned.fill(child: _webViewWidget!),
          Positioned.fill(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: _buildStage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case Stage.notifications:
        return NotificationsPage(
          key: const ValueKey('notifications'),
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
          onBack: _closeToHome,
        );

      case Stage.adminScripts:
        return AdminScriptsPage(
          key: const ValueKey('admin-scripts'),
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
          onBack: _closeToHome,
        );

      case Stage.control:
        return ControlPage(
          key: const ValueKey('control'),
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
          onBack: _closeToHome,
          adminProfile: widget.userProfile,
        );

      case Stage.scripts:
        return ScriptsPage(
          key: const ValueKey('scripts'),
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
          onBack: _closeToHome,
          profile: widget.userProfile,
        );

      case Stage.tasks:
        return TasksPage(
          key: const ValueKey('tasks'),
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
          onBack: _closeToHome,
          onLog: (e) => _log(e.msg, e.level),
          currentNumbers: _currentNumbers,
          currentCsvIndex: _currentIndex,
        );

      case Stage.numbers:
        return NumbersPage(
          key: const ValueKey('numbers'),
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
          today: _today,
          week: _week,
          ranges: _ranges,
          selectedRange: _selectedRange,
          selectedCount: _selectedCount,
          selectedType: _selectedType,
          loadingRanges: _loadingRanges,
          busy: _busy,
          onRefreshRanges: _loadRanges,
          onSelectRange: (r) => setState(() => _selectedRange = r),
          onSelectCount: (c) => setState(() => _selectedCount = c),
          onSelectType: (t) => setState(() => _selectedType = t),
          onApplyFilter: _applyFilter,
          onDownloadCsv: _downloadCsv,
          csvFiles: _csvFiles,
          selectedCsvName: _selectedCsvName,
          currentNumbers: _currentNumbers,
          currentIndex: _currentIndex,
          infinite: _infinite,
          repeatCount: _repeatCount,
          autoTypeEnabled: _autoTypeEnabled,
          volumeEnabled: _volumeEnabled,
          floatingEnabled: _floatingEnabled,
          accessibilityOn: _accessibilityOn,
          overlayOn: _overlayOn,
          running: _running,
          onToggleRunning: _toggleRunning,
          onReset: _resetCounter,
          onRefreshFiles: _refreshFiles,
          onSelectCsv: (name) async {
            setState(() => _selectedCsvName = name);
            await _loadCsvNumbers(name);
          },
          onPrevNumber: _prevNumber,
          onNextNumber: _nextNumber,
          onCopyCurrent: _copyCurrent,
          onTypeCurrent: _typeCurrent,
          onToggleInfinite: (v) => setState(() => _infinite = v),
          onSetRepeat: (v) => setState(() => _repeatCount = v),
          onToggleAutoType: _toggleAutoType,
          onToggleVolume: _toggleVolume,
          onToggleFloating: _toggleFloating,
          onOpenAccessibility: _openAccessibility,
          onOpenOverlay: _openOverlay,
          logs: _logs,
          onBack: _backToHome,
          onLogout: _logoutFromNumbers,
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
          onBack: _backFromLogin,
        );

      case Stage.home:
        return HomePage(
          key: const ValueKey('home'),
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
          profile: widget.userProfile,
          onOpenNumbers: _onOpenNumbers,
          onOpenTasks: _openTasks,
          onOpenControl: _openControl,
          onOpenScripts: _openScripts,
          onOpenNotifications: _openNotifications,
        );
    }
  }
}