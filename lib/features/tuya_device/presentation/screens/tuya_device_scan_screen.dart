import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/services/tuya_channel_service.dart';

class TuyaDeviceScanScreen extends StatefulWidget {
  const TuyaDeviceScanScreen({super.key});

  @override
  State<TuyaDeviceScanScreen> createState() => _TuyaDeviceScanScreenState();
}

class _TuyaDeviceScanScreenState extends State<TuyaDeviceScanScreen>
    with SingleTickerProviderStateMixin {
  final _tuyaService = GetIt.instance<TuyaChannelService>();

  bool _isScanning = false;
  final List<Map<String, dynamic>> _foundDevices = [];
  String? _pairingDeviceId;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription<dynamic>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startScan() async {
    // Request permissions first
    final permissionsToRequest = [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];
    
    for (final p in permissionsToRequest) {
      final status = await p.status;
      if (!status.isGranted) {
        await p.request();
      }
    }

    // If running on Android 12+, bluetoothScan is required. On older devices, location is required.
    // It's safe to proceed if they aren't explicitly permanently denied.
    
    setState(() {
      _isScanning = true;
      _foundDevices.clear();
    });

    try {
      // Start listening for BLE device discoveries via EventChannel
      _tuyaService.startEventListening();

      // Listen for BLE device found events on bleDeviceStream
      _listenForBleDevices();

      // Start actual BLE scan on native side
      await _tuyaService.startBLEScan();

      // Auto-stop after 60 seconds
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted && _isScanning) {
          _stopScan();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Scanning selesai. Pastikan perangkat Tuya dalam mode pairing.',
              ),
              backgroundColor: Color(0xFF005C61),
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Listen for BLE device discovery events from native via EventChannel
  void _listenForBleDevices() {
    _scanSubscription?.cancel();
    _scanSubscription = _tuyaService.bleDeviceStream.listen(
      (event) {
        if (!mounted) return;
        // Add discovered BLE device to the list
        final deviceInfo = {
          'id': event.deviceId,
          'name': event.dps['name'] ?? event.deviceId,
          'product_id': event.dps['product_id'] ?? '',
          'rssi': event.dps['rssi'],
        };
        // Avoid duplicates
        final exists = _foundDevices.any((d) => d['id'] == deviceInfo['id']);
        if (!exists) {
          setState(() {
            _foundDevices.add(deviceInfo);
          });
        }
      },
      onError: (error) {
        // Errors during scan are non-critical
      },
    );
  }

  Future<void> _stopScan() async {
    try {
      await _tuyaService.stopBLEScan();
    } catch (_) {}
    _scanSubscription?.cancel();
    _scanSubscription = null;
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _pairDevice(Map<String, dynamic> device) async {
    final deviceName = device['name'] ?? 'Unknown';
    setState(() => _pairingDeviceId = device['id']);

    try {
      await _tuyaService.pairDevice(device['id'] ?? '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Berhasil pairing dengan $deviceName'),
            backgroundColor: const Color(0xFF005C61),
          ),
        );
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal pairing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pairingDeviceId = null);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanSubscription?.cancel();
    if (_isScanning) _stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Color(0xFF00695C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 24, height: 24),
            const SizedBox(width: 8),
            const Text(
              'Sahabat SOS',
              style: TextStyle(
                color: Color(0xFF00695C),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0F7FA), // Light blue/teal
              Color(0xFFF5F6F8), // Greyish white
              Color(0xFFE0F2F1), // Light teal
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Scan Perangkat BLE',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                // Scan Animation / Button
                _buildScanCard(),
                const SizedBox(height: 16),

                // Instructions
                _buildInstructionCard(),
                const SizedBox(height: 16),

                // Found Devices
                if (_foundDevices.isNotEmpty) _buildFoundDevicesCard(),

                // Empty state during scan
                if (_isScanning && _foundDevices.isEmpty) _buildScanningIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildScanCard() {
    return _buildGlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isScanning ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _isScanning
                        ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                        : const Color(0xFFF2F2F7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isScanning ? CupertinoIcons.bluetooth : CupertinoIcons.bluetooth,
                    size: 48,
                    color: _isScanning ? const Color(0xFF007AFF) : Colors.black54,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            _isScanning
                ? 'Mencari perangkat... (${_foundDevices.length} ditemukan)'
                : 'Siap untuk scan',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: _isScanning ? const Color(0xFF007AFF) : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isScanning
                ? 'Pastikan perangkat Tuya berada dalam jangkauan Bluetooth'
                : 'Tekan tombol di bawah untuk mulai mencari perangkat Tuya terdekat',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? _stopScan : _startScan,
              icon: Icon(
                _isScanning ? CupertinoIcons.stop_fill : CupertinoIcons.bluetooth,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                _isScanning ? 'Berhenti Scan' : 'Mulai Scan BLE',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isScanning ? const Color(0xFFFF3B30) : const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.info_circle_fill, color: Color(0xFF34C759), size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cara Pairing Perangkat',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '1. Pastikan Bluetooth di HP aktif\n'
            '2. Tekan & tahan tombol pada perangkat Tuya selama 5 detik hingga LED berkedip\n'
            '3. Perangkat akan muncul di daftar di bawah\n'
            '4. Tekan "Hubungkan" untuk pairing',
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundDevicesCard() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perangkat Ditemukan (${_foundDevices.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          ...List.generate(_foundDevices.length, (index) {
            final device = _foundDevices[index];
            final isPairing = _pairingDeviceId == device['id'];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.antenna_radiowaves_left_right, color: Colors.black87, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device['name'] ?? 'Perangkat Tuya',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${device['id'] ?? '-'}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        if (device['rssi'] != null)
                          Text(
                            'Signal: ${device['rssi']} dBm',
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isPairing ? null : () => _pairDevice(device),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      elevation: 0,
                    ),
                    child: isPairing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Hubungkan',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return _buildGlassContainer(
      padding: const EdgeInsets.all(32),
      child: const Column(
        children: [
          CircularProgressIndicator(color: Color(0xFF007AFF)),
          SizedBox(height: 20),
          Text(
            'Mencari perangkat BLE terdekat...',
            style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 6),
          Text(
            'Ini mungkin memerlukan beberapa detik',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}




