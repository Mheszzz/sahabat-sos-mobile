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
  final _scanResultsController = StreamController<List<SmartwatchDeviceModel>>.broadcast();

  /// Notifier agar Manager/UI tahu status koneksi BLE berubah
  final ValueNotifier<bool> connectionState = ValueNotifier(false);

  BluetoothDevice? _connectedDevice;
  SmartwatchDeviceModel? _connectedDeviceModel;
  StreamSubscription? _scanSub;
  StreamSubscription? _hrSub;
  StreamSubscription? _connectionStateSub;

  // UUID Standar Bluetooth SIG
  static final Guid _immediateAlertServiceUuid = Guid('1802');
  static final Guid _alertLevelCharUuid = Guid('2a06');

  int? _currentBattery;
  int? _currentBpm;

  // Auto-reconnect config
  bool _autoReconnectEnabled = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  /// Expose BPM terakhir untuk bisa diakses dari luar
  int? get currentBpm => _currentBpm;
  int? get currentBattery => _currentBattery;
  SmartwatchDeviceModel? get connectedDeviceModel => _connectedDeviceModel;

  @override
  Future<bool> isSupported() async {
    try {
      return await FlutterBluePlus.isSupported;
    } catch (e) {
      debugPrint('Error checking BLE support: $e');
      return false;
    }
  }

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    await stopScan();

    // Pastikan Bluetooth adapter menyala
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      debugPrint('⚠️ Bluetooth adapter belum aktif: $adapterState');
      // Coba nyalakan (Android only)
      try {
        await FlutterBluePlus.turnOn();
        // Tunggu sebentar agar adapter siap
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('Tidak bisa menyalakan Bluetooth otomatis: $e');
      }
    }

    final discoveredMap = <String, SmartwatchDeviceModel>{};

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final advName = r.advertisementData.advName;
        final platformName = r.device.platformName;
        final name = advName.isNotEmpty ? advName : (platformName.isNotEmpty ? platformName : '');

        // Hanya tampilkan perangkat yang memiliki nama (bukan anonym beacon)
        if (name.isNotEmpty) {
          final lower = name.toLowerCase();
          // Filter keluar komputer, laptop, TV, Printer termal, dan IoT Tuya agar tidak mengotori daftar jam
          if (lower.startsWith('laptop-') ||
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
              lower.startsWith('ty_')) {
            continue;
          }

          final id = r.device.remoteId.str;
          discoveredMap[id] = SmartwatchDeviceModel(
            id: id,
            name: name,
            brand: _detectBrand(name),
            deviceModel: name,
            macAddress: id,
            rssi: r.rssi,
            isConnected: false,
          );
        }
      }
      _scanResultsController.add(discoveredMap.values.toList());
    });

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (e) {
      debugPrint('Error starting BLE scan: $e');
    }
  }

  String _detectBrand(String deviceName) {
    final lower = deviceName.toLowerCase();
    if (lower.contains('huawei') || lower.contains('honor')) return 'huawei';
    if (lower.contains('galaxy')) return 'samsung';
    if (lower.contains('mi band') || lower.contains('xiaomi')) return 'xiaomi';
    if (lower.contains('watch') || lower.contains('band') || lower.contains('fit')) {
      return 'generic_ble';
    }
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

      // 1. Pastikan Bluetooth aktif
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint('⚠️ Bluetooth adapter belum aktif: $adapterState');
        try {
          await FlutterBluePlus.turnOn();
          final okState = await FlutterBluePlus.adapterState
              .where((s) => s == BluetoothAdapterState.on)
              .first
              .timeout(const Duration(seconds: 3));
          if (okState != BluetoothAdapterState.on) return false;
        } catch (e) {
          debugPrint('Tidak bisa menyalakan Bluetooth otomatis: $e');
          return false;
        }
      }

      // 2. Pastikan izin BluetoothConnect di Android 12+
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.bluetoothConnect.status;
        if (!status.isGranted) {
          final res = await Permission.bluetoothConnect.request();
          if (!res.isGranted) {
            debugPrint('⚠️ Izin Bluetooth Connect tidak diberikan');
            return false;
          }
        }
      }

      // 3. Disconnect existing device dulu kalau ada
      if (_connectedDevice != null) {
        try {
          await _connectionStateSub?.cancel();
          _connectionStateSub = null;
          await _hrSub?.cancel();
          _hrSub = null;
          await _connectedDevice!.disconnect();
        } catch (_) {}
      }

      final bluetoothDevice = BluetoothDevice.fromId(device.id);
      _connectedDeviceModel = device;

      // Bersihkan koneksi lama pada instance device jika ada
      try {
        if (bluetoothDevice.isConnected) {
          await bluetoothDevice.disconnect();
        }
      } catch (_) {}

      // 4. Quick Pre-Scan: bangunkan radio Bluetooth ponsel & tangkap advertisement terbaru dari smartwatch
      debugPrint('📡 Melakukan quick scan mendeteksi sinyal ${device.name} (${device.id})...');
      try {
        final foundCompleter = Completer<void>();
        final tempSub = FlutterBluePlus.scanResults.listen((results) {
          if (results.any((r) => r.device.remoteId.str == device.id)) {
            if (!foundCompleter.isCompleted) foundCompleter.complete();
          }
        });

        await FlutterBluePlus.startScan(
          withRemoteIds: [device.id],
          timeout: const Duration(seconds: 3),
          androidScanMode: AndroidScanMode.lowLatency,
        );

        await Future.any([
          foundCompleter.future,
          Future.delayed(const Duration(seconds: 3)),
        ]);

        await tempSub.cancel();
        await stopScan();
      } catch (e) {
        debugPrint('Pre-scan info: $e');
        await stopScan();
      }

      debugPrint('📡 Menghubungkan GATT ke ${device.name} (${device.id})...');

      // 5. Connect dengan mtu: null (mencegah kegagalan negosiasi MTU 512 pada chipset budget)
      // dan retry otomatis jika terjadi timeout (GATT 147)
      bool connected = false;
      try {
        await bluetoothDevice.connect(
          timeout: const Duration(seconds: 25),
          autoConnect: false,
          mtu: null,
        );
        connected = true;
      } catch (e) {
        debugPrint('⚠️ Percobaan pertama gagal ($e). Mencoba ulang setelah jeda 1.5 detik...');
        try {
          await bluetoothDevice.disconnect();
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 1500));

        // Retry kedua
        await bluetoothDevice.connect(
          timeout: const Duration(seconds: 25),
          autoConnect: false,
          mtu: null,
        );
        connected = true;
      }

      if (!connected) {
        connectionState.value = false;
        return false;
      }

      _connectedDevice = bluetoothDevice;
      _autoReconnectEnabled = true;
      _reconnectAttempts = 0;
      connectionState.value = true;

      // Setup connection state monitoring untuk auto-reconnect
      _setupConnectionStateMonitoring(bluetoothDevice, device);

      // Beri jeda 500ms agar GATT server pada smartwatch stabil
      await Future.delayed(const Duration(milliseconds: 500));

      // Temukan service & karakteristik GATT
      await _discoverAndSubscribeServices(bluetoothDevice, device);

      debugPrint('✅ Berhasil terhubung ke ${device.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error connecting BLE device ${device.id}: $e');
      connectionState.value = false;
      return false;
    }
  }

  /// Monitor status koneksi BLE dan auto-reconnect jika terputus
  void _setupConnectionStateMonitoring(BluetoothDevice btDevice, SmartwatchDeviceModel device) {
    _connectionStateSub?.cancel();
    _connectionStateSub = btDevice.connectionState.listen((state) {
      debugPrint('🔗 BLE Connection State Changed: $state');

      if (state == BluetoothConnectionState.disconnected) {
        connectionState.value = false;
        _currentBpm = null;
        _heartRateController.add(0); // Signal bahwa BPM tidak tersedia

        if (_autoReconnectEnabled) {
          debugPrint('⚠️ Koneksi terputus. Mencoba auto-reconnect...');
          _attemptReconnect(device);
        }
      } else if (state == BluetoothConnectionState.connected) {
        connectionState.value = true;
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
      }
    });
  }

  /// Auto-reconnect dengan exponential backoff
  void _attemptReconnect(SmartwatchDeviceModel device) {
    if (!_autoReconnectEnabled || _reconnectAttempts >= _maxReconnectAttempts) {
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        debugPrint('❌ Auto-reconnect gagal setelah $_maxReconnectAttempts percobaan');
        _eventController.add(SmartwatchEventModel(
          deviceId: device.id,
          eventType: SmartwatchEventType.periodicTelemetry,
          timestamp: DateTime.now(),
          triggerType: 'Koneksi Terputus - Gagal Reconnect',
        ));
      }
      return;
    }

    _reconnectAttempts++;
    // Exponential backoff: 2s, 4s, 8s, 16s, 32s
    final delay = Duration(seconds: 2 * (1 << (_reconnectAttempts - 1)));
    debugPrint('🔄 Auto-reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delay.inSeconds}s');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (!_autoReconnectEnabled) return;

      try {
        final bluetoothDevice = BluetoothDevice.fromId(device.id);
        await bluetoothDevice.connect(
          timeout: const Duration(seconds: 15),
          autoConnect: false,
          mtu: null,
        );

        _connectedDevice = bluetoothDevice;
        connectionState.value = true;

        // Re-subscribe ke GATT services
        await _discoverAndSubscribeServices(bluetoothDevice, device);
        _reconnectAttempts = 0;
        debugPrint('✅ Auto-reconnect berhasil!');
      } catch (e) {
        debugPrint('❌ Auto-reconnect attempt $_reconnectAttempts gagal: $e');
        // Coba lagi
        _attemptReconnect(device);
      }
    });
  }

  /// Discover GATT services dan subscribe ke Heart Rate & Battery
  Future<void> _discoverAndSubscribeServices(
    BluetoothDevice bluetoothDevice,
    SmartwatchDeviceModel device,
  ) async {
    // Cancel subscription HR lama
    await _hrSub?.cancel();
    _hrSub = null;

    final services = await bluetoothDevice.discoverServices();
    bool hrFound = false;
    bool batteryFound = false;

    for (final service in services) {
      final sUuid = service.uuid.toString().toLowerCase();
      debugPrint('📡 Layanan BLE ditemukan: $sUuid');

      for (final char in service.characteristics) {
        final cUuid = char.uuid.toString().toLowerCase();

        // 1. Dengar Detak Jantung (Heart Rate Measurement 0x2A37 atau service 0x180D)
        if (cUuid.contains('2a37') || (sUuid.contains('180d') && (char.properties.notify || char.properties.indicate))) {
          debugPrint('   ❤️ Menghubungkan ke Karakteristik Heart Rate: $cUuid');
          try {
            await char.setNotifyValue(true);
            hrFound = true;
          } catch (e) {
            debugPrint('Error setNotifyValue for HR: $e');
          }

          _hrSub = char.onValueReceived.listen((data) {
            debugPrint('💓 Heart Rate Data Received ($cUuid): $data');
            if (data.isNotEmpty) {
              final bpm = _parseHeartRate(data);
              if (bpm > 0) {
                _currentBpm = bpm;
                _heartRateController.add(bpm);

                // Jika terdeteksi takikardia ekstrim (> 160 BPM saat istirahat)
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

          // Coba pembacaan langsung jika properti read diizinkan
          if (char.properties.read) {
            try {
              final initial = await char.read();
              if (initial.isNotEmpty) {
                final bpm = _parseHeartRate(initial);
                if (bpm > 0) {
                  _currentBpm = bpm;
                  _heartRateController.add(bpm);
                }
              }
            } catch (_) {}
          }
        }

        // 2. Baca Level Baterai (0x2A19 atau service 0x180F)
        if (cUuid.contains('2a19') || sUuid.contains('180f')) {
          batteryFound = true;
          try {
            if (char.properties.read) {
              final val = await char.read();
              if (val.isNotEmpty) {
                _currentBattery = val.first;
              }
            }
            if (char.properties.notify) {
              await char.setNotifyValue(true);
              char.onValueReceived.listen((val) {
                if (val.isNotEmpty) {
                  _currentBattery = val.first;
                }
              });
            }
          } catch (_) {}
        }
      }
    }

    debugPrint('📊 GATT Discovery: HR=${hrFound ? "✅" : "❌"} Battery=${batteryFound ? "✅" : "❌"}');
    if (!hrFound) {
      debugPrint('⚠️ Heart Rate Service tidak ditemukan di ${device.name}. '
          'Pastikan smartwatch mendukung standar BLE Heart Rate (UUID 0x180D/0x2A37).');
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
    if (_connectedDevice == null) return;
    try {
      final services = await _connectedDevice!.discoverServices();
      for (final service in services) {
        if (service.uuid == _immediateAlertServiceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid == _alertLevelCharUuid) {
              // 2 = High Alert (vibrate & ring on watch)
              await char.write([0x02], withoutResponse: true);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error writing feedback alert to watch: $e');
    }
  }

  /// Simulasi trigger SOS dari jam tangan (untuk testing & demo)
  void simulateWatchSosTrigger(String deviceId) {
    if (_currentBpm == null) {
      debugPrint('⚠️ Simulasi SOS: Tidak ada data BPM real dari smartwatch');
    }
    _eventController.add(SmartwatchEventModel(
      deviceId: deviceId,
      eventType: SmartwatchEventType.sosButtonPressed,
      heartRate: _currentBpm,
      batteryLevel: _currentBattery,
      timestamp: DateTime.now(),
      triggerType: 'Tombol Fisik Smartwatch',
    ));
  }

  /// Simulasi deteksi jatuh dari jam tangan
  void simulateFallDetection(String deviceId) {
    if (_currentBpm == null) {
      debugPrint('⚠️ Simulasi Fall: Tidak ada data BPM real dari smartwatch');
    }
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

  /// Cek apakah sedang terhubung ke perangkat
  bool get isConnected => _connectedDevice != null && connectionState.value;

  @override
  Future<void> dispose() async {
    _autoReconnectEnabled = false;
    _reconnectTimer?.cancel();
    await stopScan();
    await _connectionStateSub?.cancel();
    await _hrSub?.cancel();
    await _eventController.close();
    await _heartRateController.close();
    await _scanResultsController.close();
    connectionState.value = false;
  }
}
