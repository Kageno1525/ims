import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

const String _kLoginUrl = 'https://imssms.org/login';
const String _kNumbersUrl = 'https://imssms.org/numbers';

// ═══════════════════════ JavaScript Constants ═══════════════════════

const String _kFillJs = r'''
(function(){
  try {
    var U = %USER%, P = %PASS%;
    var root = document.querySelector('#app') || document;
    var u = root.querySelector('input[type=text]') || root.querySelector('input[type=email]');
    var p = root.querySelector('input[type=password]');
    var b = root.querySelector('button[type=submit]') || root.querySelector('form button') || root.querySelector('button');
    if (!u || !p || !b) return 'not-ready';
    var setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(u), 'value').set
              || Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    function fire(el, val){
      el.focus();
      try { setter.call(el, val); } catch(e){ el.value = val; }
      ['input','change','keyup','blur'].forEach(function(ev){
        el.dispatchEvent(new Event(ev, {bubbles:true}));
      });
    }
    fire(u, U); fire(p, P);
    setTimeout(function(){ try{ b.click(); }catch(e){} }, 120);
    return 'ok';
  } catch(e){ return 'err:' + e.message; }
})()
''';

const String _kDiagJs = r'''
(function(){
  try {
    var url = location.href;
    var inputs = document.querySelectorAll('input').length;
    var buttons = document.querySelectorAll('button').length;
    var stats = document.querySelectorAll('.cstat-value').length;
    var bodyLen = document.body ? document.body.innerText.length : 0;
    return [url, inputs, buttons, stats, bodyLen].join('|');
  } catch(e){ return 'err:' + e.message; }
})()
''';

const String _kReadStatsJs = r'''
(function(){
  try {
    var els = document.querySelectorAll('.cstat-value');
    if (els.length >= 2) {
      var t = (els[0].innerText || '').trim();
      var w = (els[1].innerText || '').trim();
      return 'ok|' + t + '|' + w;
    }
    return 'no';
  } catch(e){ return 'err:' + e.message; }
})()
''';

/// حقن لاصطياد ملفات CSV (blob أو fetch/xhr)
const String _kBlobCaptureJs = r'''
(function(){
  try {
    window.__imsBlobContent = null;
    window.__imsDownloadName = '';

    var origCreate = URL.createObjectURL;
    if (origCreate){
      URL.createObjectURL = function(blob){
        var url = origCreate.call(URL, blob);
        try {
          var reader = new FileReader();
          reader.onload = function(){ window.__imsBlobContent = reader.result; };
          reader.readAsText(blob);
        } catch(e){}
        return url;
      };
    }

    var origClick = HTMLAnchorElement.prototype.click;
    HTMLAnchorElement.prototype.click = function(){
      try {
        if (this.download) window.__imsDownloadName = this.download;
      } catch(e){}
      return origClick.apply(this, arguments);
    };

    var origOpen = XMLHttpRequest.prototype.open;
    var origSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function(m, u){ this.__imsUrl = u; return origOpen.apply(this, arguments); };
    XMLHttpRequest.prototype.send = function(){
      var self = this;
      this.addEventListener('load', function(){
        try {
          var cd = self.getResponseHeader('content-disposition') || '';
          var ct = self.getResponseHeader('content-type') || '';
          if (ct.indexOf('csv') >= 0 || cd.toLowerCase().indexOf('.csv') >= 0 || cd.indexOf('attachment') >= 0){
            window.__imsBlobContent = self.responseText;
            var m = cd.match(/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/);
            if (m) window.__imsDownloadName = m[1].replace(/['"]/g,'');
          }
        } catch(e){}
      });
      return origSend.apply(this, arguments);
    };
  } catch(e){}
})();
''';

/// فتح قائمة الرنجات
const String _kOpenRangesJs = r'''
(function(){
  try {
    var btn = document.querySelector('#app > div > div > main > div > div:nth-child(2) > form > div > div:nth-child(1) > div > button');
    if (!btn) {
      var form = document.querySelector('form');
      if (form){
        var all = form.querySelectorAll('button');
        for (var i=0;i<all.length;i++){
          if (all[i].type !== 'submit'){ btn = all[i]; break; }
        }
      }
    }
    if (!btn) return 'no-btn';
    btn.click();
    return 'ok';
  } catch(e){ return 'err:' + e.message; }
})()
''';

/// قراءة قائمة الرنجات
const String _kReadRangesJs = r'''
(function(){
  try {
    var items = document.querySelectorAll('.ss-pop .ss-item, .ss-list .ss-item');
    var arr = [];
    items.forEach(function(li){
      var sp = li.querySelector('.ss-clear');
      if (sp){ arr.push('All ranges'); return; }
      var s = li.querySelector('span');
      var t = s ? (s.innerText || s.textContent || '').trim() : '';
      if (t) arr.push(t);
    });
    return JSON.stringify(arr);
  } catch(e){ return 'err:' + e.message; }
})()
''';

/// اختيار رنج بالاسم
const String _kSelectRangeJs = r'''
(function(){
  try {
    var name = %NAME%;
    var items = document.querySelectorAll('.ss-pop .ss-item, .ss-list .ss-item');
    for (var i=0;i<items.length;i++){
      var sp = items[i].querySelector('.ss-clear');
      var isAll = !!sp;
      var s = items[i].querySelector('span');
      var t = isAll ? 'All ranges' : (s ? (s.innerText||'').trim() : '');
      if (t === name){
        var r = items[i].getBoundingClientRect();
        var o = {bubbles:true, cancelable:true, view:window, clientX:r.left+5, clientY:r.top+5};
        items[i].dispatchEvent(new MouseEvent('mousedown', o));
        items[i].dispatchEvent(new MouseEvent('mouseup', o));
        items[i].dispatchEvent(new MouseEvent('click', o));
        return 'ok';
      }
    }
    return 'not-found';
  } catch(e){ return 'err:' + e.message; }
})()
''';

/// ضبط الـ selects (العدد + النوع)
const String _kSetFiltersJs = r'''
(function(){
  try {
    var count = %COUNT%, type = %TYPE%;
    var sels = document.querySelectorAll('select.select');
    if (!sels.length) return 'no-selects';
    var cSet = false, tSet = false;
    sels.forEach(function(s){
      var vals = Array.from(s.options).map(function(o){ return String(o.value); });
      if (!cSet && vals.indexOf(String(count)) >= 0){
        s.value = String(count);
        s.dispatchEvent(new Event('change', {bubbles:true}));
        cSet = true;
      } else if (!tSet && vals.indexOf(type) >= 0){
        s.value = type;
        s.dispatchEvent(new Event('change', {bubbles:true}));
        tSet = true;
      }
    });
    return 'ok|c=' + cSet + '|t=' + tSet;
  } catch(e){ return 'err:' + e.message; }
})()
''';

/// الضغط على Filter
const String _kClickFilterJs = r'''
(function(){
  try {
    var f = document.querySelector('#app > div > div > main > div > div:nth-child(2) > form button[type=submit]')
         || document.querySelector('button.btn-danger');
    if (!f){
      var btns = document.querySelectorAll('button');
      for (var i=0;i<btns.length;i++){
        if ((btns[i].innerText||'').trim().toLowerCase() === 'filter'){ f = btns[i]; break; }
      }
    }
    if (!f) return 'no-filter';
    f.click();
    return 'ok';
  } catch(e){ return 'err:' + e.message; }
})()
''';

/// الضغط على CSV
const String _kClickCsvJs = r'''
(function(){
  try {
    var btns = document.querySelectorAll('button');
    for (var i=0;i<btns.length;i++){
      if ((btns[i].innerText||'').trim().toUpperCase() === 'CSV'){
        btns[i].click();
        return 'ok';
      }
    }
    return 'no-csv';
  } catch(e){ return 'err:' + e.message; }
})()
''';

/// قراءة محتوى CSV المُلتقط
const String _kReadBlobJs = r'''
(function(){
  try {
    if (window.__imsBlobContent == null) return 'no-blob';
    return JSON.stringify({
      name: window.__imsDownloadName || '',
      content: window.__imsBlobContent
    });
  } catch(e){ return 'err:' + e.message; }
})()
''';

// ═══════════════════════ Enums & Log ═══════════════════════

enum _Stage { login, dashboard, numbers }

class _LogEntry {
  final String msg;
  final DateTime time;
  final _LogLevel level;
  _LogEntry(this.msg, this.time, this.level);
}

enum _LogLevel { info, ok, error, wait }

// ═══════════════════════ App Shell ═══════════════════════

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

  // Numbers page state
  List<String> _ranges = [];
  String? _selectedRange;
  int _selectedCount = 10;
  String _selectedType = 'full';
  bool _loadingRanges = false;
  bool _numbersReady = false;
  final List<_LogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _lastJs =
          'init: web=${_web != null}, ready=$_webReady, loaded=$_pageLoaded');
    });
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _log(String msg, [_LogLevel level = _LogLevel.info]) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, _LogEntry(msg, DateTime.now(), level));
      if (_logs.length > 60) _logs.removeLast();
    });
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

  String _jsonStr(String s) {
    return jsonEncode(s);
  }

  // ═══════════════ Login & Stats ═══════════════

  Future<(int, int)?> _readStats() async {
    final s = await _eval(_kReadStatsJs);
    if (!mounted) return null;
    setState(() => _lastJs = 'READ: $s');
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
      while (_web == null && sw.elapsed < const Duration(seconds: 20)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (_web == null) {
        setState(() {
          _busy = false;
          _error = 'الـ WebView مش جاهز';
        });
        return;
      }
      while (!_pageLoaded && sw.elapsed < const Duration(seconds: 22)) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      final js = _kFillJs
          .replaceAll('%USER%', _jsonStr(_userCtrl.text.trim()))
          .replaceAll('%PASS%', _jsonStr(_passCtrl.text));
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 400));
        final r = await _eval(js);
        if (mounted) setState(() => _lastJs = 'FILL[$i]: $r');
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
        _error = 'الأوتو فشل. سجّل يدوي.';
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
    await _updateDiag();
    final stats = await _readStats();
    if (stats != null && mounted) {
      setState(() {
        _today = stats.$1;
        _week = stats.$2;
        _busy = false;
      });
      return;
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
      _pageLoaded = false;
      _showWeb = false;
      _diag = '—';
      _lastJs = '—';
    });
  }

  // ═══════════════ Numbers Page Logic ═══════════════

  Future<void> _goToNumbers() async {
    setState(() {
      _stage = _Stage.numbers;
      _logs.clear();
      _ranges.clear();
      _selectedRange = null;
      _numbersReady = false;
      _loadingRanges = true;
    });
    _log('جاري فتح صفحة الأرقام…', _LogLevel.wait);

    try {
      await _web?.loadUrl(
          urlRequest: URLRequest(url: WebUri(_kNumbersUrl)));

      // استنى لحد ما الصفحة تحمّل
      final dl = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(dl)) {
        await Future.delayed(const Duration(milliseconds: 500));
        final d = await _eval(_kDiagJs);
        if (d.contains('/numbers') && d.split('|')[1] != '0') break;
      }
      _log('اتفتحت صفحة الأرقام ✅', _LogLevel.ok);

      // استنى شويّة عشان الـ Vue يبنى الـ DOM
      await Future.delayed(const Duration(milliseconds: 1200));
      await _loadRanges();
    } catch (e) {
      _log('فشل فتح الصفحة: $e', _LogLevel.error);
      setState(() => _loadingRanges = false);
    }
  }

  Future<void> _loadRanges() async {
    if (_web == null) return;
    setState(() => _loadingRanges = true);
    _log('جاري قراءة الرنجات…', _LogLevel.wait);

    // جرّب تفتح القائمة عدة مرات لحد ما تلاقي عناصر
    List<String>? found;
    for (int attempt = 0; attempt < 8; attempt++) {
      await _eval(_kOpenRangesJs);
      await Future.delayed(const Duration(milliseconds: 600));

      final raw = await _eval(_kReadRangesJs);
      if (raw.startsWith('err')) {
        _log('خطأ: $raw', _LogLevel.error);
        continue;
      }
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
      _log('مفيش رنجات ظهرت 😕', _LogLevel.error);
      setState(() => _loadingRanges = false);
      return;
    }

    setState(() {
      _ranges = found!;
      _loadingRanges = false;
      _numbersReady = true;
      _selectedRange = found.first;
    });
    _log('تم تحميل ${found.length} رنج ✅', _LogLevel.ok);
  }

  Future<void> _applyFilter() async {
    if (_selectedRange == null) {
      _log('اختار رنج الأول', _LogLevel.error);
      return;
    }
    setState(() => _busy = true);
    _log('جاري تطبيق الفلتر…', _LogLevel.wait);

    try {
      // 1) اختار الرنج
      final selJs = _kSelectRangeJs.replaceAll('%NAME%', _jsonStr(_selectedRange!));
      final r1 = await _eval(selJs);
      _log('اختيار الرنج: $r1', r1 == 'ok' ? _LogLevel.ok : _LogLevel.error);
      await Future.delayed(const Duration(milliseconds: 500));

      // 2) ضبط العدد والنوع
      final setJs = _kSetFiltersJs
          .replaceAll('%COUNT%', _selectedCount.toString())
          .replaceAll('%TYPE%', _selectedType);
      final r2 = await _eval(setJs);
      _log('ضبط الخيارات: $r2', r2.startsWith('ok') ? _LogLevel.ok : _LogLevel.error);
      await Future.delayed(const Duration(milliseconds: 400));

      // 3) اضغط Filter
      final r3 = await _eval(_kClickFilterJs);
      _log('تطبيق الفلتر: $r3', r3 == 'ok' ? _LogLevel.ok : _LogLevel.error);
      await Future.delayed(const Duration(milliseconds: 2000));

      _log('الفلتر اتطبق ✅ جاهز للتحميل', _LogLevel.ok);
    } catch (e) {
      _log('خطأ: $e', _LogLevel.error);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _downloadCsv() async {
    if (_selectedRange == null) {
      _log('اختار رنج الأول', _LogLevel.error);
      return;
    }
    setState(() => _busy = true);
    _log('جاري توليد CSV…', _LogLevel.wait);

    try {
      // صفّر المحتوى القديم
      await _eval('window.__imsBlobContent=null; window.__imsDownloadName="";');

      // اضغط CSV
      final r = await _eval(_kClickCsvJs);
      _log('ضغط CSV: $r', r == 'ok' ? _LogLevel.ok : _LogLevel.error);
      if (r != 'ok') {
        setState(() => _busy = false);
        return;
      }

      // استنى المحتوى يظهر
      String? content;
      String fileName = _selectedRange!;
      final dl = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(dl)) {
        await Future.delayed(const Duration(milliseconds: 700));
        final raw = await _eval(_kReadBlobJs);
        if (raw.startsWith('no-blob')) continue;
        if (raw.startsWith('err')) continue;
        try {
          final m = jsonDecode(raw) as Map;
          content = m['content'] as String?;
          final nm = (m['name'] as String?) ?? '';
          if (nm.isNotEmpty) {
            fileName = nm.replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
          }
          if (content != null && content.isNotEmpty) break;
        } catch (_) {}
      }

      if (content == null || content.isEmpty) {
        _log('مقدرناش نلقط محتوى الـ CSV 😕', _LogLevel.error);
        setState(() => _busy = false);
        return;
      }

      _log('تم التقاط المحتوى (${content.length} حرف)', _LogLevel.ok);

      // احفظ الملف
      final savedPath = await _saveCsv(fileName, content);
      if (savedPath == null) {
        _log('فشل حفظ الملف 😕', _LogLevel.error);
      } else {
        _log('✅ اتحفظ: $savedPath', _LogLevel.ok);
      }
    } catch (e) {
      _log('خطأ: $e', _LogLevel.error);
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

      final safe = name
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();
      final fname = '$safe.csv';
      final file = File('${dir.path}/$fname');

      // لو UTF-8 BOM يدعم العربي في Excel
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
      await file.writeAsBytes(bytes);

      return file.path;
    } catch (e) {
      return null;
    }
  }

  Future<void> _backToDashboard() async {
    setState(() {
      _stage = _Stage.dashboard;
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

  // ═══════════════ Build ═══════════════

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
                  source: _kBlobCaptureJs,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              onWebViewCreated: (c) {
                _web = c;
                if (mounted) setState(() => _webReady = true);
              },
              onLoadStart: (c, url) {
                if (mounted) setState(() => _pageLoaded = false);
              },
              onLoadStop: (c, url) async {
                if (mounted) setState(() => _pageLoaded = true);
                await Future.delayed(const Duration(milliseconds: 500));
                await _updateDiag();
              },
              onReceivedError: (c, req, err) {
                if (mounted) setState(() => _lastJs = 'err: ${err.description}');
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
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_off_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('إخفاء',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      position: Tween(begin: const Offset(0, 0.05), end: Offset.zero)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                  child: _buildCurrentStage(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentStage() {
    switch (_stage) {
      case _Stage.numbers:
        return _NumbersView(
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
      case _Stage.dashboard:
        return _DashboardView(
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
      case _Stage.login:
        return _LoginView(
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
          onToggleWeb: () => setState(() => _showWeb = !_showWeb),
          onRetryDiag: () async {
            await _updateDiag();
            await _refresh();
          },
        );
    }
  }
}

// ═══════════════════════ Login View ═══════════════════════

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
                      _IconBtn(icon: Icons.visibility_rounded, onTap: onToggleWeb),
                      const SizedBox(width: 8),
                      _IconBtn(
                        icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        onTap: onToggleTheme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _logo(theme),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(isDark ? 0.55 : 0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
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
                          Text('تسجيل الدخول',
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('ادخل بياناتك للوصول لإحصائيات الرسائل',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6))),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: userCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'من فضلك ادخل اسم المستخدم' : null,
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
                                ? 'من فضلك ادخل كلمة المرور' : null,
                            onFieldSubmitted: (_) => onSubmit(),
                          ),
                          const SizedBox(height: 14),
                          _statusChip(webReady, pageLoaded),
                          const SizedBox(height: 10),
                          _diagBox(theme, diag, lastJs, onRetryDiag),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            child: error == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: _errorBox(theme, error!),
                                  ),
                          ),
                          const SizedBox(height: 22),
                          _submitBtn(busy, onSubmit),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('IMS SMS',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 12,
                        letterSpacing: 2,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo(ThemeData theme) {
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
            child: const Icon(Icons.sms_rounded, color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 14),
        Text('لوحة تحكم الرسائل',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ═══════════════════════ Dashboard View ═══════════════════════

class _DashboardView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final int today;
  final int week;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;
  final VoidCallback onOpenNumbers;

  const _DashboardView({
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
                        Text('مرحباً 👋',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6))),
                        const SizedBox(height: 2),
                        Text('لوحة الرسائل',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  _IconBtn(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    onTap: onToggleTheme,
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: Icons.refresh_rounded,
                    spinning: busy,
                    onTap: busy ? null : () => onRefresh(),
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(icon: Icons.logout_rounded, onTap: () => onLogout()),
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
                      _StatCard(
                        title: 'رسائل اليوم',
                        value: today,
                        icon: Icons.today_rounded,
                        colors: const [Color(0xFF6C5CE7), Color(0xFF8E7CFF)],
                      ),
                      const SizedBox(height: 18),
                      _StatCard(
                        title: 'رسائل هذا الأسبوع',
                        value: week,
                        icon: Icons.calendar_view_week_rounded,
                        colors: const [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                        delay: 120,
                      ),
                      const SizedBox(height: 18),
                      _NumbersEntryCard(onTap: onOpenNumbers),
                      const SizedBox(height: 24),
                      Center(
                        child: Text('اسحب للأسفل للتحديث',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
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
}

class _NumbersEntryCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NumbersEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 820),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, 24 * (1 - t)),
        child: Opacity(opacity: t, child: child),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
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
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
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
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 18),
              ],
            ),
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
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, 24 * (1 - t)),
        child: Opacity(opacity: t, child: child),
      ),
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
                  Text(title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value.toDouble()),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutExpo,
                    builder: (_, v, __) => Text('${v.toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        )),
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

// ═══════════════════════ Numbers View ═══════════════════════

class _NumbersView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final List<String> ranges;
  final String? selectedRange;
  final int selectedCount;
  final String selectedType;
  final bool loadingRanges;
  final bool busy;
  final List<_LogEntry> logs;
  final VoidCallback onBack;
  final Future<void> Function() onRefreshRanges;
  final ValueChanged<String> onSelectRange;
  final ValueChanged<int> onSelectCount;
  final ValueChanged<String> onSelectType;
  final Future<void> Function() onApplyFilter;
  final Future<void> Function() onDownloadCsv;

  const _NumbersView({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.ranges,
    required this.selectedRange,
    required this.selectedCount,
    required this.selectedType,
    required this.loadingRanges,
    required this.busy,
    required this.logs,
    required this.onBack,
    required this.onRefreshRanges,
    required this.onSelectRange,
    required this.onSelectCount,
    required this.onSelectType,
    required this.onApplyFilter,
    required this.onDownloadCsv,
  });

  static const _counts = [10, 25, 50, 100, 500, 1000, 2000, 5000];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AnimatedBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _IconBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الأرقام',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text('اختر الرنج وفلتره وحمّله',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5))),
                      ],
                    ),
                  ),
                  _IconBtn(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    onTap: onToggleTheme,
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: Icons.refresh_rounded,
                    spinning: loadingRanges,
                    onTap: loadingRanges ? null : () => onRefreshRanges(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _card(
                theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(theme, Icons.sim_card_rounded, 'الرنج'),
                    const SizedBox(height: 10),
                    _RangePicker(
                      theme: theme,
                      ranges: ranges,
                      selected: selectedRange,
                      loading: loadingRanges,
                      onSelect: onSelectRange,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(theme, Icons.numbers_rounded, 'العدد'),
                              const SizedBox(height: 10),
                              _MiniSelect<int>(
                                theme: theme,
                                value: selectedCount,
                                items: _counts,
                                labelBuilder: (v) => v >= 1000
                                    ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K'
                                    : '$v',
                                onChanged: onSelectCount,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(theme, Icons.tag_rounded, 'النوع'),
                              const SizedBox(height: 10),
                              _MiniSelect<String>(
                                theme: theme,
                                value: selectedType,
                                items: const ['full', 'local'],
                                labelBuilder: (v) =>
                                    v == 'full' ? 'Full Num' : 'Local Num',
                                onChanged: onSelectType,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            label: 'تطبيق الفلتر',
                            icon: Icons.filter_alt_rounded,
                            gradient: const [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                            busy: busy,
                            onTap: busy ? null : () => onApplyFilter(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionBtn(
                            label: 'تحميل CSV',
                            icon: Icons.download_rounded,
                            gradient: const [Color(0xFF00B894), Color(0xFF00D68F)],
                            busy: busy,
                            onTap: busy ? null : () => onDownloadCsv(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _logsPanel(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(isDark ? 0.55 : 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _label(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }

  Widget _logsPanel(ThemeData theme) {
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
                        color: theme.colorScheme.onSurface.withOpacity(0.4))),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text('لا يوجد سجل بعد',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                            fontSize: 12)),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (_, i) {
                      final l = logs[i];
                      return _logTile(theme, l);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _logTile(ThemeData theme, _LogEntry l) {
    Color color;
    IconData icon;
    switch (l.level) {
      case _LogLevel.ok:
        color = const Color(0xFF00D68F);
        icon = Icons.check_circle_rounded;
        break;
      case _LogLevel.error:
        color = const Color(0xFFFF6B6B);
        icon = Icons.error_rounded;
        break;
      case _LogLevel.wait:
        color = const Color(0xFFFFB84D);
        icon = Icons.hourglass_top_rounded;
        break;
      case _LogLevel.info:
        color = theme.colorScheme.primary;
        icon = Icons.info_rounded;
        break;
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

class _RangePicker extends StatelessWidget {
  final ThemeData theme;
  final List<String> ranges;
  final String? selected;
  final bool loading;
  final ValueChanged<String> onSelect;

  const _RangePicker({
    required this.theme,
    required this.ranges,
    required this.selected,
    required this.loading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading || ranges.isEmpty ? null : () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: loading
                    ? Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('جاري التحميل…',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  fontSize: 14)),
                        ],
                      )
                    : Text(
                        selected ?? (ranges.isEmpty ? 'مفيش رنجات' : 'اختر رنج'),
                        style: TextStyle(
                          color: selected != null
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: selected != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _RangeSheet(
        ranges: ranges,
        selected: selected,
        onSelect: (r) {
          Navigator.pop(ctx);
          onSelect(r);
        },
      ),
    );
  }
}

class _RangeSheet extends StatefulWidget {
  final List<String> ranges;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _RangeSheet({
    required this.ranges,
    required this.selected,
    required this.onSelect,
  });
  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late TextEditingController _search;
  List<String> filtered = [];

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    filtered = widget.ranges;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('اختر الرنج',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (q) => setState(() {
                filtered = q.trim().isEmpty
                    ? widget.ranges
                    : widget.ranges
                        .where((r) =>
                            r.toLowerCase().contains(q.trim().toLowerCase()))
                        .toList();
              }),
              decoration: InputDecoration(
                hintText: 'ابحث…',
                prefixIcon: const Icon(Icons.search_rounded),
                fillColor: theme.colorScheme.surface.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('مفيش نتائج',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.5))),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final r = filtered[i];
                      final isSel = r == widget.selected;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Material(
                          color: isSel
                              ? theme.colorScheme.primary.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => widget.onSelect(r),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(
                                    isSel
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSel
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface
                                            .withOpacity(0.4),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(r,
                                        style: TextStyle(
                                          fontWeight: isSel
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          fontSize: 14,
                                        )),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _MiniSelect<T> extends StatelessWidget {
  final ThemeData theme;
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  const _MiniSelect({
    required this.theme,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(labelBuilder(e)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final bool busy;
  final VoidCallback? onTap;

  const _ActionBtn({
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
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
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

// ═══════════════════════ Shared Small Widgets ═══════════════════════

Widget _statusChip(bool webReady, bool pageLoaded) {
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
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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

Widget _diagBox(ThemeData theme, String diag, String lastJs,
    Future<void> Function() onRetry) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: theme.colorScheme.onSurface.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bug_report_rounded, size: 14, color: Colors.grey),
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
        SelectableText(diag,
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
        const SizedBox(height: 4),
        SelectableText(lastJs,
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
      ],
    ),
  );
}

Widget _errorBox(ThemeData theme, String error) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: theme.colorScheme.error.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: theme.colorScheme.error.withOpacity(0.35)),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(error,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
        ),
      ],
    ),
  );
}

Widget _submitBtn(bool busy, Future<void> Function() onSubmit) {
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
        onTap: busy ? null : () => onSubmit(),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: busy
                ? const SizedBox(
                    key: ValueKey('spin'),
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Row(
                    key: ValueKey('txt'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('دخول',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          )),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
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
                      strokeWidth: 2, color: theme.colorScheme.primary),
                )
              : Icon(icon, size: 20, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

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
            gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
          ),
        ),
      ),
    );
  }
}