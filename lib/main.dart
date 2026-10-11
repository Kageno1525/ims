import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config.dart';
import 'auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ تهيئة Firebase بالتوازي مع بدء التطبيق
  await Firebase.initializeApp(
    options: Firebase.app().options,
  ).catchError((_) => Firebase.app());

  runApp(const ImsApp());
}

class ImsApp extends StatefulWidget {
  const ImsApp({super.key});
  @override
  State<ImsApp> createState() => _ImsAppState();
}

class _ImsAppState extends State<ImsApp> {
  ThemeMode _mode = ThemeMode.dark;

  void _toggle() => setState(() =>
      _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: IS_ADMIN_APP ? 'IMS Admin' : 'IMS',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      builder: (context, child) {
        return DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
            decorationStyle: TextDecorationStyle.solid,
          ),
          child: child!,
        );
      },
      home: AuthGate(
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

  final cleanTextTheme = base.textTheme.apply(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  return base.copyWith(
    scaffoldBackgroundColor:
        b == Brightness.dark ? const Color(0xFF0B0B14) : const Color(0xFFF5F6FB),
    textTheme: cleanTextTheme,
    primaryTextTheme: cleanTextTheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: b == Brightness.dark
          ? Colors.white.withOpacity(0.04)
          : Colors.black.withOpacity(0.02),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: scheme.primary.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      labelStyle: TextStyle(
          color: scheme.onSurface.withOpacity(0.6),
          decoration: TextDecoration.none,
          decorationColor: Colors.transparent),
      hintStyle: TextStyle(
          color: scheme.onSurface.withOpacity(0.4),
          decoration: TextDecoration.none,
          decorationColor: Colors.transparent),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xFF2C2C3E),
      contentTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 14,
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      ),
    ),
  );
}