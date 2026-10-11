# ══════════════════════════════════════════════
# Kageno IMS — ProGuard Rules
# ══════════════════════════════════════════════

# ─── Flutter ───
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Firebase ───
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ─── Device Info Plus ───
-keep class com.jeep.** { *; }
-keep class com.jeep.plugin.** { *; }

# ─── Shared Preferences ───
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ─── Path Provider ───
-keep class io.flutter.plugins.pathprovider.** { *; }

# ─── InAppWebView ───
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-dontwarn com.pichillilorenzo.flutter_inappwebview.**

# ─── HTTP ───
-keep class org.apache.http.** { *; }
-dontwarn org.apache.http.**
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**

# ─── Kotlin ───
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# ─── App Classes (ImsAccessibilityService etc) ───
-keep class com.kageno.ims.** { *; }

# ⭐⭐⭐ Anti-Debug & Anti-Tamper ⭐⭐⭐
# منع عرض أسماء الملفات والدوال
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# إخفاء الأسماء
-repackageclasses ''
-allowaccessmodification

# حذف الـ logs في release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# منع الوصول لـ BuildConfig المكشوف
-assumenosideeffects class com.kageno.ims.BuildConfig {
    public static *** DEBUG;
}

# ══════════════════════════════════════════════
# نهاية القواعد
# ══════════════════════════════════════════════