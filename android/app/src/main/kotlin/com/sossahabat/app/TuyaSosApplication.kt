package com.sossahabat.app

import android.app.Application
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log

import com.thingclips.smart.home.sdk.ThingHomeSdk

class TuyaSosApplication : Application() {

    companion object {
        private const val TAG = "TuyaSosApp"
    }

    override fun onCreate() {
        super.onCreate()
        initTuyaSdk()
    }

    private fun initTuyaSdk() {
        try {
            val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong())
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            }

            val appKey = appInfo.metaData?.getString("THING_SMART_APPKEY")?.trim() ?: ""
            val appSecret = appInfo.metaData?.getString("THING_SMART_SECRET")?.trim() ?: ""

            if (appKey.isEmpty() || appSecret.isEmpty()) {
                Log.w(TAG, "Tuya AppKey or AppSecret is not configured. ThingHomeSdk init skipped.")
                return
            }

            // Initialize using AppKey/AppSecret injected from secure config
            ThingHomeSdk.init(this, appKey, appSecret)
            ThingHomeSdk.setDebugMode(true)
            ThingHomeSdk.setOnNeedLoginListener {
                Log.w(TAG, "Tuya session expired, need re-login")
            }
            Log.d(TAG, "Tuya SDK initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Tuya SDK: ${e.message}", e)
        }
    }
}
