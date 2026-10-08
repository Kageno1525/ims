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
      // الثيم الفاتح
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFA5F8F6),
        primaryColor: const Color(0xFF6C5CE7),
        cardColor: Colors.white,
        fontFamily: GoogleFonts.cairo().fontFamily,
      ),
      // الثيم الغامق الفاجر (Dark Neon Glass)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090A0F),
        primaryColor: const Color(0xFF00FFA3),
        cardColor: const Color(0xFF12151E),
        fontFamily: GoogleFonts.cairo().fontFamily,
      ),
      home: DashboardScreen(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const DashboardScreen({
    Key? key,
    required onToggleTheme,
    required isDark,
  })  : onToggleTheme = onToggleTheme,
        isDark = isDark,
        super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  InAppWebViewController? _webViewController;

  // Controllers للتحكم في الإدخال
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  // القراءات المفتوحة
  String _smsToday = "0";
  String _smsThisWeek = "0";
  bool _isLoading = false;
  String _statusMessage = "جاهز للبدء...";

  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.05).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // 1️⃣ تسجيل الدخول التلقائي باستعمال الـ Selectors الدقيقة
  Future<void> _executeAutoLogin() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) {
      _showSnackBar("اكتب اسم المستخدم والباسورد الأول يا كاجينو!");
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "جاري تسجيل الدخول تلقائياً...";
    });

    final String username = _userController.text.trim();
    final String password = _passController.text.trim();

    // كود السكريبت المحقون لتعبئة البيانات بالظبط في الحقول وضغط الزرار
    await _webViewController?.evaluateJavascript(source: '''
      (function() {
        let userInput = document.querySelector('#app > div > form > div.login-body.classic-body > div:nth-child(3) > input[type=text]');
        let passInput = document.querySelector('#app > div > form > div.login-body.classic-body > div.pill-input.has-reveal > input[type=password]');
        let submitBtn = document.querySelector('#app > div > form > div.login-body.classic-body > button');

        if (userInput && passInput) {
          userInput.value = '$username';
          passInput.value = '$password';

          // تحفيز الأحداث لـ Vue.js
          userInput.dispatchEvent(new Event('input', { bubbles: true }));
          passInput.dispatchEvent(new Event('input', { bubbles: true }));

          if (submitBtn) {
            setTimeout(() => { submitBtn.click(); }, 300);
          }
        }
      })();
    ''');

    // انتظار التحميل ثم قراءة البيانات أوتوماتيكياً
    await Future.delayed(const Duration(seconds: 4));
    await _readSmsData();
  }

  // 2️⃣ قراءة البيانات (SMS Today & SMS This Week)
  Future<void> _readSmsData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "جاري سحب القراءات...";
    });

    var result = await _webViewController?.evaluateJavascript(source: '''
      (function() {
        let stats = document.querySelectorAll('.cstat-value');
        if (stats.length >= 2) {
          return {
            today: stats[0].innerText.trim(),
            week: stats[1].innerText.trim()
          };
        } else if (stats.length === 1) {
          return {
            today: stats[0].innerText.trim(),
            week: "N/A"
          };
        }
        return { today: "0", week: "0" };
      })();
    ''');

    setState(() {
      _isLoading = false;
      if (result != null && result is Map) {
        _smsToday = result['today']?.toString() ?? "0";
        _smsThisWeek = result['week']?.toString() ?? "0";
        _statusMessage = "تم تحديث البيانات بنجاح 🔥";
      } else {
        _statusMessage = "لم يتم العثور على القراءات، تأكد من تسجيل الدخول.";
      }
    });
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
    final primaryColor = isDark ? const Color(0xFF00FFA3) : const Color(0xFF6C5CE7);
    final cardBg = isDark ? const Color(0xFF121520) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'IMSSMS AUTOMATOR',
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
          // 🌗 زرار الثيم الغامق والفاتح بأنيميشن
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                key: ValueKey<bool>(isDark),
                color: isDark ? const Color(0xFFFFD700) : const Color(0xFF2D3436),
              ),
            ),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView شغال خفي خلف الكواليس
          SizedBox(
            height: 1,
            width: 1,
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://imssms.org/login'),
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStop: (controller, url) {
                setState(() {
                  _statusMessage = "الصفحة جاهزة لتسجيل الدخول";
                });
              },
            ),
          ),

          // واجهة المستخدم
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // كارت الحالة
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isLoading ? Icons.sync : Icons.check_circle_outline,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // 🌟 كروت العرض الفاجرة (SMS Stats)
                Row(
                  children: [
                    Expanded(
                      child: ScaleTransition(
                        scale: _pulseAnimation,
                        child: _buildStatCard(
                          title: "SMS TODAY",
                          value: _smsToday,
                          icon: Icons.today,
                          color: const Color(0xFF00E5FF),
                          cardBg: cardBg,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ScaleTransition(
                        scale: _pulseAnimation,
                        child: _buildStatCard(
                          title: "SMS THIS WEEK",
                          value: _smsThisWeek,
                          icon: Icons.date_range,
                          color: const Color(0xFFFF007A),
                          cardBg: cardBg,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // فورس تسجيل الدخول
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                    border: Border.all(
                      color: primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _userController,
                        label: 'اسم المستخدم / الإيميل',
                        icon: Icons.person_outline,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: _passController,
                        label: 'كلمة المرور',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 25),

                      // زرار الدخول الفاجر
                      ElevatedButton(
                        onPressed: _isLoading ? null : _executeAutoLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 10,
                          shadowColor: primaryColor.withOpacity(0.5),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.black)
                            : const Text(
                                'تسجيل دخول وتحديث',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // زرار سحب القراءات يدوياً
                OutlinedButton.icon(
                  onPressed: _readSmsData,
                  icon: Icon(Icons.refresh, color: primaryColor),
                  label: Text(
                    'قراءة البيانات الآن',
                    style: TextStyle(color: primaryColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // كود تشكيل الكروت والإدخالات
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color primaryColor,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1D2B) : const Color(0xFFF1F2F6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
}
