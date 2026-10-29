# App classes
-keep class com.sossahabat.app.** { *; }
-keep class com.sossahabatsos.app.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Background Service
-keep class id.flutter.flutter_background_service.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Health Connect
-keep class cachet.plugins.health.** { *; }
-keep class androidx.health.** { *; }

# Flutter Blue Plus
-keep class com.lib.flutter_blue_plus.** { *; }

# Audio & Media
-keep class xyz.luan.audioplayers.** { *; }
-keep class com.llfbandit.record.** { *; }

# Google Sign In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Dio/OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# ThingClips Smart SDK (Tuya)
-keep class com.alibaba.fastjson.**{*;}
-dontwarn com.alibaba.fastjson.**
-keep class com.thingclips.smart.mqttclient.mqttv3.** { *; }
-dontwarn com.thingclips.smart.mqttclient.mqttv3.**
-keep class com.thingclips.**{*;}
-dontwarn com.thingclips.**
-dontwarn com.facebook.soloader.**
-dontwarn com.google.android.play.**
-dontwarn com.google.gson.**
-keep class chip.** { *; }
-dontwarn chip.**
-keep class com.gzl.smart.** { *; }
-dontwarn com.gzl.smart.**
