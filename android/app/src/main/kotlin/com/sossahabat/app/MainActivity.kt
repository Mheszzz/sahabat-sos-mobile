package com.sossahabat.app

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.json.JSONArray

import com.thingclips.smart.home.sdk.ThingHomeSdk
import com.thingclips.smart.home.sdk.bean.HomeBean
import com.thingclips.smart.home.sdk.callback.IThingHomeResultCallback
import com.thingclips.smart.home.sdk.api.IThingHome
import com.thingclips.smart.sdk.api.IDevListener
import com.thingclips.smart.sdk.api.IThingDevice
import com.thingclips.smart.sdk.api.IResultCallback
import com.thingclips.smart.sdk.bean.DeviceBean
import com.thingclips.smart.home.sdk.callback.IThingGetHomeListCallback

// BLE scanning imports
import com.thingclips.smart.sdk.api.IThingActivator
import com.thingclips.smart.android.ble.api.ScanType
import com.thingclips.smart.android.ble.api.LeScanSetting

// User login
import com.thingclips.smart.android.user.api.ILoginCallback
import com.thingclips.smart.android.user.bean.User
import com.thingclips.smart.android.ble.api.ScanDeviceBean

// Wi-Fi Activator imports
import com.thingclips.smart.sdk.api.IThingActivatorGetToken
import com.thingclips.smart.sdk.api.IThingSmartActivatorListener
import com.thingclips.smart.home.sdk.builder.ActivatorBuilder
import com.thingclips.smart.sdk.enums.ActivatorModelEnum

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "TuyaMainActivity"
        private const val METHOD_CHANNEL = "com.sahabatsos.app/tuya_method"
        private const val EVENT_CHANNEL = "com.sahabatsos.app/tuya_events"
    }

    private var eventSink: EventChannel.EventSink? = null

    // Active device listeners keyed by deviceId
    private val deviceListeners = mutableMapOf<String, IThingDevice>()

    // Current home ID (required by Tuya for device management)
    private var currentHomeId: Long = -1L

    // Track discovered BLE devices for pairing
    private val discoveredBleDevices = mutableMapOf<String, ScanDeviceBean>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupMethodChannel(flutterEngine)
        setupEventChannel(flutterEngine)
    }

    private fun setupMethodChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initTuya" -> handleInitTuya(result)
                    "loginAnonymous" -> {
                        val uid = call.argument<String>("uid") ?: ""
                        handleLoginAnonymous(uid, result)
                    }
                    "startWifiPairing" -> {
                        val ssid = call.argument<String>("ssid") ?: ""
                        val password = call.argument<String>("password") ?: ""
                        handleStartWifiPairing(ssid, password, result)
                    }
                    "startWifiPairingAP" -> {
                        val ssid = call.argument<String>("ssid") ?: ""
                        val password = call.argument<String>("password") ?: ""
                        handleStartWifiPairingWithMode(ssid, password, "ap", result)
                    }
                    "getWifiToken" -> handleGetWifiToken(result)
                    "startApPairingWithToken" -> {
                        val ssid = call.argument<String>("ssid") ?: ""
                        val password = call.argument<String>("password") ?: ""
                        val token = call.argument<String>("token") ?: ""
                        handleStartApPairingWithToken(ssid, password, token, result)
                    }
                    "stopWifiPairing" -> handleStopWifiPairing(result)
                    "startBLEScan" -> handleStartBLEScan(result)
                    "stopBLEScan" -> handleStopBLEScan(result)
                    "pairDevice" -> {
                        val deviceInfo = call.argument<String>("deviceInfo") ?: ""
                        handlePairDevice(deviceInfo, result)
                    }
                    "getDeviceList" -> handleGetDeviceList(result)
                    "listenDevice" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        handleListenDevice(deviceId, result)
                    }
                    "stopListenDevice" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        handleStopListenDevice(deviceId, result)
                    }
                    "removeDevice" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        handleRemoveDevice(deviceId, result)
                    }
                    "getDeviceStatus" -> {
                        val deviceId = call.argument<String>("deviceId") ?: ""
                        handleGetDeviceStatus(deviceId, result)
                    }
                    "simulateSosEvent" -> {
                        val deviceId = call.argument<String>("deviceId") ?: "sim_device_001"
                        simulateSosEvent(deviceId)
                        result.success(mapOf("status" to "simulated"))
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

    // ========================================================================
    // initTuya - Verify SDK is initialized
    // ========================================================================
    private fun handleInitTuya(result: MethodChannel.Result) {
        Log.d(TAG, "initTuya called from Flutter")
        try {
            result.success(mapOf(
                "status" to "initialized",
                "message" to "Tuya SDK is ready"
            ))
        } catch (e: Exception) {
            Log.e(TAG, "initTuya error: ${e.message}", e)
            result.error("INIT_ERROR", "Failed to initialize Tuya SDK: ${e.message}", null)
        }
    }

    // ========================================================================
    // loginAnonymous - Register/login user with UID
    // ========================================================================
    private fun handleLoginAnonymous(uid: String, result: MethodChannel.Result) {
        Log.d(TAG, "loginAnonymous called with uid: $uid")
        if (uid.isEmpty()) {
            result.error("INVALID_UID", "UID cannot be empty", null)
            return
        }

        try {
            ThingHomeSdk.getUserInstance().loginOrRegisterWithUid(
                "62", // Country code for Indonesia
                uid,
                uid.hashCode().toString(), // Use uid hash as password
                object : ILoginCallback {
                    override fun onSuccess(user: User?) {
                        Log.d(TAG, "Login success: uid=$uid")

                        // After login, ensure we have a home to manage devices
                        ensureHomeExists { homeId ->
                            currentHomeId = homeId
                            runOnUiThread {
                                result.success(mapOf(
                                    "status" to "logged_in",
                                    "uid" to uid,
                                    "home_id" to homeId
                                ))
                            }
                        }
                    }

                    override fun onError(code: String?, error: String?) {
                        Log.e(TAG, "Login error: $code - $error")
                        runOnUiThread {
                            result.error("LOGIN_ERROR", "Login failed: $error (code: $code)", null)
                        }
                    }
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "loginAnonymous exception: ${e.message}", e)
            result.error("LOGIN_EXCEPTION", e.message, null)
        }
    }

    /**
     * Ensure a Tuya "home" exists for device management.
     * Tuya requires devices to be managed under a home context.
     */
    private fun ensureHomeExists(callback: (Long) -> Unit) {
        ThingHomeSdk.getHomeManagerInstance().queryHomeList(object : IThingGetHomeListCallback {
            override fun onSuccess(homeBeans: MutableList<HomeBean>?) {
                if (!homeBeans.isNullOrEmpty()) {
                    val homeId = homeBeans[0].homeId
                    Log.d(TAG, "Using existing home: $homeId")
                    callback(homeId)
                } else {
                    // Create a default home
                    ThingHomeSdk.getHomeManagerInstance().createHome(
                        "Sahabat SOS Home",
                        0.0, 0.0, // lat/lon
                        "",        // geoName
                        listOf("Default Room"),
                        object : IThingHomeResultCallback {
                            override fun onSuccess(bean: HomeBean?) {
                                val homeId = bean?.homeId ?: -1L
                                Log.d(TAG, "Created new home: $homeId")
                                callback(homeId)
                            }

                            override fun onError(errorCode: String?, errorMsg: String?) {
                                Log.e(TAG, "Create home error: $errorCode - $errorMsg")
                                callback(-1L)
                            }
                        }
                    )
                }
            }

            override fun onError(errorCode: String?, error: String?) {
                Log.e(TAG, "Query home list error: $errorCode - $error")
                callback(-1L)
            }
        })
    }

    // ========================================================================
    // startWifiPairing - Start Wi-Fi EZ or AP Mode pairing
    // ========================================================================
    private var currentActivator: IThingActivator? = null
    private var savedToken: String? = null

    private fun handleStartWifiPairing(ssid: String, password: String, result: MethodChannel.Result) {
        handleStartWifiPairingWithMode(ssid, password, "ez", result)
    }

    // Step 1 for AP Mode: Get token while still on home Wi-Fi (with internet)
    private fun handleGetWifiToken(result: MethodChannel.Result) {
        Log.d(TAG, "getWifiToken called, homeId=$currentHomeId")

        if (currentHomeId <= 0) {
            result.error("NO_HOME", "No Tuya home available. Please login first.", null)
            return
        }

        try {
            ThingHomeSdk.getActivatorInstance().getActivatorToken(currentHomeId, object : IThingActivatorGetToken {
                override fun onSuccess(token: String) {
                    Log.d(TAG, "Got activator token: $token")
                    savedToken = token
                    runOnUiThread {
                        result.success(mapOf("status" to "token_ready", "token" to token))
                    }
                }

                override fun onFailure(errorCode: String?, errorMsg: String?) {
                    Log.e(TAG, "Failed to get token: $errorCode - $errorMsg")
                    runOnUiThread {
                        result.error("TOKEN_ERROR", "Gagal ambil token: $errorMsg (code: $errorCode)", null)
                    }
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "getWifiToken exception: ${e.message}", e)
            result.error("TOKEN_EXCEPTION", e.message, null)
        }
    }

    // Step 2 for AP Mode: Start pairing after user connects to SmartLife hotspot
    private fun handleStartApPairingWithToken(ssid: String, password: String, token: String, result: MethodChannel.Result) {
        Log.d(TAG, "startApPairingWithToken called for SSID: $ssid, token: $token")

        // Stop any existing activator
        try {
            currentActivator?.stop()
            currentActivator?.onDestroy()
            currentActivator = null
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping previous activator: ${e.message}")
        }

        try {
            val builder = ActivatorBuilder()
                .setContext(this@MainActivity)
                .setSsid(ssid)
                .setPassword(password)
                .setActivatorModel(ActivatorModelEnum.THING_AP)
                .setTimeOut(120)
                .setToken(token)
                .setListener(object : IThingSmartActivatorListener {
                    override fun onError(errorCode: String?, errorMsg: String?) {
                        Log.e(TAG, "AP pairing error: $errorCode - $errorMsg")
                        runOnUiThread {
                            val eventData = JSONObject().apply {
                                put("type", "wifi_pairing_error")
                                put("error_code", errorCode)
                                put("error_msg", errorMsg)
                            }
                            eventSink?.success(eventData.toString())
                        }
                    }

                    override fun onActiveSuccess(devResp: DeviceBean?) {
                        Log.d(TAG, "AP pairing success! devId: ${devResp?.devId}")
                        runOnUiThread {
                            val eventData = JSONObject().apply {
                                put("type", "wifi_pairing_success")
                                put("device_id", devResp?.devId)
                                put("name", devResp?.name)
                                put("is_online", devResp?.getIsOnline())
                            }
                            eventSink?.success(eventData.toString())
                        }
                    }

                    override fun onStep(step: String?, data: Any?) {
                        Log.d(TAG, "AP pairing step: $step, data: $data")
                        runOnUiThread {
                            val eventData = JSONObject().apply {
                                put("type", "wifi_pairing_step")
                                put("step", step)
                            }
                            eventSink?.success(eventData.toString())
                        }
                    }
                })

            currentActivator = ThingHomeSdk.getActivatorInstance().newActivator(builder)
            currentActivator?.start()

            runOnUiThread {
                result.success(mapOf("status" to "pairing_started", "mode" to "ap"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "AP pairing exception: ${e.message}", e)
            result.error("AP_PAIRING_ERROR", "Failed to start AP pairing: ${e.message}", null)
        }
    }

    // EZ Mode: get token + start in one step (phone stays on home Wi-Fi)
    private fun handleStartWifiPairingWithMode(ssid: String, password: String, mode: String, result: MethodChannel.Result) {
        Log.d(TAG, "startWifiPairing EZ mode called for SSID: $ssid")

        if (currentHomeId <= 0) {
            result.error("NO_HOME", "No Tuya home available. Please login first.", null)
            return
        }

        // Stop any existing activator
        try {
            currentActivator?.stop()
            currentActivator?.onDestroy()
            currentActivator = null
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping previous activator: ${e.message}")
        }

        try {
            ThingHomeSdk.getActivatorInstance().getActivatorToken(currentHomeId, object : IThingActivatorGetToken {
                override fun onSuccess(token: String) {
                    Log.d(TAG, "Got activator token: $token")

                    val builder = ActivatorBuilder()
                        .setContext(this@MainActivity)
                        .setSsid(ssid)
                        .setPassword(password)
                        .setActivatorModel(ActivatorModelEnum.THING_EZ)
                        .setTimeOut(120)
                        .setToken(token)
                        .setListener(object : IThingSmartActivatorListener {
                            override fun onError(errorCode: String?, errorMsg: String?) {
                                Log.e(TAG, "Wi-Fi pairing error: $errorCode - $errorMsg")
                                runOnUiThread {
                                    val eventData = JSONObject().apply {
                                        put("type", "wifi_pairing_error")
                                        put("error_code", errorCode)
                                        put("error_msg", errorMsg)
                                    }
                                    eventSink?.success(eventData.toString())
                                }
                            }

                            override fun onActiveSuccess(devResp: DeviceBean?) {
                                Log.d(TAG, "Wi-Fi pairing success! devId: ${devResp?.devId}")
                                runOnUiThread {
                                    val eventData = JSONObject().apply {
                                        put("type", "wifi_pairing_success")
                                        put("device_id", devResp?.devId)
                                        put("name", devResp?.name)
                                        put("is_online", devResp?.getIsOnline())
                                    }
                                    eventSink?.success(eventData.toString())
                                }
                            }

                            override fun onStep(step: String?, data: Any?) {
                                Log.d(TAG, "Wi-Fi pairing step: $step, data: $data")
                                runOnUiThread {
                                    val eventData = JSONObject().apply {
                                        put("type", "wifi_pairing_step")
                                        put("step", step)
                                    }
                                    eventSink?.success(eventData.toString())
                                }
                            }
                        })

                    currentActivator = ThingHomeSdk.getActivatorInstance().newMultiActivator(builder)
                    currentActivator?.start()
                    
                    runOnUiThread {
                        result.success(mapOf("status" to "pairing_started", "mode" to "ez"))
                    }
                }

                override fun onFailure(errorCode: String?, errorMsg: String?) {
                    Log.e(TAG, "Failed to get activator token: $errorCode - $errorMsg")
                    runOnUiThread {
                        result.error("TOKEN_ERROR", "Failed to get pairing token: $errorMsg (code: $errorCode)", null)
                    }
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "Wi-Fi pairing exception: ${e.message}", e)
            result.error("WIFI_PAIRING_ERROR", "Failed to start Wi-Fi pairing: ${e.message}", null)
        }
    }

    private fun handleStopWifiPairing(result: MethodChannel.Result) {
        try {
            currentActivator?.stop()
            currentActivator?.onDestroy()
            currentActivator = null
            result.success(mapOf("status" to "stopped"))
        } catch (e: Exception) {
            Log.e(TAG, "Stop Wi-Fi pairing error: ${e.message}")
            result.success(mapOf("status" to "stopped"))
        }
    }

    // ========================================================================
    // startBLEScan - Start BLE scanning for nearby Tuya devices
    // ========================================================================
    private fun handleStartBLEScan(result: MethodChannel.Result) {
        Log.d(TAG, "startBLEScan called")
        try {
            discoveredBleDevices.clear()

            val scanSetting = LeScanSetting.Builder()
                .setTimeout(60000) // 60 seconds scan timeout
                .addScanType(ScanType.SINGLE) // Single BLE device scan
                .build()

            ThingHomeSdk.getBleOperator().startLeScan(
                scanSetting
            ) { bean ->
                if (bean != null) {
                    val deviceId = bean.uuid ?: ""
                    Log.d(TAG, "BLE device found: name=${bean.name}, uuid=$deviceId")

                    // Store for later pairing
                    discoveredBleDevices[deviceId] = bean

                    // Send found device info to Flutter via EventChannel
                    val deviceInfo = JSONObject().apply {
                        put("type", "ble_device_found")
                        put("id", deviceId)
                        put("name", bean.name ?: "Tuya BLE Device")
                        put("product_id", bean.productId ?: "")
                        put("rssi", bean.rssi)
                        put("timestamp", System.currentTimeMillis())
                    }
                    runOnUiThread {
                        eventSink?.success(deviceInfo.toString())
                    }
                }
            }

            result.success(mapOf("status" to "scanning"))
        } catch (e: Exception) {
            Log.e(TAG, "BLE scan error: ${e.message}", e)
            result.error("BLE_SCAN_ERROR", "Failed to start BLE scan: ${e.message}", null)
        }
    }

    // ========================================================================
    // stopBLEScan - Stop BLE scanning
    // ========================================================================
    private fun handleStopBLEScan(result: MethodChannel.Result) {
        Log.d(TAG, "stopBLEScan called")
        try {
            ThingHomeSdk.getBleOperator().stopLeScan()
            result.success(mapOf("status" to "stopped"))
        } catch (e: Exception) {
            Log.e(TAG, "Stop BLE scan error: ${e.message}", e)
            result.error("BLE_STOP_ERROR", "Failed to stop BLE scan: ${e.message}", null)
        }
    }

    // ========================================================================
    // pairDevice - Connect a discovered BLE device
    // ========================================================================
    private fun handlePairDevice(deviceUuid: String, result: MethodChannel.Result) {
        Log.d(TAG, "pairDevice called for: $deviceUuid")

        if (currentHomeId <= 0) {
            result.error("NO_HOME", "No Tuya home available. Please login first.", null)
            return
        }

        val scanBean = discoveredBleDevices[deviceUuid]
        if (scanBean == null) {
            result.error("DEVICE_NOT_FOUND", "Device $deviceUuid not found in scan results. Please scan again.", null)
            return
        }

        try {
            ThingHomeSdk.getBleOperator().connectBleDevice(scanBean.address, object : com.thingclips.smart.android.ble.api.LeConnectResponse {
                override fun onConnnectResult(devId: String?, isSuccess: Boolean) {
                    Log.d(TAG, "BLE connect result: $isSuccess for $devId")
                    if (isSuccess) {
                        runOnUiThread {
                            result.success(mapOf(
                                "status" to "paired",
                                "device_id" to (devId ?: scanBean.address),
                                "name" to (scanBean.name ?: "Tuya BLE Device"),
                                "product_id" to (scanBean.productId ?: ""),
                                "is_online" to true
                            ))
                        }
                    } else {
                        runOnUiThread {
                            result.error("CONNECT_FAILED", "Failed to connect to BLE device", null)
                        }
                    }
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "pairDevice exception: ${e.message}", e)
            result.error("PAIR_EXCEPTION", e.message, null)
        }
    }

    // ========================================================================
    // getDeviceList - Get all devices from current home
    // ========================================================================
    private fun handleGetDeviceList(result: MethodChannel.Result) {
        Log.d(TAG, "getDeviceList called, homeId=$currentHomeId")

        if (currentHomeId <= 0) {
            // Try to get home first
            ensureHomeExists { homeId ->
                currentHomeId = homeId
                if (homeId > 0) {
                    fetchDevicesFromHome(homeId, result)
                } else {
                    runOnUiThread {
                        result.success(listOf<Map<String, Any>>())
                    }
                }
            }
            return
        }

        fetchDevicesFromHome(currentHomeId, result)
    }

    private fun fetchDevicesFromHome(homeId: Long, result: MethodChannel.Result) {
        try {
            val homeInstance = ThingHomeSdk.newHomeInstance(homeId)
            homeInstance.getHomeDetail(object : IThingHomeResultCallback {
                override fun onSuccess(bean: HomeBean?) {
                    val deviceBeans = bean?.deviceList ?: emptyList()
                    Log.d(TAG, "Found ${deviceBeans.size} devices in home $homeId")

                    val deviceList = deviceBeans.map { device ->
                        mapOf(
                            "device_id" to device.devId,
                            "name" to device.name,
                            "product_id" to (device.productId ?: ""),
                            "is_online" to device.getIsOnline(),
                            "battery" to (getDpValue(device, "battery_percentage") ?: -1),
                            "signal_strength" to getSignalStrength(device),
                            "dps" to (device.dps?.mapKeys { it.key } ?: emptyMap<String, Any>())
                        )
                    }

                    runOnUiThread {
                        result.success(deviceList)
                    }
                }

                override fun onError(errorCode: String?, errorMsg: String?) {
                    Log.e(TAG, "getDeviceList error: $errorCode - $errorMsg")
                    runOnUiThread {
                        result.success(listOf<Map<String, Any>>())
                    }
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "getDeviceList exception: ${e.message}", e)
            result.success(listOf<Map<String, Any>>())
        }
    }

    // ========================================================================
    // listenDevice - Register IDevListener for real-time DP updates
    // ========================================================================
    private fun handleListenDevice(deviceId: String, result: MethodChannel.Result) {
        Log.d(TAG, "listenDevice called for: $deviceId")

        if (deviceId.isEmpty()) {
            result.error("INVALID_DEVICE", "Device ID cannot be empty", null)
            return
        }

        // Stop existing listener for this device if any
        deviceListeners[deviceId]?.let {
            it.unRegisterDevListener()
            it.onDestroy()
        }

        try {
            val tuyaDevice = ThingHomeSdk.newDeviceInstance(deviceId)
            tuyaDevice.registerDevListener(object : IDevListener {
                override fun onDpUpdate(devId: String?, dpStr: String?) {
                    Log.d(TAG, "DP Update from $devId: $dpStr")
                    val eventData = JSONObject().apply {
                        put("device_id", devId ?: deviceId)
                        put("dps", dpStr ?: "{}")
                        put("timestamp", System.currentTimeMillis())
                        put("type", "dp_update")
                        put("is_simulation", false)
                    }
                    runOnUiThread {
                        eventSink?.success(eventData.toString())
                    }
                }

                override fun onRemoved(devId: String?) {
                    Log.d(TAG, "Device removed: $devId")
                    val eventData = JSONObject().apply {
                        put("device_id", devId ?: deviceId)
                        put("type", "device_removed")
                        put("timestamp", System.currentTimeMillis())
                    }
                    runOnUiThread {
                        eventSink?.success(eventData.toString())
                    }
                    // Clean up
                    deviceListeners.remove(devId ?: deviceId)
                }

                override fun onStatusChanged(devId: String?, online: Boolean) {
                    Log.d(TAG, "Device status changed: $devId online=$online")
                    val eventData = JSONObject().apply {
                        put("device_id", devId ?: deviceId)
                        put("type", "status_changed")
                        put("is_online", online)
                        put("timestamp", System.currentTimeMillis())
                    }
                    runOnUiThread {
                        eventSink?.success(eventData.toString())
                    }
                }

                override fun onNetworkStatusChanged(devId: String?, status: Boolean) {
                    Log.d(TAG, "Network status changed: $devId status=$status")
                }

                override fun onDevInfoUpdate(devId: String?) {
                    Log.d(TAG, "Device info updated: $devId")
                }
            })

            deviceListeners[deviceId] = tuyaDevice
            result.success(mapOf("status" to "listening", "device_id" to deviceId))
        } catch (e: Exception) {
            Log.e(TAG, "listenDevice exception: ${e.message}", e)
            result.error("LISTEN_ERROR", "Failed to listen device: ${e.message}", null)
        }
    }

    // ========================================================================
    // stopListenDevice - Unregister device listener
    // ========================================================================
    private fun handleStopListenDevice(deviceId: String, result: MethodChannel.Result) {
        Log.d(TAG, "stopListenDevice called for: $deviceId")
        try {
            deviceListeners[deviceId]?.let {
                it.unRegisterDevListener()
                it.onDestroy()
            }
            deviceListeners.remove(deviceId)
            result.success(mapOf("status" to "stopped"))
        } catch (e: Exception) {
            Log.e(TAG, "stopListenDevice exception: ${e.message}", e)
            result.success(mapOf("status" to "stopped"))
        }
    }

    // ========================================================================
    // removeDevice - Unpair/Remove a device from Tuya Cloud
    // ========================================================================
    private fun handleRemoveDevice(deviceId: String, result: MethodChannel.Result) {
        Log.d(TAG, "removeDevice called for: $deviceId")
        try {
            val device = ThingHomeSdk.newDeviceInstance(deviceId)
            if (device != null) {
                device.removeDevice(object : IResultCallback {
                    override fun onError(code: String?, error: String?) {
                        Log.e(TAG, "Remove device failed: code=$code, error=$error")
                        result.error(code ?: "REMOVE_FAILED", error ?: "Unknown error", null)
                    }
                    override fun onSuccess() {
                        Log.d(TAG, "Device successfully removed: $deviceId")
                        deviceListeners[deviceId]?.let {
                            it.unRegisterDevListener()
                            it.onDestroy()
                        }
                        deviceListeners.remove(deviceId)
                        result.success(mapOf("status" to "success"))
                    }
                })
            } else {
                result.error("DEVICE_NOT_FOUND", "Device instance not found", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "removeDevice exception: ${e.message}", e)
            result.error("EXCEPTION", e.message, null)
        }
    }

    // ========================================================================
    // getDeviceStatus - Get real device status from Tuya SDK cache
    // ========================================================================
    private fun handleGetDeviceStatus(deviceId: String, result: MethodChannel.Result) {
        Log.d(TAG, "getDeviceStatus called for: $deviceId")
        try {
            val deviceBean = ThingHomeSdk.getDataInstance().getDeviceBean(deviceId)
            if (deviceBean != null) {
                val dps = deviceBean.dps ?: emptyMap()
                result.success(mapOf(
                    "device_id" to deviceBean.devId,
                    "name" to (deviceBean.name ?: "Unknown"),
                    "product_id" to (deviceBean.productId ?: ""),
                    "is_online" to deviceBean.getIsOnline(),
                    "battery" to (getDpValue(deviceBean, "battery_percentage") ?: -1),
                    "signal_strength" to getSignalStrength(deviceBean),
                    "dps" to dps.mapKeys { it.key }
                ))
            } else {
                // Device not found in cache, return basic info
                result.success(mapOf(
                    "device_id" to deviceId,
                    "name" to "Unknown Device",
                    "is_online" to false,
                    "battery" to -1,
                    "signal_strength" to "unknown"
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "getDeviceStatus exception: ${e.message}", e)
            result.success(mapOf(
                "device_id" to deviceId,
                "is_online" to false,
                "battery" to -1,
                "signal_strength" to "unknown"
            ))
        }
    }

    // ========================================================================
    // Helper methods
    // ========================================================================

    /**
     * Get a specific DP value from a DeviceBean by DP code name.
     * Returns null if not found.
     */
    private fun getDpValue(device: DeviceBean, dpCode: String): Any? {
        return try {
            device.dps?.entries?.find {
                it.key == dpCode || it.key.contains(dpCode, ignoreCase = true)
            }?.value
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Determine signal strength label from device info.
     */
    private fun getSignalStrength(device: DeviceBean): String {
        return if (device.getIsOnline()) "strong" else "offline"
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
        // Clean up all device listeners
        deviceListeners.forEach { (_, device) ->
            try {
                device.unRegisterDevListener()
                device.onDestroy()
            } catch (e: Exception) {
                Log.e(TAG, "Error cleaning up device listener: ${e.message}")
            }
        }
        deviceListeners.clear()

        // Stop BLE scanning
        try {
            ThingHomeSdk.getBleOperator().stopLeScan()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping BLE scan: ${e.message}")
        }

        super.onDestroy()
    }
}
