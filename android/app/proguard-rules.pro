# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Sign In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Dio/OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# Tuya Smart SDK
-keep class com.tuya.** { *; }
-dontwarn com.tuya.**
-keep class com.tuyasmart.** { *; }
-dontwarn com.tuyasmart.**
