import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static bool get isLoggedIn => _auth.currentUser != null;
  static String? get uid => _auth.currentUser?.uid;
  static String? get email => _auth.currentUser?.email;

  static Future<UserCredential> signIn(
      String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// رسالة خطأ مفهومة بالعربي
  static String arError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'الإيميل ده مش مسجل';
        case 'wrong-password':
          return 'كلمة المرور غلط';
        case 'invalid-email':
          return 'الإيميل غير صحيح';
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