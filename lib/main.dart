import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KagenoApp());
}

class KagenoApp extends StatefulWidget {
  const KagenoApp({Key? key}) : super(key: key);

  @override
  State<KagenoApp> createState() => _KagenoAppState();
}

class _KagenoAppState extends State<KagenoApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IMSSMS Control Center',
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F3F8),
        primaryColor: const Color(0xFF6C5CE7),
        cardColor: Colors.white,
        fontFamily: GoogleFonts.cairo().fontFamily,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07090E),
        primaryColor: const Color(0xFF00FFA3),
        cardColor: const Color(0xFF111420),
        fontFamily: GoogleFonts.cairo().fontFamily,
      ),
      home: LoginScreen(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

// Global Controller للـ WebView ليعمل في خلفية التطبيق بين الصفحات
InAppWebViewController? globalWebViewController;

// -------------------------------------------------------------
// 1️⃣ شاشة تسجيل الدخول (LOGIN SCREEN)
// -------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const LoginScreen({
    Key? key,
    required this.onToggleTheme,
    required this.isDark,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;
  bool _isWebViewReady = false;

  Future<void> _executeLogin() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) {
      _showSnackBar("اكتب اسم المستخدم والباسورد الأول يا كاجينو!");
      return;
    }

    if (!_isWebViewReady || globalWebViewController == null) {
      _showSnackBar("جاري تجهيز الاتصال بالموقع، انتظر ثواني وجرب تاني...");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final username = _userController.text.trim();
    final password = _passController.text.trim();

    // 1. حقن كود الدخول
    await globalWebViewController?.evaluateJavascript(source: '''
      (function() {
        let userInput = document.querySelector('#app > div > form > div.login-body.classic-body > div:nth-child(3) > input[type=text]');
        let passInput = document.querySelector('#app > div > form > div.login-body.classic-body > div.pill-input.has-reveal > input[type=password]');
        let submitBtn = document.querySelector('#app > div > form > div.login-body.classic-body > button');

        if (userInput && passInput) {
          userInput.value = '$username';
          passInput.value = '$password';

          userInput.dispatchEvent(new Event('input', { bubbles: true }));
          passInput.dispatchEvent(new Event('input', { bubbles: true }));

          if (submitBtn) {
            setTimeout(() => { submitBtn.click(); }, 300);
          }
        }
      })();
    ''');

    // 2. الانتظار للانتقال لصفحة الـ Dashboard
    await Future.delayed(const Duration(seconds: 4));

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    // 3. الانتقال لصفحة الـ SMS Dashboard
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SmsDashboardScreen(
          onToggleTheme: widget.onToggleTheme,
          isDark: widget.isDark,
        ),
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00FFA3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryColor =
        isDark ? const Color(0xFF00FFA3) : const Color(0xFF6C5CE7);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? const Color(0xFF80FFA3) : const Color(0xFF2D3436),
            ),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView خفي ومستمر
          SizedBox(
            height: 1,
            width: 1,
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://imssms.org/login'),
              ),
              onWebViewCreated: (controller) {
                globalWebViewController = controller;
              },
              onLoadStop: (controller, url) {
                setState(() {
                  _isWebViewReady = true;
                });
              },
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // شعار/عنوان التطبيق
                  Icon(
                    Icons.security_rounded,
                    size: 70,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'IMSSMS CONTROL',
                    style: GoogleFonts.orbitron(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سجل دخولك للتحكم والمتابعة اللحظية',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // كارت تسجيل الدخول
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111420) : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.15),
                          blurRadius: 25,
                          spreadRadius: 2,
                        )
                      ],
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _userController,
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            labelText: 'اسم المستخدم / الإيميل',
                            labelStyle: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54),
                            prefixIcon:
                                Icon(Icons.person_outline, color: primaryColor),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1A1D2B)
                                : const Color(0xFFF1F2F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _passController,
                          obscureText: true,
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            labelStyle: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54),
                            prefixIcon:
                                Icon(Icons.lock_outline, color: primaryColor),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1A1D2B)
                                : const Color(0xFFF1F2F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _executeLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.black)
                              : const Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 2️⃣ شاشة العرض والمتابعة التلقائية (SMS DASHBOARD SCREEN)
// -------------------------------------------------------------
class SmsDashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const SmsDashboardScreen({
    Key? key,
    required this.onToggleTheme,
    required this.isDark,
  }) : super(key: key);

  @override
  State<SmsDashboardScreen> createState() => _SmsDashboardScreenState();
}

class _SmsDashboardScreenState extends State<SmsDashboardScreen>
    with SingleTickerProviderStateMixin {
  String _smsToday = "--";
  String _smsThisWeek = "--";
  Timer? _liveTimer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // ⏱️ بدء التحديث التلقائي اللحظي كل ثانية واحدة!
    _startLiveSync();
  }

  void _startLiveSync() {
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchLiveSmsData();
    });
  }

  Future<void> _fetchLiveSmsData() async {
    if (globalWebViewController == null) return;

    var result = await globalWebViewController?.evaluateJavascript(source: '''
      (function() {
        let stats = document.querySelectorAll('.cstat-value');
        if (stats && stats.length >= 2) {
          return {
            today: stats[0].innerText.trim(),
            week: stats[1].innerText.trim()
          };
        }
        return null;
      })();
    ''');

    if (result != null && result is Map) {
      if (mounted) {
        setState(() {
          _smsToday = result['today']?.toString() ?? "--";
          _smsThisWeek = result['week']?.toString() ?? "--";
        });
      }
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryColor =
        isDark ? const Color(0xFF00FFA3) : const Color(0xFF6C5CE7);
    final cardBg = isDark ? const Color(0xFF111420) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SMS LIVE MONITOR',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: primaryColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? const Color(0xFFFFD700) : const Color(0xFF2D3436),
            ),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // مؤشر التحديث اللحظي المباشر
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: primaryColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _animController,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "بث مباشر: تحديث كل ثانية",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // كروت القراءات
            Row(
              children: [
                Expanded(
                  child: _buildLiveCard(
                    title: "SMS TODAY",
                    value: _smsToday,
                    icon: Icons.today,
                    glowColor: const Color(0xFF00E5FF),
                    cardBg: cardBg,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildLiveCard(
                    title: "SMS THIS WEEK",
                    value: _smsThisWeek,
                    icon: Icons.date_range,
                    glowColor: const Color(0xFFFF007A),
                    cardBg: cardBg,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // زر الخروج للعودة لشاشة الدخول
            OutlinedButton.icon(
              onPressed: () {
                _liveTimer?.cancel();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(
                      onToggleTheme: widget.onToggleTheme,
                      isDark: widget.isDark,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.redAccent),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCard({
    required String title,
    required String value,
    required IconData icon,
    required Color glowColor,
    required Color cardBg,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: glowColor.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.25),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: glowColor, size: 30),
          const SizedBox(height: 15),
          Text(
            title,
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: glowColor,
            ),
          ),
        ],
      ),
    );
  }
}
