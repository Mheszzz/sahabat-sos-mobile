package com.example.sahabat_sos_mobile

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "TuyaMainActivity"
        private const val METHOD_CHANNEL = "com.sahabatsos.app/tuya_method"
        private const val EVENT_CHANNEL = "com.sahabatsos.app/tuya_events"
    }

    private var eventSink: EventChannel.EventSink? = null

    // Placeholder: Tuya device listener reference
    // private var tuyaDevice: ITuyaDevice? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupMethodChannel(flutterEngine)
        setupEventChannel(flutterEngine)
    }

    private fun setupMethodChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initTuya" -> {
                        Log.d(TAG, "initTuya called from Flutter")
                        // TODO: Initialize Tuya SDK if not already done
                        result.success(mapOf("status" to "initialized", "message" to "Tuya SDK placeholder ready"))
                    }

                    "loginAnonymous" -> {
                        val uid = call.argument<String>("uid") ?: ""
                        Log.d(TAG, "loginAnonymous called with uid: $uid")
                        // TODO: Implement Tuya anonymous login
                        // TuyaHomeSdk.getUserInstance().loginOrRegisterWithUid(
                        //     "86", uid, "password_hash",
                        //     object : ILoginCallback { ... }
                        // )
                        result.success(mapOf("status" to "logged_in", "uid" to uid))
                    }

                    "startBLEScan" -> {
                        Log.d(TAG, "startBLEScan called")
                        // TODO: Implement BLE scanning
                        // TuyaHomeSdk.getBleManager().startBLEScan(...)
                        result.success(mapOf("status" to "scanning"))
                    }

                    "stopBLEScan" -> {
                        Log.d(TAG, "stopBLEScan called")
                        // TODO: Stop BLE scanning
                        result.success(mapOf("status" to "stopped"))
                    }

                    "pairDevice" -> {
                        val deviceInfo = call.argument<String>("deviceInfo") ?: ""
                        Log.d(TAG, "pairDevice called with: $deviceInfo")
                        // TODO: Implement device pairing
                        result.success(mapOf("status" to "paired", "device_id" to "tuya_placeholder_id"))
                    }

                    "getDeviceList" -> {
                        Log.d(TAG, "getDeviceList called")
                        // TODO: Get device list from Tuya SDK
                        // val home = TuyaHomeSdk.getHomeManagerInstance()
                        result.success(listOf<Map<String, Any>>())
                    }

                    "listenDevice" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        Log.d(TAG, "listenDevice called for: $deviceId")
                        startDeviceListener(deviceId)
                        result.success(mapOf("status" to "listening", "device_id" to deviceId))
                    }

                    "stopListenDevice" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        Log.d(TAG, "stopListenDevice called for: $deviceId")
                        stopDeviceListener()
                        result.success(mapOf("status" to "stopped"))
                    }

                    "simulateSosEvent" -> {
                        val deviceId = call.argument<String>("deviceId") ?: "sim_device_001"
                        Log.d(TAG, "simulateSosEvent called for: $deviceId")
                        simulateSosEvent(deviceId)
                        result.success(mapOf("status" to "simulated"))
                    }

                    "getDeviceStatus" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        Log.d(TAG, "getDeviceStatus called for: $deviceId")
                        // TODO: Get real device status from Tuya SDK
                        result.success(mapOf(
                            "device_id" to deviceId,
                            "is_online" to true,
                            "battery" to 88,
                            "signal_strength" to "strong"
                        ))
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun setupEventChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.d(TAG, "EventChannel: Flutter started listening")
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    Log.d(TAG, "EventChannel: Flutter stopped listening")
                    eventSink = null
                }
            })
    }

    private fun startDeviceListener(deviceId: String) {
        Log.d(TAG, "Starting device listener for: $deviceId")
        // TODO: When Tuya SDK is configured, implement real listener:
        // tuyaDevice = TuyaHomeSdk.newDeviceInstance(deviceId)
        // tuyaDevice?.registerDevListener(object : IDevListener {
        //     override fun onDpUpdate(devId: String?, dpStr: String?) {
        //         Log.d(TAG, "DP Update from $devId: $dpStr")
        //         val eventData = JSONObject().apply {
        //             put("device_id", devId)
        //             put("dps", dpStr)
        //             put("timestamp", System.currentTimeMillis())
        //             put("type", "dp_update")
        //         }
        //         runOnUiThread {
        //             eventSink?.success(eventData.toString())
        //         }
        //     }
        //     override fun onRemoved(devId: String?) {
        //         val eventData = JSONObject().apply {
        //             put("device_id", devId)
        //             put("type", "device_removed")
        //             put("timestamp", System.currentTimeMillis())
        //         }
        //         runOnUiThread { eventSink?.success(eventData.toString()) }
        //     }
        //     override fun onStatusChanged(devId: String?, online: Boolean) {
        //         val eventData = JSONObject().apply {
        //             put("device_id", devId)
        //             put("type", "status_changed")
        //             put("is_online", online)
        //             put("timestamp", System.currentTimeMillis())
        //         }
        //         runOnUiThread { eventSink?.success(eventData.toString()) }
        //     }
        //     override fun onNetworkStatusChanged(devId: String?, status: Boolean) {}
        // })
    }

    private fun stopDeviceListener() {
        // tuyaDevice?.unRegisterDevListener()
        // tuyaDevice?.onDestroy()
        // tuyaDevice = null
        Log.d(TAG, "Device listener stopped")
    }

    /**
     * Simulate an SOS event for testing purposes.
     * This sends a fake DP update through the EventChannel
     * to test the Flutter -> Laravel -> Admin Dashboard flow
     * without needing physical Tuya hardware.
     */
    private fun simulateSosEvent(deviceId: String) {
        val simulatedDp = JSONObject().apply {
            put("device_id", deviceId)
            put("dps", JSONObject().apply {
                put("1", true)  // Standard Tuya SOS DP
                put("sos_state", "alarm")
            }.toString())
            put("timestamp", System.currentTimeMillis())
            put("type", "dp_update")
            put("is_simulation", true)
        }
        Log.d(TAG, "Sending simulated SOS event: $simulatedDp")
        runOnUiThread {
            eventSink?.success(simulatedDp.toString())
        }
    }

    override fun onDestroy() {
        stopDeviceListener()
        super.onDestroy()
    }
}
