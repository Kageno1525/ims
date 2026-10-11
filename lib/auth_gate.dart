import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase/auth_service.dart';
import 'firebase/firestore_service.dart';
import 'firebase/session_manager.dart';
import 'models.dart';
import 'pages/firebase_login_page.dart';
import 'app_shell.dart';
import 'widgets.dart';

class AuthGate extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const AuthGate({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? _firebaseUser;
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  bool _sessionConflict = false;

  @override
  void initState() {
    super.initState();
    // نسمع تغيّر الـ auth state — أول ما يفتح التطبيق
    AuthService.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (!mounted) return;

    // لو مفيش مستخدم → روح لشاشة اللوجين
    if (user == null) {
      setState(() {
        _firebaseUser = null;
        _profile = null;
        _loading = false;
        _error = null;
        _sessionConflict = false;
      });
      return;
    }

    // فيه مستخدم → اجيب البروفايل من Firestore
    setState(() {
      _firebaseUser = user;
      _loading = true;
      _error = null;
    });

    try {
      final profile = await FirestoreService.getUserProfile(user.uid);

      // لو البروفايل مش موجود → المستخدم مش مصرح له
      if (profile == null) {
        await AuthService.signOut();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'الحساب ده مش مصرّح له';
        });
        return;
      }

      // اتحظر؟
      if (profile.isBanned) {
        await AuthService.signOut();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'الحساب ده اتحظر';
        });
        return;
      }

      // ── فحص الجهاز الواحد ──
      final ok = await SessionManager.bindSession(user.uid);
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _sessionConflict = true;
          _profile = profile;
        });
        return;
      }

      // حدّث آخر دخول
      FirestoreService.updateLastLogin(user.uid);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
        _sessionConflict = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'خطأ في تحميل البيانات: $e';
      });
    }
  }

  Future<void> _forceLogout() async {
    final uid = AuthService.uid;
    if (uid != null) {
      await FirestoreService.clearSession(uid);
    }
    await AuthService.signOut();
    await SessionManager.clearLocalSession();
    if (mounted) {
      setState(() {
        _sessionConflict = false;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 1) جاري التحميل
    if (_loading) {
      return AnimatedBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF6C5CE7),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'جاري التحميل…',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2) مش مسجل دخول → شاشة اللوجين
    if (_firebaseUser == null) {
      return FirebaseLoginPage(
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
      );
    }

    // 3) فيه خطأ (حظر / مش مصرح)
    if (_error != null && _profile == null) {
      return _errorScreen(theme, _error!);
    }

    // 4) تضارب جلسة (فتح من جهاز تاني)
    if (_sessionConflict) {
      return _conflictScreen(theme);
    }

    // 5) البروفايل جاهز → التطبيق شغال
    if (_profile != null) {
      return AppShell(
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
        userProfile: _profile!,
      );
    }

    // fallback
    return FirebaseLoginPage(
      isDark: widget.isDark,
      onToggleTheme: widget.onToggleTheme,
    );
  }

  Widget _errorScreen(ThemeData theme, String msg) {
    return AnimatedBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.4),
                  ),
                ),
                child: Icon(
                  Icons.block_rounded,
                  size: 60,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 32),
              ActionBtn(
                label: 'تسجيل خروج',
                icon: Icons.logout_rounded,
                gradient: const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                busy: false,
                onTap: _forceLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conflictScreen(ThemeData theme) {
    return AnimatedBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB84D).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFFB84D).withOpacity(0.4),
                  ),
                ),
                child: const Icon(
                  Icons.devices_rounded,
                  size: 60,
                  color: Color(0xFFFFB84D),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'الحساب ده مفتوح على جهاز تاني',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'مسموح بجهاز واحد فقط في نفس الوقت',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
              ActionBtn(
                label: 'تسجيل خروج',
                icon: Icons.logout_rounded,
                gradient: const [Color(0xFFFFB84D), Color(0xFFFF8E53)],
                busy: false,
                onTap: _forceLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}