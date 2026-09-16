package com.example.sahabat_sos_mobile

import android.app.Application
import android.util.Log

// import com.thingclips.smart.home.sdk.ThingHomeSdk

class TuyaSosApplication : Application() {

    companion object {
        private const val TAG = "TuyaSosApp"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Application onCreate - Tuya SDK temporarily disabled")
        // initTuyaSdk()
    }

    private fun initTuyaSdk() {
        try {
            // Menggunakan key dari Tuya Developer Platform
            // ThingHomeSdk.init(this, "95k43ts8vrgputwxr53f", "m8rwvtwpmfcfmvxndwlxxa9mhh8k8pxj")
            // ThingHomeSdk.setDebugMode(true)
            // ThingHomeSdk.setOnNeedLoginListener {
            //     Log.w(TAG, "Tuya session expired, need re-login")
            // }
            Log.d(TAG, "Tuya SDK initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Tuya SDK: ${e.message}", e)
        }
    }
}
