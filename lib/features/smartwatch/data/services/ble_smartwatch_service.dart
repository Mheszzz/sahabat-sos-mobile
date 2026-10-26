import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/smartwatch_device_model.dart';
import '../models/smartwatch_event_model.dart';
import 'smartwatch_service.dart';

class BleSmartwatchService implements SmartwatchService {
  @override
  String get protocolName => 'Universal BLE GATT';

  final _eventController = StreamController<SmartwatchEventModel>.broadcast();
  final _heartRateController = StreamController<int>.broadcast();
  final _batteryController = StreamController<int>.broadcast();
  final _scanResultsController = StreamController<List<SmartwatchDeviceModel>>.broadcast();

  final ValueNotifier<bool> connectionState = ValueNotifier(false);

  BluetoothDevice? _connectedDevice;
  SmartwatchDeviceModel? _connectedDeviceModel;
  StreamSubscription? _scanSub;
  StreamSubscription? _hrSub;
  StreamSubscription? _batterySub;
  StreamSubscription? _connectionStateSub;

  static final Guid _immediateAlertServiceUuid = Guid('1802');
  static final Guid _alertLevelCharUuid = Guid('2a06');

  int? _currentBattery;
  int? _currentBpm;

  bool _autoReconnectEnabled = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  int? get currentBpm => _currentBpm;
  int? get currentBattery => _currentBattery;
  SmartwatchDeviceModel? get connectedDeviceModel => _connectedDeviceModel;
  Stream<int> get batteryStream => _batteryController.stream;

  @override
  Future<bool> isSupported() async {
    try {
      return await FlutterBluePlus.isSupported;
    } catch (e) {
      debugPrint('Error checking BLE support: $e');
      return false;
    }
  }

  static bool isIgnoredDeviceName(String name) {
    final lower = name.toLowerCase().trim();
    return lower.isEmpty ||
        lower.startsWith('laptop-') ||
        lower.startsWith('desktop-') ||
        lower.startsWith('pc-') ||
        lower.contains('windows') ||
        lower.contains('smart tv') ||
        lower.startsWith('rpp') ||
        lower.contains('printer') ||
        lower.startsWith('pos-') ||
        lower.startsWith('pos58') ||
        lower.startsWith('pos80') ||
        lower.startsWith('tuya_') ||
        lower.startsWith('ty_');
  }

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    await stopScan();

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('Tidak bisa menyalakan Bluetooth otomatis: $e');
      }
    }

    final discoveredMap = <String, SmartwatchDeviceModel>{};

    // 1. Ambil perangkat yang sudah terhubung / bonded di pengaturan Bluetooth HP (Penting untuk Huawei & Vivan)
    try {
      final systemDevices = await FlutterBluePlus.systemDevices([]);
      final bondedDevices = await FlutterBluePlus.bondedDevices;
      final allKnown = [...systemDevices, ...bondedDevices];

      for (final d in allKnown) {
        final name = d.platformName.trim();
        if (!isIgnoredDeviceName(name)) {
          final id = d.remoteId.str;
          discoveredMap[id] = SmartwatchDeviceModel(
            id: id,
            name: name,
            brand: _detectBrand(name),
            deviceModel: name,
            macAddress: id,
            rssi: -50,
            isConnected: d.isConnected,
          );
        }
      }
      if (discoveredMap.isNotEmpty) {
        _scanResultsController.add(discoveredMap.values.toList());
      }
    } catch (e) {
      debugPrint('Info membaca bonded/system devices: $e');
    }

    // 2. BLE Scan reguler untuk perangkat di sekitar
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final advName = r.advertisementData.advName.trim();
        final platformName = r.device.platformName.trim();
        final name = advName.isNotEmpty ? advName : platformName;

        if (!isIgnoredDeviceName(name)) {
          final id = r.device.remoteId.str;
          discoveredMap[id] = SmartwatchDeviceModel(
            id: id,
            name: name,
            brand: _detectBrand(name),
            deviceModel: name,
            macAddress: id,
            rssi: r.rssi,
            isConnected: r.device.isConnected,
          );
        }
      }
      _scanResultsController.add(discoveredMap.values.toList());
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      debugPrint('Error starting BLE scan: $e');
    }
  }

  String _detectBrand(String deviceName) {
    final lower = deviceName.toLowerCase();
    if (lower.contains('mi band') || lower.contains('xiaomi') || lower.contains('redmi')) {
      return 'xiaomi';
    }
    if (lower.contains('huawei') ||
        lower.contains('honor') ||
        lower.contains('watch gt') ||
        lower.contains('watch fit') ||
        lower.contains(' band ')) {
      return 'huawei';
    }
    if (lower.contains('galaxy')) return 'samsung';
    return 'generic_ble';
  }

  @override
  Future<void> stopScan() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (e) {
      debugPrint('Error stopping BLE scan: $e');
    }
    await _scanSub?.cancel();
    _scanSub = null;
  }

  @override
  Stream<List<SmartwatchDeviceModel>> get scanResultsStream =>
      _scanResultsController.stream;

  @override
  Future<bool> connect(SmartwatchDeviceModel device) async {
    try {
      await stopScan();

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
          await Future.delayed(const Duration(seconds: 2));
        } catch (_) {
          return false;
        }
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
      }

      if (_connectedDevice != null && _connectedDevice!.remoteId.str != device.id) {
        try {
          await _connectionStateSub?.cancel();
          await _hrSub?.cancel();
          await _batterySub?.cancel();
          await _connectedDevice!.disconnect();
        } catch (_) {}
      }

      BluetoothDevice bluetoothDevice = BluetoothDevice.fromId(device.id);
      _connectedDeviceModel = device;

      // 1. Scan singkat 4 detik untuk menangkap sinyal BLE aktif saat Heart Rate Broadcast menyala
      debugPrint('🔍 Mencari sinyal aktif dari ${device.name} (${device.id})...');
      try {
        final foundCompleter = Completer<void>();
        final tempSub = FlutterBluePlus.scanResults.listen((results) {
          for (final r in results) {
            final rName = r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
                : r.device.platformName;
            // Cocokkan berdasarkan MAC Address atau Nama (karena Huawei kadang memakai Random MAC untuk BLE HR)
            if (r.device.remoteId.str.toUpperCase() == device.id.toUpperCase() ||
                (rName.isNotEmpty &&
                    device.name.isNotEmpty &&
                    rName.toLowerCase().contains(device.name.toLowerCase().split('-').first))) {
              bluetoothDevice = r.device;
              if (!foundCompleter.isCompleted) foundCompleter.complete();
            }
          }
        });

        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 4),
          androidScanMode: AndroidScanMode.lowLatency,
        );

        await Future.any([
          foundCompleter.future,
          Future.delayed(const Duration(seconds: 4)),
        ]);

        await tempSub.cancel();
        await stopScan();
      } catch (e) {
        await stopScan();
      }

      debugPrint('📡 Menghubungkan GATT ke ${device.name} (${bluetoothDevice.remoteId.str})...');

      bool connected = bluetoothDevice.isConnected;

      // 2. Percobaan Direct Connect
      if (!connected) {
        try {
          await bluetoothDevice.connect(
            timeout: const Duration(seconds: 12),
            autoConnect: false,
            mtu: null,
          );
          connected = true;
        } catch (e) {
          debugPrint('⚠️ Direct connect gagal ($e). Mencoba autoConnect...');
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }

      // 3. Percobaan AutoConnect
      if (!connected) {
        try {
          await bluetoothDevice.connect(
            timeout: const Duration(seconds: 15),
            autoConnect: true,
            mtu: null,
          );
          await bluetoothDevice.connectionState
              .where((s) => s == BluetoothConnectionState.connected)
              .first
              .timeout(const Duration(seconds: 8));
          connected = true;
        } catch (e) {
          debugPrint('⚠️ AutoConnect info: $e');
          if (device.brand.toLowerCase() == 'huawei') {
            connected = true;
          }
        }
      }

      if (!connected) {
        connectionState.value = false;
        return false;
      }

      _connectedDevice = bluetoothDevice;
      _autoReconnectEnabled = true;
      _reconnectAttempts = 0;
      connectionState.value = true;

      _setupConnectionStateMonitoring(bluetoothDevice, device);

      await Future.delayed(const Duration(milliseconds: 600));
      await _discoverAndSubscribeServices(bluetoothDevice, device);

      return true;
    } catch (e) {
      debugPrint('❌ Error connecting BLE device ${device.id}: $e');
      connectionState.value = false;
      return false;
    }
  }

  void _setupConnectionStateMonitoring(BluetoothDevice btDevice, SmartwatchDeviceModel device) {
    _connectionStateSub?.cancel();
    _connectionStateSub = btDevice.connectionState.listen((state) {
      debugPrint('🔗 BLE Connection State Changed: $state');

      if (state == BluetoothConnectionState.disconnected) {
        connectionState.value = false;
        _currentBpm = null;
        _heartRateController.add(0);

        if (_autoReconnectEnabled) {
          _attemptReconnect(device);
        }
      } else if (state == BluetoothConnectionState.connected) {
        connectionState.value = true;
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
      }
    });
  }

  void _attemptReconnect(SmartwatchDeviceModel device) {
    if (!_autoReconnectEnabled || _reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: 2 * (1 << (_reconnectAttempts - 1)));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (!_autoReconnectEnabled) return;
      try {
        final bluetoothDevice = BluetoothDevice.fromId(device.id);
        await bluetoothDevice.connect(
          timeout: const Duration(seconds: 15),
          autoConnect: true,
          mtu: null,
        );
        await bluetoothDevice.connectionState
            .where((s) => s == BluetoothConnectionState.connected)
            .first
            .timeout(const Duration(seconds: 10));

        _connectedDevice = bluetoothDevice;
        connectionState.value = true;

        await Future.delayed(const Duration(milliseconds: 500));
        await _discoverAndSubscribeServices(bluetoothDevice, device);
        _reconnectAttempts = 0;
      } catch (e) {
        _attemptReconnect(device);
      }
    });
  }

  /// Fungsi khusus untuk menangkap sinyal BLE Heart Rate Broadcast (UUID 0x180D)
  /// meskipun HUAWEI Band 7 menggunakan Random MAC Address saat broadcast
  Future<String> scanAndReadLiveHeartRate(SmartwatchDeviceModel device) async {
    try {
      await stopScan();

      if (defaultTargetPlatform == TargetPlatform.android) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();
      }

      BluetoothDevice? targetDevice;

      // TAHAP 1: Cari perangkat apa pun di sekitar yang sedang memancarkan Service Heart Rate (0x180D)
      // Ini mengatasi masalah HUAWEI Band 7 yang mengganti MAC Address saat mode Siaran HR aktif!
      debugPrint('🔍 Tahap 1: Mencari pancaran Service Heart Rate (0x180D)...');
      final hrServiceCompleter = Completer<BluetoothDevice?>();
      final sub1 = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final hasHrService = r.advertisementData.serviceUuids
              .any((u) => u.toString().toLowerCase().contains('180d'));
          if (hasHrService && !hrServiceCompleter.isCompleted) {
            debugPrint('✅ Ditemukan pemancar 0x180D: ${r.device.remoteId.str}');
            hrServiceCompleter.complete(r.device);
          }
        }
      });

      await FlutterBluePlus.startScan(
        withServices: [Guid('180d')],
        timeout: const Duration(seconds: 4),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      targetDevice = await Future.any([
        hrServiceCompleter.future,
        Future.delayed(const Duration(seconds: 4), () => null),
      ]);

      await sub1.cancel();
      await stopScan();

      // TAHAP 2: Jika tidak terdeteksi lewat filter 0x180D, lakukan scan umum (nama / MAC / sinyal terdekat)
      if (targetDevice == null) {
        debugPrint('🔍 Tahap 2: Melakukan scan umum untuk ${device.name}...');
        final generalCompleter = Completer<BluetoothDevice?>();
        BluetoothDevice? bestCandidate;
        int bestRssi = -999;

        final sub2 = FlutterBluePlus.scanResults.listen((results) {
          for (final r in results) {
            final advName = r.advertisementData.advName.toLowerCase();
            final platName = r.device.platformName.toLowerCase();
            final macMatch = r.device.remoteId.str.toUpperCase() == device.id.toUpperCase();
            final nameMatch = advName.contains('huawei') ||
                platName.contains('huawei') ||
                advName.contains('band') ||
                platName.contains('band');

            if (macMatch || nameMatch) {
              if (!generalCompleter.isCompleted) {
                generalCompleter.complete(r.device);
              }
            } else if (r.rssi > -70 && r.rssi > bestRssi && !isIgnoredDeviceName(advName)) {
              bestRssi = r.rssi;
              bestCandidate = r.device;
            }
          }
        });

        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 4),
          androidScanMode: AndroidScanMode.lowLatency,
        );

        targetDevice = await Future.any([
          generalCompleter.future,
          Future.delayed(const Duration(seconds: 4), () => bestCandidate),
        ]);

        await sub2.cancel();
        await stopScan();
      }

      // TAHAP 3: Cek dari daftar perangkat yang sudah terhubung di sistem Android
      if (targetDevice == null) {
        try {
          final bonded = await FlutterBluePlus.bondedDevices;
          for (final d in bonded) {
            if (d.remoteId.str.toUpperCase() == device.id.toUpperCase() ||
                d.platformName.toLowerCase().contains('huawei') ||
                d.platformName.toLowerCase().contains('band')) {
              targetDevice = d;
              break;
            }
          }
        } catch (_) {}
      }

      targetDevice ??= BluetoothDevice.fromId(device.id);
      debugPrint('🎯 Menghubungkan GATT ke target: ${targetDevice.remoteId.str}');

      // TAHAP 4: Buka koneksi GATT (coba direct connect, lalu fallback ke autoConnect)
      if (!targetDevice.isConnected) {
        bool ok = false;
        try {
          await targetDevice.connect(
            timeout: const Duration(seconds: 8),
            autoConnect: false,
            mtu: null,
          );
          ok = true;
        } catch (e) {
          debugPrint('Direct connect info ($e), mencoba autoConnect...');
        }

        if (!ok) {
          try {
            await targetDevice.connect(
              timeout: const Duration(seconds: 10),
              autoConnect: true,
              mtu: null,
            );
            await targetDevice.connectionState
                .where((s) => s == BluetoothConnectionState.connected)
                .first
                .timeout(const Duration(seconds: 7));
            ok = true;
          } catch (e) {
            return 'Gelang belum merespons koneksi BLE (${targetDevice.remoteId.str}). Pastikan layar gelang MENYALA di menu "Siaran Detak Jantung" & lupakan (Unpair) gelang dari pengaturan Bluetooth HP.';
          }
        }
      }

      _connectedDevice = targetDevice;
      connectionState.value = true;

      await Future.delayed(const Duration(milliseconds: 500));
      final services = await targetDevice.discoverServices();
      debugPrint('📋 Berhasil membaca ${services.length} GATT Services!');

      bool hrFound = false;

      for (final s in services) {
        final sUuid = s.uuid.toString().toLowerCase();
        debugPrint('   🔹 Service: $sUuid');

        for (final c in s.characteristics) {
          final cUuid = c.uuid.toString().toLowerCase();
          final isStandardHr = cUuid.contains('2a37') || sUuid.contains('180d');

          if (isStandardHr && (c.properties.notify || c.properties.indicate)) {
            debugPrint('   ❤️ Subscribe ke Heart Rate ($cUuid)');
            await _hrSub?.cancel();
            await c.setNotifyValue(true);
            hrFound = true;

            _hrSub = c.onValueReceived.listen((data) {
              final bpm = _parseHeartRate(data);
              debugPrint('💓 LIVE BPM DITERIMA: $bpm (raw: $data)');
              if (bpm >= 30 && bpm <= 240) {
                _currentBpm = bpm;
                _heartRateController.add(bpm);
              }
            });
            targetDevice.cancelWhenDisconnected(_hrSub!);
          }

          // Sekalian baca baterai jika ada (0x2A19)
          if (cUuid.contains('2a19') && c.properties.read) {
            try {
              final bat = await c.read();
              if (bat.isNotEmpty) {
                _currentBattery = bat.first;
                _batteryController.add(_currentBattery!);
              }
            } catch (_) {}
          }
        }
      }

      if (hrFound) {
        await Future.delayed(const Duration(seconds: 3));
        if (_currentBpm != null && _currentBpm! > 0) {
          return 'Berhasil! Detak jantung live: $_currentBpm BPM';
        }
        return 'Terhubung ke sensor gelang! Kenakan gelang di tangan & tunggu beberapa detik...';
      }

      // Menampilkan daftar UUID yang ditemukan agar kita tahu persis isi gelang
      final uuidList = services.map((s) => s.uuid.toString().substring(0, 8)).join(', ');
      return 'Terhubung ke gelang (Services: $uuidList), tetapi fitur "Siaran Detak Jantung" (0x180D) di gelang belum aktif.';
    } catch (e) {
      debugPrint('❌ Error scanAndReadLiveHeartRate: $e');
      return 'Gagal menghubungkan ke sensor gelang: $e';
    }
  }

  Future<void> _discoverAndSubscribeServices(
    BluetoothDevice bluetoothDevice,
    SmartwatchDeviceModel device,
  ) async {
    await _hrSub?.cancel();
    _hrSub = null;
    await _batterySub?.cancel();
    _batterySub = null;

    List<BluetoothService> services = [];
    try {
      // Pastikan sudah connect sebelum discoverServices
      if (!bluetoothDevice.isConnected) {
        await bluetoothDevice.connect(
          timeout: const Duration(seconds: 8),
          autoConnect: false,
          mtu: null,
        );
      }
      services = await bluetoothDevice.discoverServices();
      debugPrint('📋 Ditemukan ${services.length} GATT services pada ${device.name}');
    } catch (e) {
      debugPrint('⚠️ Gagal discoverServices (pastikan Heart Rate Broadcast di gelang menyala): $e');
      return;
    }

    for (final service in services) {
      final sUuid = service.uuid.toString().toLowerCase();
      debugPrint('   🔹 Service UUID: $sUuid');

      for (final char in service.characteristics) {
        final cUuid = char.uuid.toString().toLowerCase();

        // 1. Heart Rate (0x2A37 di dalam service 0x180D)
        if (cUuid.contains('2a37') || (sUuid.contains('180d') && (char.properties.notify || char.properties.indicate))) {
          debugPrint('   ❤️ Karakteristik Heart Rate ditemukan ($cUuid)! Subscribing...');
          try {
            await char.setNotifyValue(true);
            _hrSub = char.onValueReceived.listen((data) {
              if (data.isNotEmpty) {
                final bpm = _parseHeartRate(data);
                debugPrint('💓 Live BPM dari gelang: $bpm');
                if (bpm > 0) {
                  _currentBpm = bpm;
                  _heartRateController.add(bpm);

                  if (bpm > 160) {
                    _eventController.add(SmartwatchEventModel(
                      deviceId: device.id,
                      eventType: SmartwatchEventType.heartRateAnomaly,
                      heartRate: bpm,
                      batteryLevel: _currentBattery,
                      timestamp: DateTime.now(),
                      triggerType: 'Detak Jantung Ekstrim (>160 BPM)',
                    ));
                  }
                }
              }
            });
            bluetoothDevice.cancelWhenDisconnected(_hrSub!);
          } catch (e) {
            debugPrint('Error setNotifyValue for HR: $e');
          }

          if (char.properties.read) {
            try {
              final initial = await char.read();
              final bpm = _parseHeartRate(initial);
              if (bpm > 0) {
                _currentBpm = bpm;
                _heartRateController.add(bpm);
              }
            } catch (_) {}
          }
        }

        // 2. Battery Level (0x2A19 di dalam service 0x180F)
        if (cUuid.contains('2a19') || sUuid.contains('180f')) {
          try {
            if (char.properties.read) {
              final val = await char.read();
              if (val.isNotEmpty) {
                _currentBattery = val.first;
                _batteryController.add(_currentBattery!);
              }
            }
            if (char.properties.notify) {
              await char.setNotifyValue(true);
              _batterySub = char.onValueReceived.listen((val) {
                if (val.isNotEmpty) {
                  _currentBattery = val.first;
                  _batteryController.add(_currentBattery!);
                }
              });
              bluetoothDevice.cancelWhenDisconnected(_batterySub!);
            }
          } catch (_) {}
        }
      }
    }
  }

  int _parseHeartRate(List<int> data) {
    if (data.isEmpty) return 0;
    final flags = data[0];
    final is16Bit = (flags & 0x01) != 0;
    if (is16Bit && data.length >= 3) {
      return data[1] + (data[2] << 8);
    } else if (data.length >= 2) {
      return data[1];
    } else if (data.length == 1) {
      return data[0];
    }
    return 0;
  }

  @override
  Future<void> disconnect(String deviceId) async {
    _autoReconnectEnabled = false;
    _reconnectTimer?.cancel();
    try {
      await _connectionStateSub?.cancel();
      _connectionStateSub = null;
      await _hrSub?.cancel();
      _hrSub = null;
      await _batterySub?.cancel();
      _batterySub = null;
      if (_connectedDevice != null && _connectedDevice!.remoteId.str == deviceId) {
        await _connectedDevice!.disconnect();
      }
      _connectedDevice = null;
      _connectedDeviceModel = null;
      _currentBpm = null;
      _currentBattery = null;
      connectionState.value = false;
    } catch (e) {
      debugPrint('Error disconnecting BLE: $e');
    }
  }

  @override
  Stream<SmartwatchEventModel> get eventStream => _eventController.stream;

  @override
  Stream<int> get heartRateStream => _heartRateController.stream;

  @override
  Future<void> sendFeedbackAlert(
    String deviceId, {
    required String title,
    required String message,
  }) async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) return;
    try {
      final services = await _connectedDevice!.discoverServices();
      for (final service in services) {
        if (service.uuid == _immediateAlertServiceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid == _alertLevelCharUuid) {
              await char.write([0x02], withoutResponse: true);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error writing feedback alert to watch: $e');
    }
  }

  void simulateWatchSosTrigger(String deviceId) {
    _eventController.add(SmartwatchEventModel(
      deviceId: deviceId,
      eventType: SmartwatchEventType.sosButtonPressed,
      heartRate: _currentBpm,
      batteryLevel: _currentBattery,
      timestamp: DateTime.now(),
      triggerType: 'Tombol Fisik Smartwatch',
    ));
  }

  void simulateFallDetection(String deviceId) {
    _eventController.add(SmartwatchEventModel(
      deviceId: deviceId,
      eventType: SmartwatchEventType.fallDetected,
      heartRate: _currentBpm,
      batteryLevel: _currentBattery,
      fallDetected: true,
      timestamp: DateTime.now(),
      triggerType: 'Sensor Deteksi Jatuh Smartwatch',
    ));
  }

  bool get isConnected => _connectedDevice != null && connectionState.value;

  @override
  Future<void> dispose() async {
    _autoReconnectEnabled = false;
    _reconnectTimer?.cancel();
    await stopScan();
    await _connectionStateSub?.cancel();
    await _hrSub?.cancel();
    await _batterySub?.cancel();
    await _eventController.close();
    await _heartRateController.close();
    await _batteryController.close();
    await _scanResultsController.close();
    connectionState.value = false;
  }
}