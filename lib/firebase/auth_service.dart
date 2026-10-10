import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static FirebaseApp? _secondaryApp;

  // ⭐ علامة الـ domain الوهمي
  static const String _domainSuffix = '@ims.app';

  static User? get currentUser => _auth.currentUser;
  static bool get isLoggedIn => _auth.currentUser != null;
  static String? get uid => _auth.currentUser?.uid;
  static String? get email => _auth.currentUser?.email;

  /// يحوّل username لـ email شكلي لـ Firebase
  static String usernameToEmail(String username) {
    final u = username.trim().toLowerCase();
    if (u.contains('@')) return u;
    return '$u$_domainSuffix';
  }

  static Future<UserCredential> signIn(
      String username, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: usernameToEmail(username),
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  // ⭐ إنشاء مستخدم جديد من داخل التطبيق (بدون الخروج من حساب الأدمن)
  static Future<String> createUser({
    required String username,
    required String password,
  }) async {
    if (_secondaryApp == null) {
      _secondaryApp = await Firebase.initializeApp(
        name: 'secondary_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
    }

    final secondaryAuth =
        FirebaseAuth.instanceFor(app: _secondaryApp!);

    try {
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: usernameToEmail(username),
        password: password,
      );
      final newUid = cred.user?.uid ?? '';
      await secondaryAuth.signOut();
      return newUid;
    } catch (e) {
      try {
        await secondaryAuth.signOut();
      } catch (_) {}
      rethrow;
    }
  }

  /// رسالة خطأ مفهومة بالعربي
  static String arError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'اسم المستخدم ده مش مسجل';
        case 'wrong-password':
          return 'كلمة المرور غلط';
        case 'invalid-email':
          return 'اسم المستخدم غير صحيح';
        case 'email-already-in-use':
          return 'اسم المستخدم ده مستخدم بالفعل';
        case 'weak-password':
          return 'كلمة المرور ضعيفة (6 حروف على الأقل)';
        case 'user-disabled':
          return 'الحساب ده متوقف';
        case 'too-many-requests':
          return 'محاولات كتير — استنى شوية';
        case 'invalid-credential':
          return 'بيانات الدخول غلط';
        case 'network-request-failed':
          return 'مشكلة في الإنترنت';
        default:
          return 'خطأ: ${e.message ?? e.code}';
      }
    }
    return 'خطأ غير متوقع: $e';
  }
}