import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

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
    setState(() {
      _isScanning = true;
      _foundDevices.clear();
    });

    try {
      await _tuyaService.startBLEScan();

      // In real implementation, found devices would come through EventChannel
      // For now, show scanning state for a few seconds
      await Future.delayed(const Duration(seconds: 5));

      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Scanning selesai. Pastikan perangkat Tuya dalam mode pairing.',
            ),
            backgroundColor: Color(0xFF005C61),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _stopScan() async {
    try {
      await _tuyaService.stopBLEScan();
    } catch (_) {}
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
    if (_isScanning) _stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF005C61)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Scan Perangkat BLE',
          style: TextStyle(
            color: Color(0xFF005C61),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
    );
  }

  Widget _buildScanCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
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
                        ? const Color(0xFF005C61).withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                    size: 48,
                    color: _isScanning ? const Color(0xFF005C61) : Colors.grey,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            _isScanning ? 'Mencari perangkat...' : 'Siap untuk scan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _isScanning ? const Color(0xFF005C61) : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isScanning
                ? 'Pastikan perangkat Tuya berada dalam jangkauan Bluetooth'
                : 'Tekan tombol di bawah untuk mulai mencari perangkat Tuya terdekat',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? _stopScan : _startScan,
              icon: Icon(
                _isScanning ? Icons.stop : Icons.bluetooth_searching,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                _isScanning ? 'Berhenti Scan' : 'Mulai Scan BLE',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isScanning ? Colors.red : const Color(0xFF005C61),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'Cara Pairing Perangkat',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '1. Pastikan Bluetooth di HP aktif\n'
            '2. Tekan & tahan tombol pada perangkat Tuya selama 5 detik hingga LED berkedip\n'
            '3. Perangkat akan muncul di daftar di bawah\n'
            '4. Tekan "Hubungkan" untuk pairing',
            style: TextStyle(fontSize: 12, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundDevicesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perangkat Ditemukan (${_foundDevices.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ...List.generate(_foundDevices.length, (index) {
            final device = _foundDevices[index];
            final isPairing = _pairingDeviceId == device['id'];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sensors, color: Color(0xFF005C61)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device['name'] ?? 'Perangkat Tuya',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'ID: ${device['id'] ?? '-'}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isPairing ? null : () => _pairDevice(device),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF005C61),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                            style: TextStyle(color: Colors.white, fontSize: 12),
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
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: Color(0xFF005C61)),
          SizedBox(height: 16),
          Text(
            'Mencari perangkat BLE terdekat...',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          SizedBox(height: 4),
          Text(
            'Ini mungkin memerlukan beberapa detik',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
