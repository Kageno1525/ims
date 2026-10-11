import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config.dart';
import 'firebase/auth_service.dart';
import 'firebase/firestore_service.dart';
import 'firebase/session_manager.dart';
import 'firebase/security_service.dart';
import 'firebase/device_service.dart';
import 'firebase/profile_cache.dart';
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
  bool _hwidBanned = false;
  bool _deviceMismatch = false;
  bool _verifiedOnce = false;
  bool _listeningAuth = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      // ⭐ 1) فحص HWID — مع timeout عشان ما يعلّقش
      final hwid = await DeviceService.getHwid()
          .timeout(const Duration(seconds: 3), onTimeout: () => 'unknown');

      bool banned = false;
      try {
        banned = await SecurityService.isHwidBanned(hwid)
            .timeout(const Duration(seconds: 3), onTimeout: () => false);
      } catch (_) {
        banned = false;
      }

      if (banned) {
        if (!mounted) return;
        setState(() {
          _hwidBanned = true;
          _loading = false;
        });
        return;
      }

      // ⭐ 2) اقرأ الكاش
      final cached = await ProfileCache.load()
          .timeout(const Duration(seconds: 2), onTimeout: () => null);

      final currentUser = AuthService.currentUser;

      // ⭐ 3) لو فيه كاش + مستخدم مسجّل → اعرض التطبيق فوراً
      if (cached != null &&
          currentUser != null &&
          cached.uid == currentUser.uid &&
          !cached.isBanned) {
        if (!mounted) return;
        setState(() {
          _firebaseUser = currentUser;
          _profile = cached;
          _loading = false;
        });
        // نتحقق في الخلفية
        _verifyBackground(currentUser);
        return;
      }

      // ⭐ 4) مفيش كاش → اسمع Firebase auth
      _listenAuth();

      // ⭐ 5) Safety: لو بعد 5 ثواني لسه loading → وضّح السبب
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _loading && _firebaseUser == null) {
          setState(() {
            _loading = false;
            _error = null; // هيظهر شاشة اللوجين
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'خطأ في التحميل: $e';
      });
    }
  }

  void _listenAuth() {
    if (_listeningAuth) return;
    _listeningAuth = true;
    AuthService.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (!mounted) return;

    if (user == null) {
      await ProfileCache.clear();
      if (!mounted) return;
      setState(() {
        _firebaseUser = null;
        _profile = null;
        _loading = false;
        _error = null;
        _sessionConflict = false;
        _deviceMismatch = false;
      });
      return;
    }

    setState(() {
      _firebaseUser = user;
      _loading = true;
      _error = null;
      _deviceMismatch = false;
    });

    _verifyBackground(user);
  }

  Future<void> _verifyBackground(User user) async {
    if (_verifiedOnce) return;
    _verifiedOnce = true;

    try {
      // ⭐ timeout للـ Firestore
      final profile = await FirestoreService.getUserProfile(user.uid)
          .timeout(const Duration(seconds: 6), onTimeout: () => null);

      if (!mounted) return;

      // ❌ البروفايل مش موجود → اطرد
      if (profile == null) {
        await ProfileCache.clear();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'الحساب ده مش مصرّح له';
          _firebaseUser = null;
          _profile = null;
        });
        await AuthService.signOut();
        await SessionManager.clearLocalSession();
        return;
      }

      // ❌ محظور → اطرد
      if (profile.isBanned) {
        await ProfileCache.clear();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'الحساب ده اتحظر';
          _firebaseUser = null;
          _profile = null;
        });
        await AuthService.signOut();
        await SessionManager.clearLocalSession();
        return;
      }

      // ❌ أدمن في تطبيق يوزر → سجّل + اطرد
      if (!IS_ADMIN_APP && profile.isAdmin) {
        try {
          final info = await DeviceService.getDeviceInfo()
              .timeout(const Duration(seconds: 3));
          final ip = await DeviceService.fetchIP()
              .timeout(const Duration(seconds: 3));
          await SecurityService.logSecurityEvent(
            type: 'admin_login_attempt',
            hwid: info['hwid'] ?? 'unknown',
            ip: ip,
            deviceModel: info['model'] ?? 'Unknown',
            deviceName: info['device'] ?? 'unknown',
            attemptedUsername: user.email ?? '',
            targetAccountUid: user.uid,
            targetAccountName: profile.name,
          );
        } catch (_) {}

        await ProfileCache.clear();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _deviceMismatch = true;
          _firebaseUser = null;
          _profile = null;
        });
        await AuthService.signOut();
        await SessionManager.clearLocalSession();
        return;
      }

      // ✅ تمام — حدّث الكاش والواجهة
      await ProfileCache.save(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });

      // ⭐ الجلسة والمتابعة — في الخلفية
      _sessionAndWatchers(user);
    } catch (e) {
      // لو فشل النت — نعتمد على الكاش
      final cached = await ProfileCache.load();
      if (!mounted) return;
      if (cached != null && cached.uid == user.uid) {
        setState(() {
          _profile = cached;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'خطأ في التحميل: $e';
        });
      }
    }
  }

  Future<void> _sessionAndWatchers(User user) async {
    try {
      final ok = await SessionManager.bindSession(user.uid)
          .timeout(const Duration(seconds: 5), onTimeout: () => true);
      if (!ok) {
        if (!mounted) return;
        setState(() => _sessionConflict = true);
        return;
      }

      FirestoreService.updateLastLogin(user.uid);

      _watchProfile(user.uid);
    } catch (_) {}
  }

  void _watchProfile(String uid) {
    FirestoreService.userProfileStream(uid).listen((profile) {
      if (!mounted || profile == null) return;

      if (profile.isBanned) {
        ProfileCache.clear();
        _forceLogout(message: 'الحساب ده اتحظر');
        return;
      }

      if (!IS_ADMIN_APP && profile.isAdmin) {
        ProfileCache.clear();
        _forceLogout(message: 'ده حساب أدمن — مينفعش يدخل من هنا');
        return;
      }

      ProfileCache.save(profile);
      setState(() => _profile = profile);
    });

    SessionManager.watchSessionConflict(uid).listen((conflict) {
      if (!mounted) return;
      if (conflict && !_sessionConflict) {
        setState(() => _sessionConflict = true);
      }
    });
  }

  Future<void> _forceLogout({String? message}) async {
    final uid = AuthService.uid;
    try {
      if (uid != null) await FirestoreService.clearSession(uid);
    } catch (_) {}
    await ProfileCache.clear();
    try {
      await AuthService.signOut();
    } catch (_) {}
    try {
      await SessionManager.clearLocalSession();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _loading = false; // ⭐⭐ الإصلاح المهم
      _sessionConflict = false;
      _error = message;
      _profile = null;
      _firebaseUser = null;
      _deviceMismatch = false;
    });
  }

  Future<void> _forceLogoutManual() async {
    _verifiedOnce = false;
    await _forceLogout();
    if (mounted) {
      setState(() => _error = null);
      // أعد تشغيل الـ listener
      _listenAuth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_hwidBanned) return _blockedScreen(theme);

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

    if (_firebaseUser == null) {
      if (_error != null) return _errorScreen(theme, _error!);
      return FirebaseLoginPage(
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
      );
    }

    if (_deviceMismatch) return _mismatchScreen(theme);

    if (_error != null && _profile == null) {
      return _errorScreen(theme, _error!);
    }

    if (_sessionConflict) return _conflictScreen(theme);

    if (_profile != null) {
      return AppShell(
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
        userProfile: _profile!,
      );
    }

    // لو المستخدم لسه موجود لكن مفيش بروفايل — يروح للوجين
    return FirebaseLoginPage(
      isDark: widget.isDark,
      onToggleTheme: widget.onToggleTheme,
    );
  }

  Widget _blockedScreen(ThemeData theme) {
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
                  color: const Color(0xFFFF6B6B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFF6B6B).withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.gpp_bad_rounded,
                    size: 70, color: Color(0xFFFF6B6B)),
              ),
              const SizedBox(height: 24),
              Text(
                '🚫 جهازك محظور',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'الجهاز ده اتحظر من استخدام التطبيق.\n'
                'لو ده حصل بالغلط، كلم المسؤول.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mismatchScreen(ThemeData theme) {
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
                  color: const Color(0xFFFFB84D).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFFB84D).withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.security_rounded,
                    size: 70, color: Color(0xFFFFB84D)),
              ),
              const SizedBox(height: 24),
              Text(
                '⚠️ مش مسموح',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'التطبيق ده للمستخدمين بس.\n'
                'مينفعش تسجّل دخول بحساب أدمن من هنا.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'تم إرسال إشعار للمسؤول',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFFFFB84D),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              ActionBtn(
                label: 'رجوع',
                icon: Icons.arrow_back_rounded,
                gradient: const [Color(0xFFFFB84D), Color(0xFFFF8E53)],
                busy: false,
                onTap: () async {
                  await _forceLogoutManual();
                  if (mounted) {
                    setState(() => _deviceMismatch = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
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
                      color: theme.colorScheme.error.withOpacity(0.4)),
                ),
                child: Icon(Icons.block_rounded,
                    size: 60, color: theme.colorScheme.error),
              ),
              const SizedBox(height: 24),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 32),
              ActionBtn(
                label: 'رجوع لتسجيل الدخول',
                icon: Icons.logout_rounded,
                gradient: const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                busy: false,
                onTap: _forceLogoutManual,
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
                      color: const Color(0xFFFFB84D).withOpacity(0.4)),
                ),
                child: const Icon(Icons.devices_rounded,
                    size: 60, color: Color(0xFFFFB84D)),
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
                onTap: _forceLogoutManual,
              ),
            ],
          ),
        ),
      ),
    );
  }
}