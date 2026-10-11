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

  @override
  void initState() {
    super.initState();
    _fastStart();
  }

  // ⭐⭐ تشغيل سريع — الكاش الأول
  Future<void> _fastStart() async {
    // 1) اقرأ الكاش والـ HWID بالتوازي
    final results = await Future.wait([
      ProfileCache.load(),
      DeviceService.getHwid(),
      SecurityService.isHwidBanned(await DeviceService.getHwid()),
    ]);

    final cached = results[0] as UserProfile?;
    final hwidBanned = results[2] as bool;

    // الجهاز محظور → وقف فوراً
    if (hwidBanned) {
      if (mounted) {
        setState(() {
          _hwidBanned = true;
          _loading = false;
        });
      }
      return;
    }

    // لو فيه كاش ومستخدم مسجّل
    final currentUser = AuthService.currentUser;
    if (cached != null &&
        currentUser != null &&
        cached.uid == currentUser.uid &&
        !cached.isBanned) {
      // ⭐⭐⭐ نعرض التطبيق فوراً — بدون انتظار
      if (mounted) {
        setState(() {
          _firebaseUser = currentUser;
          _profile = cached;
          _loading = false;
        });
      }
      // نكمل التحقق في الخلفية
      _verifyInBackground(currentUser);
      return;
    }

    // مفيش كاش — استنى Firebase auth state
    AuthService.authStateChanges().listen(_onAuthChanged);
  }

  // ⭐ التحقق من الخادم في الخلفية — بدون حجب الواجهة
  Future<void> _verifyInBackground(User user) async {
    if (_verifiedOnce) return;
    _verifiedOnce = true;

    try {
      final profile = await FirestoreService.getUserProfile(user.uid);
      if (!mounted) return;

      // ⚠️ المستخدم اتحظر على الخادم — اطرده
      if (profile == null || profile.isBanned) {
        await ProfileCache.clear();
        _forceLogout(
          message: profile == null
              ? 'الحساب ده مش مصرّح له'
              : 'الحساب ده اتحظر',
        );
        return;
      }

      // ⚠️ حساب أدمن في تطبيق يوزر
      if (!IS_ADMIN_APP && profile.isAdmin) {
        final info = await DeviceService.getDeviceInfo();
        final ip = await DeviceService.fetchIP();
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
        await ProfileCache.clear();
        await AuthService.signOut();
        await SessionManager.clearLocalSession();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _deviceMismatch = true;
          _profile = null;
          _firebaseUser = null;
        });
        return;
      }

      // ⭐ حدّث الكاش والواجهة
      await ProfileCache.save(profile);
      if (!mounted) return;
      setState(() => _profile = profile);

      // ⭐ الجلسة والاتصال بالخادم — في الخلفية
      _sessionAndWatchers(user, profile);
    } catch (e) {
      // لو فشل النت — نسيب الكاش يعمل
    }
  }

  // ⭐ الجلسة والمتابعة
  Future<void> _sessionAndWatchers(User user, UserProfile profile) async {
    try {
      // ربط الجلسة
      final ok = await SessionManager.bindSession(user.uid);
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _sessionConflict = true;
          _profile = profile;
        });
        return;
      }

      // آخر دخول (fire & forget)
      FirestoreService.updateLastLogin(user.uid);

      // راقب البروفايل
      _watchProfile(user.uid);
    } catch (_) {}
  }

  // ⭐ لليوزر اللي عنده كاش — نشوف الـ auth state برضه
  Future<void> _onAuthChanged(User? user) async {
    if (!mounted) return;

    if (user == null) {
      await ProfileCache.clear();
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

    _verifyInBackground(user);
  }

  // ⭐ متابعة البروفايل — للطرد الفوري عند الحظر
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

      // ⭐ حدّث الكاش والواجهة
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
    if (uid != null) {
      await FirestoreService.clearSession(uid);
    }
    await ProfileCache.clear();
    await AuthService.signOut();
    await SessionManager.clearLocalSession();
    if (!mounted) return;
    setState(() {
      _sessionConflict = false;
      _error = message;
      _profile = null;
      _firebaseUser = null;
      _deviceMismatch = false;
    });
  }

  Future<void> _forceLogoutManual() async {
    final uid = AuthService.uid;
    if (uid != null) {
      await FirestoreService.clearSession(uid);
    }
    await ProfileCache.clear();
    await AuthService.signOut();
    await SessionManager.clearLocalSession();
    if (mounted) {
      setState(() {
        _sessionConflict = false;
        _error = null;
        _deviceMismatch = false;
      });
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
                label: 'تسجيل خروج',
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