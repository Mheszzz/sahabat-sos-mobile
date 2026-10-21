package com.sossahabat.app

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

import com.thingclips.smart.home.sdk.ThingHomeSdk
import com.thingclips.smart.home.sdk.bean.HomeBean
import com.thingclips.smart.home.sdk.callback.IThingHomeResultCallback
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

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val TAG = "TuyaMainActivity"
        private const val METHOD_CHANNEL = "com.sahabatsos.app/tuya_method"
        private const val EVENT_CHANNEL = "com.sahabatsos.app/tuya_events"
        private const val HUAWEI_METHOD_CHANNEL = "com.sahabatsos.app/huawei_wear"
        private const val HUAWEI_EVENT_CHANNEL = "com.sahabatsos.app/huawei_wear_events"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var huaweiEventSink: EventChannel.EventSink? = null

    private val deviceListeners = mutableMapOf<String, IThingDevice>()
    private var currentHomeId: Long = -1L
    private val discoveredBleDevices = mutableMapOf<String, ScanDeviceBean>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupMethodChannel(flutterEngine)
        setupEventChannel(flutterEngine)
        setupHuaweiWearChannel(flutterEngine)
    }

    private fun setupHuaweiWearChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HUAWEI_METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isWearEngineSupported" -> {
                        // Kembalikan false karena SDK Wear Engine native belum diinstal,
                        // sehingga koneksi GATT & Health Connect ditangani penuh oleh BleSmartwatchService & Health plugin
                        result.success(false)
                    }
                    "getBondedHuaweiDevices" -> {
                        try {
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                                if (checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                                    result.success(emptyList<Map<String, Any>>())
                                    return@setMethodCallHandler
                                }
                            }

                            val btManager = getSystemService(android.content.Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
                            val adapter = btManager?.adapter ?: android.bluetooth.BluetoothAdapter.getDefaultAdapter()
                            val list = mutableListOf<Map<String, Any>>()
                            if (adapter != null && adapter.isEnabled) {
                                val bonded = adapter.bondedDevices ?: emptySet()
                                for (device in bonded) {
                                    val name = device.name ?: ""
                                    val lower = name.lowercase()
                                    val isHuawei = lower.contains("huawei") || lower.contains("honor") || lower.contains("gt") || lower.contains("watch fit")
                                    val isWatch = isHuawei || lower.contains("watch") || lower.contains("band") || lower.contains("fit")

                                    if (isWatch) {
                                        list.add(mapOf(
                                            "device_id" to device.address,
                                            "device_name" to name,
                                            "brand" to if (isHuawei) "huawei" else "generic_ble",
                                            "device_model" to name,
                                            "mac_address" to device.address,
                                            "is_connected" to false
                                        ))
                                    }
                                }
                            }
                            Log.i(TAG, "Bonded smartwatches found: ${list.size}")
                            result.success(list)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error getting bonded Huawei devices: ${e.message}")
                            result.success(emptyList<Map<String, Any>>())
                        }
                    }
                    "connectDevice" -> {
                        val deviceId = call.argument<String>("device_id") ?: ""
                        Log.i(TAG, "Connected to Huawei smartwatch: $deviceId")
                        result.success(true)
                    }
                    "disconnectDevice" -> {
                        result.success(null)
                    }
                    "sendFeedbackAlert" -> {
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, HUAWEI_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    huaweiEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    huaweiEventSink = null
                }
            })
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

    private fun handleInitTuya(result: MethodChannel.Result) {
        try {
            result.success(mapOf(
                "status" to "initialized",
                "message" to "Tuya SDK is ready"
            ))
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize Tuya SDK: ${e.message}", null)
        }
    }

    private fun handleLoginAnonymous(uid: String, result: MethodChannel.Result) {
        if (uid.isEmpty()) {
            result.error("INVALID_UID", "UID cannot be empty", null)
            return
        }

        try {
            ThingHomeSdk.getUserInstance().loginOrRegisterWithUid(
                "62",
                uid,
                uid.hashCode().toString(),
                object : ILoginCallback {
                    override fun onSuccess(user: User?) {
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
                        runOnUiThread {
                            result.error("LOGIN_ERROR", "Login failed: $error (code: $code)", null)
                        }
                    }
                }
            )
        } catch (e: Exception) {
            result.error("LOGIN_EXCEPTION", e.message, null)
        }
    }

    private fun ensureHomeExists(callback: (Long) -> Unit) {
        ThingHomeSdk.getHomeManagerInstance().queryHomeList(object : IThingGetHomeListCallback {
            override fun onSuccess(homeBeans: MutableList<HomeBean>?) {
                if (!homeBeans.isNullOrEmpty()) {
                    callback(homeBeans[0].homeId)
                } else {
                    ThingHomeSdk.getHomeManagerInstance().createHome(
                        "Sahabat SOS Home",
                        0.0, 0.0,
                        "",
                        listOf("Default Room"),
                        object : IThingHomeResultCallback {
                            override fun onSuccess(bean: HomeBean?) {
                                callback(bean?.homeId ?: -1L)
                            }

                            override fun onError(errorCode: String?, errorMsg: String?) {
                                callback(-1L)
                            }
                        }
                    )
                }
            }

            override fun onError(errorCode: String?, error: String?) {
                callback(-1L)
            }
        })
    }

    private var currentActivator: IThingActivator? = null
    private var savedToken: String? = null

    private fun handleStartWifiPairing(ssid: String, password: String, result: MethodChannel.Result) {
        handleStartWifiPairingWithMode(ssid, password, "ez", result)
    }

    private fun handleGetWifiToken(result: MethodChannel.Result) {
        if (currentHomeId <= 0) {
            result.error("NO_HOME", "No Tuya home available. Please login first.", null)
            return
        }

        try {
            ThingHomeSdk.getActivatorInstance().getActivatorToken(currentHomeId, object : IThingActivatorGetToken {
                override fun onSuccess(token: String) {
                    savedToken = token
                    runOnUiThread {
                        result.success(mapOf("status" to "token_ready", "token" to token))
                    }
                }

                override fun onFailure(errorCode: String?, errorMsg: String?) {
                    runOnUiThread {
                        result.error("TOKEN_ERROR", "Gagal ambil token: $errorMsg (code: $errorCode)", null)
                    }
                }
            })
        } catch (e: Exception) {
            result.error("TOKEN_EXCEPTION", e.message, null)
        }
    }

    private fun handleStartApPairingWithToken(ssid: String, password: String, token: String, result: MethodChannel.Result) {
        try {
            currentActivator?.stop()
            currentActivator?.onDestroy()
            currentActivator = null
        } catch (_: Exception) {}

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
            result.error("AP_PAIRING_ERROR", "Failed to start AP pairing: ${e.message}", null)
        }
    }

    private fun handleStartWifiPairingWithMode(ssid: String, password: String, mode: String, result: MethodChannel.Result) {
        if (currentHomeId <= 0) {
            result.error("NO_HOME", "No Tuya home available. Please login first.", null)
            return
        }

        try {
            currentActivator?.stop()
            currentActivator?.onDestroy()
            currentActivator = null
        } catch (_: Exception) {}

        try {
            ThingHomeSdk.getActivatorInstance().getActivatorToken(currentHomeId, object : IThingActivatorGetToken {
                override fun onSuccess(token: String) {
                    val builder = ActivatorBuilder()
                        .setContext(this@MainActivity)
                        .setSsid(ssid)
                        .setPassword(password)
                        .setActivatorModel(ActivatorModelEnum.THING_EZ)
                        .setTimeOut(120)
                        .setToken(token)
                        .setListener(object : IThingSmartActivatorListener {
                            override fun onError(errorCode: String?, errorMsg: String?) {
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
                    runOnUiThread {
                        result.error("TOKEN_ERROR", "Failed to get pairing token: $errorMsg (code: $errorCode)", null)
                    }
                }
            })
        } catch (e: Exception) {
            result.error("WIFI_PAIRING_ERROR", "Failed to start Wi-Fi pairing: ${e.message}", null)
        }
    }

    private fun handleStopWifiPairing(result: MethodChannel.Result) {
        try {
            currentActivator?.stop()
            currentActivator?.onDestroy()
            currentActivator = null
        } catch (_: Exception) {}
        result.success(mapOf("status" to "stopped"))
    }

    private fun handleStartBLEScan(result: MethodChannel.Result) {
        try {
            discoveredBleDevices.clear()

            val scanSetting = LeScanSetting.Builder()
                .setTimeout(60000)
                .addScanType(ScanType.SINGLE)
                .build()

            ThingHomeSdk.getBleOperator().startLeScan(scanSetting) { bean ->
                if (bean != null) {
                    val deviceId = bean.uuid ?: ""
                    discoveredBleDevices[deviceId] = bean

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
            result.error("BLE_SCAN_ERROR", "Failed to start BLE scan: ${e.message}", null)
        }
    }

    private fun handleStopBLEScan(result: MethodChannel.Result) {
        try {
            ThingHomeSdk.getBleOperator().stopLeScan()
            result.success(mapOf("status" to "stopped"))
        } catch (e: Exception) {
            result.error("BLE_STOP_ERROR", "Failed to stop BLE scan: ${e.message}", null)
        }
    }

    private fun handlePairDevice(deviceUuid: String, result: MethodChannel.Result) {
        if (currentHomeId <= 0) {
            result.error("NO_HOME", "No Tuya home available. Please login first.", null)
            return
        }

        val scanBean = discoveredBleDevices[deviceUuid]
        if (scanBean == null) {
            result.error("DEVICE_NOT_FOUND", "Device $deviceUuid not found in scan results.", null)
            return
        }

        try {
            ThingHomeSdk.getBleOperator().connectBleDevice(scanBean.address, object : com.thingclips.smart.android.ble.api.LeConnectResponse {
                override fun onConnnectResult(devId: String?, isSuccess: Boolean) {
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
            result.error("PAIR_EXCEPTION", e.message, null)
        }
    }

    private fun handleGetDeviceList(result: MethodChannel.Result) {
        if (currentHomeId <= 0) {
            ensureHomeExists { homeId ->
                currentHomeId = homeId
                if (homeId > 0) {
                    fetchDevicesFromHome(homeId, result)
                } else {
                    runOnUiThread { result.success(listOf<Map<String, Any>>()) }
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
                    runOnUiThread { result.success(deviceList) }
                }

                override fun onError(errorCode: String?, errorMsg: String?) {
                    runOnUiThread { result.success(listOf<Map<String, Any>>()) }
                }
            })
        } catch (e: Exception) {
            result.success(listOf<Map<String, Any>>())
        }
    }

    private fun handleListenDevice(deviceId: String, result: MethodChannel.Result) {
        if (deviceId.isEmpty()) {
            result.error("INVALID_DEVICE", "Device ID cannot be empty", null)
            return
        }

        deviceListeners[deviceId]?.let {
            it.unRegisterDevListener()
            it.onDestroy()
        }

        try {
            val tuyaDevice = ThingHomeSdk.newDeviceInstance(deviceId)
            tuyaDevice.registerDevListener(object : IDevListener {
                override fun onDpUpdate(devId: String?, dpStr: String?) {
                    val eventData = JSONObject().apply {
                        put("device_id", devId ?: deviceId)
                        put("dps", dpStr ?: "{}")
                        put("timestamp", System.currentTimeMillis())
                        put("type", "dp_update")
                        put("is_simulation", false)
                    }
                    runOnUiThread { eventSink?.success(eventData.toString()) }
                }

                override fun onRemoved(devId: String?) {
                    val eventData = JSONObject().apply {
                        put("device_id", devId ?: deviceId)
                        put("type", "device_removed")
                        put("timestamp", System.currentTimeMillis())
                    }
                    runOnUiThread { eventSink?.success(eventData.toString()) }
                    deviceListeners.remove(devId ?: deviceId)
                }

                override fun onStatusChanged(devId: String?, online: Boolean) {
                    val eventData = JSONObject().apply {
                        put("device_id", devId ?: deviceId)
                        put("type", "status_changed")
                        put("is_online", online)
                        put("timestamp", System.currentTimeMillis())
                    }
                    runOnUiThread { eventSink?.success(eventData.toString()) }
                }

                override fun onNetworkStatusChanged(devId: String?, status: Boolean) {}
                override fun onDevInfoUpdate(devId: String?) {}
            })

            deviceListeners[deviceId] = tuyaDevice
            result.success(mapOf("status" to "listening", "device_id" to deviceId))
        } catch (e: Exception) {
            result.error("LISTEN_ERROR", "Failed to listen device: ${e.message}", null)
        }
    }

    private fun handleStopListenDevice(deviceId: String, result: MethodChannel.Result) {
        try {
            deviceListeners[deviceId]?.let {
                it.unRegisterDevListener()
                it.onDestroy()
            }
            deviceListeners.remove(deviceId)
        } catch (_: Exception) {}
        result.success(mapOf("status" to "stopped"))
    }

    private fun handleRemoveDevice(deviceId: String, result: MethodChannel.Result) {
        try {
            val device = ThingHomeSdk.newDeviceInstance(deviceId)
            if (device != null) {
                device.removeDevice(object : IResultCallback {
                    override fun onError(code: String?, error: String?) {
                        result.error(code ?: "REMOVE_FAILED", error ?: "Unknown error", null)
                    }
                    override fun onSuccess() {
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
            result.error("EXCEPTION", e.message, null)
        }
    }

    private fun handleGetDeviceStatus(deviceId: String, result: MethodChannel.Result) {
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
                result.success(mapOf(
                    "device_id" to deviceId,
                    "name" to "Unknown Device",
                    "is_online" to false,
                    "battery" to -1,
                    "signal_strength" to "unknown"
                ))
            }
        } catch (e: Exception) {
            result.success(mapOf(
                "device_id" to deviceId,
                "is_online" to false,
                "battery" to -1,
                "signal_strength" to "unknown"
            ))
        }
    }

    private fun getDpValue(device: DeviceBean, dpCode: String): Any? {
        return try {
            device.dps?.entries?.find {
                it.key == dpCode || it.key.contains(dpCode, ignoreCase = true)
            }?.value
        } catch (e: Exception) {
            null
        }
    }

    private fun getSignalStrength(device: DeviceBean): String {
        return if (device.getIsOnline()) "strong" else "offline"
    }

    private fun simulateSosEvent(deviceId: String) {
        val simulatedDp = JSONObject().apply {
            put("device_id", deviceId)
            put("dps", JSONObject().apply {
                put("1", true)
                put("sos_state", "alarm")
            }.toString())
            put("timestamp", System.currentTimeMillis())
            put("type", "dp_update")
            put("is_simulation", true)
        }
        runOnUiThread {
            eventSink?.success(simulatedDp.toString())
        }
    }

    override fun onDestroy() {
        deviceListeners.forEach { (_, device) ->
            try {
                device.unRegisterDevListener()
                device.onDestroy()
            } catch (_: Exception) {}
        }
        deviceListeners.clear()

        try {
            ThingHomeSdk.getBleOperator().stopLeScan()
        } catch (_: Exception) {}

        super.onDestroy()
    }
}