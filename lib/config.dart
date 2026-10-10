// lib/config.dart
// ⭐ فلاج يحدد إذا كان التطبيق Admin أو User
// بيتحدد من الـ build command:
//   flutter build apk --dart-define=IS_ADMIN=true   → Admin
//   flutter build apk --dart-define=IS_ADMIN=false  → User
const bool IS_ADMIN_APP = bool.fromEnvironment(
  'IS_ADMIN',
  defaultValue: true,
);