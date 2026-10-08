import 'package:flutter/material.dart';
import 'app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ImsApp());
}

class ImsApp extends StatefulWidget {
  const ImsApp({super.key});
  @override
  State<ImsApp> createState() => _ImsAppState();
}

class _ImsAppState extends State<ImsApp> {
  ThemeMode _mode = ThemeMode.dark;

  void _toggle() => setState(
      () => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IMS',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: AppShell(
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
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);

  // ⭐ textTheme نضيف بدون underline
  final baseText = base.textTheme;
  TextStyle clean(TextStyle? s) =>
      (s ?? const TextStyle()).copyWith(decoration: TextDecoration.none);

  return base.copyWith(
    scaffoldBackgroundColor:
        b == Brightness.dark ? const Color(0xFF0B0B14) : const Color(0xFFF5F6FB),
    textTheme: baseText.copyWith(
      displayLarge: clean(baseText.displayLarge),
      displayMedium: clean(baseText.displayMedium),
      displaySmall: clean(baseText.displaySmall),
      headlineLarge: clean(baseText.headlineLarge),
      headlineMedium: clean(baseText.headlineMedium),
      headlineSmall: clean(baseText.headlineSmall),
      titleLarge: clean(baseText.titleLarge),
      titleMedium: clean(baseText.titleMedium),
      titleSmall: clean(baseText.titleSmall),
      bodyLarge: clean(baseText.bodyLarge),
      bodyMedium: clean(baseText.bodyMedium),
      bodySmall: clean(baseText.bodySmall),
      labelLarge: clean(baseText.labelLarge),
      labelMedium: clean(baseText.labelMedium),
      labelSmall: clean(baseText.labelSmall),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: b == Brightness.dark
          ? Colors.white.withOpacity(0.04)
          : Colors.black.withOpacity(0.02),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xFF2C2C3E),
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
    ),
  );
}