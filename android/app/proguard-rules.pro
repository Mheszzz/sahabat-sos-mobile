# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

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
