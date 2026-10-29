package com.sossahabat.app

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.facebook.soloader.SoLoader
import com.thingclips.smart.home.sdk.ThingHomeSdk
import io.flutter.app.FlutterApplication

open class TuyaSosApplication : FlutterApplication() {

    companion object {
        private const val TAG = "TuyaSosApp"
        private var isInitialized = false

        fun initTuyaSdk(context: Context) {
            if (isInitialized) return
            try {
                try {
                    SoLoader.init(context, false)
                } catch (t: Throwable) {
                    Log.w(TAG, "SoLoader init warning: ${t.message}")
                }

                val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    context.packageManager.getApplicationInfo(
                        context.packageName,
                        PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong())
                    )
                } else {
                    @Suppress("DEPRECATION")
                    context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
                }

                val appKey = appInfo.metaData?.getString("THING_SMART_APPKEY")?.trim() ?: ""
                val appSecret = appInfo.metaData?.getString("THING_SMART_SECRET")?.trim() ?: ""

                if (appKey.isEmpty() || appSecret.isEmpty()) {
                    Log.w(TAG, "Tuya AppKey or AppSecret is not configured. ThingHomeSdk init skipped.")
                    return
                }

                val app = context.applicationContext as? android.app.Application ?: return
                ThingHomeSdk.init(app, appKey, appSecret)
                ThingHomeSdk.setDebugMode(false)
                ThingHomeSdk.setOnNeedLoginListener {
                    Log.w(TAG, "Tuya session expired, need re-login")
                }
                isInitialized = true
                Log.d(TAG, "Tuya SDK initialized successfully")
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to initialize Tuya SDK safely: ${t.message}", t)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        try {
            SoLoader.init(this, false)
        } catch (t: Throwable) {
            Log.w(TAG, "SoLoader init in onCreate: ${t.message}")
        }
        try {
            initTuyaSdk(this)
        } catch (t: Throwable) {
            Log.e(TAG, "Tuya SDK init in onCreate: ${t.message}", t)
        }
    }
}
