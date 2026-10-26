import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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
  static const Color primaryTeal = Color(0xFF00695C);

  final _bleService = GetIt.instance<BleSmartwatchService>();
  final _huaweiService = GetIt.instance<HuaweiWearService>();
  final _manager = GetIt.instance<SmartwatchManager>();

  bool _isScanning = false;
  bool _permissionDenied = false;
  bool _bluetoothOff = false;
  final List<SmartwatchDeviceModel> _discoveredDevices = [];
  StreamSubscription? _bleSub;
  StreamSubscription? _huaweiSub;
  StreamSubscription? _adapterStateSub;

  @override
  void initState() {
    super.initState();
    _monitorBluetoothAdapter();
    _requestPermissionsAndScan();
  }

  /// Monitor status Bluetooth adapter (on/off)
  void _monitorBluetoothAdapter() {
    _adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      setState(() {
        _bluetoothOff = state != BluetoothAdapterState.on;
      });

      // Auto-scan saat Bluetooth dinyalakan
      if (state == BluetoothAdapterState.on && !_isScanning && _discoveredDevices.isEmpty) {
        _startScanning();
      }
    });
  }

  Future<void> _requestPermissionsAndScan() async {
    // Izin Bluetooth & Lokasi untuk Android
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // Cek apakah ada permission yang ditolak permanen
    final allGranted = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );

    if (!allGranted) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
        });
      }
      return;
    }

    setState(() {
      _permissionDenied = false;
    });

    _startScanning();
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;

    // Cek apakah Bluetooth adapter aktif
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        if (mounted) {
          setState(() {
            _bluetoothOff = true;
          });
        }
        // Coba nyalakan otomatis (Android)
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
        return;
      }
    } catch (e) {
      debugPrint('Error checking adapter state: $e');
    }

    setState(() {
      _isScanning = true;
      _bluetoothOff = false;
      _discoveredDevices.clear();
    });

    // 1. Dengar BLE Scan
    _bleSub?.cancel();
    _bleSub = _bleService.scanResultsStream.listen((list) {
      if (!mounted) return;
      setState(() {
        for (final item in list) {
          final existingIdx = _discoveredDevices.indexWhere((d) => d.id == item.id);
          if (existingIdx == -1) {
            _discoveredDevices.add(item);
          } else {
            // Update RSSI kalau sudah ada
            _discoveredDevices[existingIdx] = item;
          }
        }
        // Sort by signal strength (closest first)
        _discoveredDevices.sort((a, b) => (b.rssi ?? -100).compareTo(a.rssi ?? -100));
      });
    });

    // 2. Dengar Huawei Wear Scan (perangkat yang ter-pairing di Huawei Health)
    _huaweiSub?.cancel();
    _huaweiSub = _huaweiService.scanResultsStream.listen((list) {
      if (!mounted) return;
      setState(() {
        for (final item in list) {
          final existingIdx = _discoveredDevices.indexWhere((d) => d.id == item.id);
          if (existingIdx == -1) {
            _discoveredDevices.insert(0, item);
          } else {
            _discoveredDevices[existingIdx] = item;
          }
        }
      });
    });

    try {
      await Future.wait([
        _bleService.startScan(timeout: const Duration(seconds: 15)),
        _huaweiService.startScan(timeout: const Duration(seconds: 15)),
      ]);
    } catch (e) {
      debugPrint('Error during scan: $e');
      if (mounted) {
        setState(() => _bluetoothOff = true);
      }
    }

    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    });
  }

  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
    BorderRadius? borderRadius,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withValues(alpha: 0.65),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _pairDevice(SmartwatchDeviceModel device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoActivityIndicator(radius: 16, color: primaryTeal),
                const SizedBox(height: 18),
                Text(
                  'Menyambungkan ke ${device.name}...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String?>(
                  valueListenable: _manager.connectionStatus,
                  builder: (context, status, _) {
                    return Text(
                      status ?? 'Memulai koneksi Bluetooth...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    );
                  },
                ),
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
          backgroundColor: primaryTeal,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyambungkan ke ${device.name}. '
            'Pastikan layar jam MENYALA dan aplikasi bawaan (Vivan/GloryFit) sudah ditutup.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _signalLabel(int? rssi) {
    if (rssi == null) return 'Tidak diketahui';
    if (rssi >= -50) return 'Sangat Kuat';
    if (rssi >= -70) return 'Kuat';
    if (rssi >= -85) return 'Sedang';
    return 'Lemah';
  }

  Color _signalColor(int? rssi) {
    if (rssi == null) return Colors.grey;
    if (rssi >= -50) return Colors.green;
    if (rssi >= -70) return Colors.green.shade400;
    if (rssi >= -85) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _huaweiSub?.cancel();
    _adapterStateSub?.cancel();
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
        ),
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: primaryTeal),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: primaryTeal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: _isScanning
                ? const CupertinoActivityIndicator(radius: 11, color: primaryTeal)
                : const Icon(CupertinoIcons.arrow_clockwise, color: primaryTeal, size: 20),
            onPressed: _isScanning ? null : _startScanning,
            tooltip: 'Pindai Ulang',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Info Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _buildGlassContainer(
              color: primaryTeal.withValues(alpha: 0.08),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryTeal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.info_circle_fill, color: primaryTeal, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Pastikan layar jam MENYALA dan Bluetooth aktif. Buka menu Detak Jantung di jam agar sensor aktif.',
                      style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Warning: Bluetooth Mati
          if (_bluetoothOff)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _buildGlassContainer(
                color: const Color(0xFFFEF2F2).withValues(alpha: 0.9),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.bluetooth, color: Color(0xFFDC2626), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bluetooth Tidak Aktif',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Aktifkan Bluetooth dari pengaturan ponsel untuk memindai smartwatch.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await FlutterBluePlus.turnOn();
                              } catch (_) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Mohon aktifkan Bluetooth secara manual dari pengaturan.'),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(CupertinoIcons.bluetooth, size: 14),
                            label: const Text('Aktifkan Bluetooth', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Warning: Permission Denied
          if (_permissionDenied)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _buildGlassContainer(
                color: const Color(0xFFFFF7ED).withValues(alpha: 0.9),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Color(0xFFEA580C), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Izin Diperlukan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF9A3412),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Izin Bluetooth dan Lokasi diperlukan untuk memindai smartwatch.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => openAppSettings(),
                            icon: const Icon(CupertinoIcons.gear_alt, size: 14),
                            label: const Text('Buka Pengaturan', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA580C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Device List
          Expanded(
            child: _discoveredDevices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isScanning) ...[
                          const CupertinoActivityIndicator(radius: 16, color: primaryTeal),
                          const SizedBox(height: 16),
                          const Text(
                            'Memindai jam tangan di sekitar...',
                            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Pastikan smartwatch menyala dan Bluetooth aktif',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ] else if (!_permissionDenied && !_bluetoothOff) ...[
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.watch_outlined, size: 48, color: Colors.grey),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Belum ada smartwatch terdeteksi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 6),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 48),
                            child: Text(
                              'Pastikan jam tangan Anda menyala, Bluetooth aktif, dan berada dalam jarak dekat (< 3 meter).',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _startScanning,
                            icon: const Icon(CupertinoIcons.search, size: 16),
                            label: const Text('Pindai Ulang', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTeal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Text(
                          '${_discoveredDevices.length} perangkat ditemukan',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _discoveredDevices.length,
                          itemBuilder: (context, index) {
                            final device = _discoveredDevices[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildGlassContainer(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: primaryTeal.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.watch,
                                        color: primaryTeal,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            device.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'MAC: ${device.id}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Text(
                                                device.brandDisplay,
                                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: _signalColor(device.rssi),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Sinyal: ${_signalLabel(device.rssi)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _signalColor(device.rssi),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _pairDevice(device),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryTeal,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      child: const Text('Sambungkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
