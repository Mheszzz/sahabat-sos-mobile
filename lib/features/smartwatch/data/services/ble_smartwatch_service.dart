import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/smartwatch_device_model.dart';
import '../models/smartwatch_event_model.dart';
import 'smartwatch_service.dart';

class BleSmartwatchService implements SmartwatchService {
  @override
  String get protocolName => 'Universal BLE GATT';

  final _eventController = StreamController<SmartwatchEventModel>.broadcast();
  final _heartRateController = StreamController<int>.broadcast();
  final _scanResultsController = StreamController<List<SmartwatchDeviceModel>>.broadcast();

  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSub;
  StreamSubscription? _hrSub;

  // UUID Standar Bluetooth SIG
  static final Guid _heartRateServiceUuid = Guid('180d');
  static final Guid _heartRateCharUuid = Guid('2a37');
  static final Guid _batteryServiceUuid = Guid('180f');
  static final Guid _batteryCharUuid = Guid('2a19');
  static final Guid _immediateAlertServiceUuid = Guid('1802');
  static final Guid _alertLevelCharUuid = Guid('2a06');

  int? _currentBattery;
  int? _currentBpm;

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

    final discoveredMap = <String, SmartwatchDeviceModel>{};

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final advName = r.advertisementData.advName;
        final platformName = r.device.platformName;
        final name = advName.isNotEmpty ? advName : (platformName.isNotEmpty ? platformName : '');

        // Hanya tampilkan perangkat yang memiliki nama (bukan anonym beacon)
        if (name.isNotEmpty) {
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
    if (lower.contains('watch') || lower.contains('band') || lower.contains('galaxy') || lower.contains('fit')) {
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
      final bluetoothDevice = BluetoothDevice.fromId(device.id);

      await bluetoothDevice.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = bluetoothDevice;

      // Temukan service & karakteristik GATT
      final services = await bluetoothDevice.discoverServices();
      for (final service in services) {
        // 1. Dengar Detak Jantung (Heart Rate Measurement 0x2A37)
        if (service.uuid == _heartRateServiceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid == _heartRateCharUuid) {
              await char.setNotifyValue(true);
              _hrSub = char.lastValueStream.listen((data) {
                if (data.isNotEmpty) {
                  final bpm = _parseHeartRate(data);
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
              });
            }
          }
        }

        // 2. Baca Level Baterai (0x2A19)
        if (service.uuid == _batteryServiceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid == _batteryCharUuid) {
              try {
                final val = await char.read();
                if (val.isNotEmpty) {
                  _currentBattery = val.first;
                }
              } catch (_) {}
            }
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error connecting BLE device ${device.id}: $e');
      return false;
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
    try {
      await _hrSub?.cancel();
      _hrSub = null;
      if (_connectedDevice != null && _connectedDevice!.remoteId.str == deviceId) {
        await _connectedDevice!.disconnect();
      }
      _connectedDevice = null;
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
    _eventController.add(SmartwatchEventModel(
      deviceId: deviceId,
      eventType: SmartwatchEventType.sosButtonPressed,
      heartRate: _currentBpm ?? 92,
      batteryLevel: _currentBattery ?? 80,
      timestamp: DateTime.now(),
      triggerType: 'Tombol Fisik Smartwatch',
    ));
  }

  /// Simulasi deteksi jatuh dari jam tangan
  void simulateFallDetection(String deviceId) {
    _eventController.add(SmartwatchEventModel(
      deviceId: deviceId,
      eventType: SmartwatchEventType.fallDetected,
      heartRate: _currentBpm ?? 115,
      batteryLevel: _currentBattery ?? 80,
      fallDetected: true,
      timestamp: DateTime.now(),
      triggerType: 'Sensor Deteksi Jatuh Smartwatch',
    ));
  }

  @override
  Future<void> dispose() async {
    await stopScan();
    await _hrSub?.cancel();
    await _eventController.close();
    await _heartRateController.close();
    await _scanResultsController.close();
  }
}
