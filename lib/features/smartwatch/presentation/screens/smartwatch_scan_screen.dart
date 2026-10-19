import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/models/smartwatch_device_model.dart';
import '../../data/services/ble_smartwatch_service.dart';
import '../../data/services/huawei_wear_service.dart';
import '../../data/services/smartwatch_manager.dart';

class SmartwatchScanScreen extends StatefulWidget {
  const SmartwatchScanScreen({super.key});

  @override
  State<SmartwatchScanScreen> createState() => _SmartwatchScanScreenState();
}

class _SmartwatchScanScreenState extends State<SmartwatchScanScreen> {
  final _bleService = GetIt.instance<BleSmartwatchService>();
  final _huaweiService = GetIt.instance<HuaweiWearService>();
  final _manager = GetIt.instance<SmartwatchManager>();

  bool _isScanning = false;
  final List<SmartwatchDeviceModel> _discoveredDevices = [];
  StreamSubscription? _bleSub;
  StreamSubscription? _huaweiSub;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
  }

  Future<void> _requestPermissionsAndScan() async {
    // Izin Bluetooth & Lokasi untuk Android
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    _startScanning();
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    // 1. Dengar BLE Scan
    _bleSub = _bleService.scanResultsStream.listen((list) {
      if (!mounted) return;
      setState(() {
        for (final item in list) {
          if (!_discoveredDevices.any((d) => d.id == item.id)) {
            _discoveredDevices.add(item);
          }
        }
      });
    });

    // 2. Dengar Huawei Wear Scan
    _huaweiSub = _huaweiService.scanResultsStream.listen((list) {
      if (!mounted) return;
      setState(() {
        for (final item in list) {
          if (!_discoveredDevices.any((d) => d.id == item.id)) {
            _discoveredDevices.add(item);
          }
        }
      });
    });

    await Future.wait([
      _bleService.startScan(timeout: const Duration(seconds: 12)),
      _huaweiService.startScan(timeout: const Duration(seconds: 12)),
    ]);

    Future.delayed(const Duration(seconds: 12), () {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    });
  }

  Future<void> _pairDevice(SmartwatchDeviceModel device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(radius: 14),
                SizedBox(height: 16),
                Text('Menyambungkan Smartwatch...'),
              ],
            ),
          ),
        ),
      ),
    );

    final ok = await _manager.pairAndConnectDevice(device);
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil menyambungkan ke ${device.name}!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyambungkan. Pastikan Bluetooth aktif dan jam dalam jarak dekat.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _huaweiSub?.cancel();
    _bleService.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text(
          'Cari Smartwatch',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: _isScanning
                ? const CupertinoActivityIndicator(radius: 10)
                : const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScanning,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: Colors.blue.withValues(alpha: 0.08),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pastikan Bluetooth aktif pada ponsel dan jam tangan (Huawei Watch, Wear OS, atau BLE) berada di sekitar Anda.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _discoveredDevices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isScanning) ...[
                          const CupertinoActivityIndicator(radius: 16),
                          const SizedBox(height: 16),
                          const Text(
                            'Memindai jam tangan di sekitar...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ] else ...[
                          const Icon(Icons.watch_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            'Belum ada smartwatch terdeteksi',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _startScanning,
                            icon: const Icon(Icons.search),
                            label: const Text('Pindai Ulang'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = _discoveredDevices[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.watch,
                              color: Color(0xFFE53935),
                            ),
                          ),
                          title: Text(
                            device.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            '${device.brandDisplay} • Sinyal: ${device.rssi ?? -60} dBm',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _pairDevice(device),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: const Text('Sambungkan'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
