package com.sossahabat.app

import android.app.Application
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
            // Initialize using AppKey/AppSecret from Tuya Developer Platform
            // (Get Key tab: https://iot.tuya.com)
            ThingHomeSdk.init(this, "v7jujdvxvrn55hvvqwyu", "84keu3y8erwku9rs9adnae595cvtsruv")
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
