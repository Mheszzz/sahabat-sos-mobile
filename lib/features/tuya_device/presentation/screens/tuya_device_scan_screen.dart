import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import '../../data/services/tuya_channel_service.dart';

class TuyaDeviceScanScreen extends StatefulWidget {
  const TuyaDeviceScanScreen({super.key});

  @override
  State<TuyaDeviceScanScreen> createState() => _TuyaDeviceScanScreenState();
}

class _TuyaDeviceScanScreenState extends State<TuyaDeviceScanScreen>
    with SingleTickerProviderStateMixin {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color primaryLightTeal = Color(0xFFE0F2F1);

  final _tuyaService = sl<TuyaChannelService>();

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
    _pulseAnimation = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    unawaited(
      AccessibilityService.instance
          .speak('Halaman pemindaian perangkat Bluetooth SOS'),
    );
  }

  Future<void> _startScan() async {
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

    AccessibilityService.instance.hapticSelection();
    unawaited(
      AccessibilityService.instance
          .speak('Memulai pemindaian perangkat Bluetooth'),
    );

    setState(() {
      _isScanning = true;
      _foundDevices.clear();
    });

    try {
      _tuyaService.startEventListening();
      _listenForBleDevices();
      await _tuyaService.startBLEScan();

      // Auto-stop after 60 seconds
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted && _isScanning) {
          _stopScan();
          AccessibilityService.instance.hapticMedium();
          unawaited(
            AccessibilityService.instance
                .speak('Pemindaian selesai. Pastikan perangkat dalam mode pairing.'),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Scanning selesai. Pastikan perangkat Tuya dalam mode pairing.',
              ),
              backgroundColor: primaryTeal,
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        AccessibilityService.instance.hapticMedium();
        unawaited(
          AccessibilityService.instance.speak('Gagal memulai pemindaian: $e'),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _listenForBleDevices() {
    _scanSubscription?.cancel();
    _scanSubscription = _tuyaService.bleDeviceStream.listen(
      (event) {
        if (!mounted) return;
        final deviceInfo = {
          'id': event.deviceId,
          'name': event.dps['name'] ?? event.deviceId,
          'product_id': event.dps['product_id'] ?? '',
          'rssi': event.dps['rssi'],
        };
        final exists = _foundDevices.any((d) => d['id'] == deviceInfo['id']);
        if (!exists) {
          AccessibilityService.instance.hapticSelection();
          unawaited(
            AccessibilityService.instance
                .speak('Ditemukan perangkat ${deviceInfo['name']}'),
          );
          setState(() {
            _foundDevices.add(deviceInfo);
          });
        }
      },
      onError: (error) {},
    );
  }

  Future<void> _stopScan() async {
    AccessibilityService.instance.hapticSelection();
    unawaited(AccessibilityService.instance.speak('Pemindaian dihentikan'));
    try {
      await _tuyaService.stopBLEScan();
    } catch (_) {}
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _pairDevice(Map<String, dynamic> device) async {
    final deviceName = device['name'] ?? 'Perangkat Tuya';
    AccessibilityService.instance.hapticSelection();
    unawaited(
      AccessibilityService.instance.speak('Menghubungkan ke $deviceName'),
    );
    setState(() => _pairingDeviceId = device['id']);

    try {
      await _tuyaService.pairDevice(device['id'] ?? '');
      if (mounted) {
        AccessibilityService.instance.hapticSelection();
        unawaited(
          AccessibilityService.instance
              .speak('Berhasil terhubung dengan $deviceName'),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil pairing dengan $deviceName'),
            backgroundColor: primaryTeal,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AccessibilityService.instance.hapticMedium();
        unawaited(
          AccessibilityService.instance
              .speak('Gagal menghubungkan ke $deviceName: $e'),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal pairing: $e'),
            backgroundColor: const Color(0xFFDC2626),
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

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    bool isHighContrast = false,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(16),
        border: AccessibleColors.cardBorder(isHighContrast),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isHighContrast ? 0.3 : 0.04,
            ),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;
        final currentBg =
            isHighContrast ? Colors.black : const Color(0xFFF8FAFC);
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
        final textPrimary = AccessibleColors.textPrimary(isHighContrast);
        final textSecondary = AccessibleColors.textSecondary(isHighContrast);

        return Scaffold(
          backgroundColor: currentBg,
          appBar: AppBar(
            backgroundColor: currentBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: tealColor),
            leading: IconButton(
              icon: Icon(CupertinoIcons.back, color: tealColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            centerTitle: false,
            titleSpacing: 0,
            title: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 24, height: 24),
                const SizedBox(width: 8),
                Text(
                  'Sahabat SOS',
                  style: TextStyle(
                    color: tealColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Scan Perangkat BLE',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pindai perangkat Bluetooth Low Energy di sekitar Anda.',
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Scan Animation / Button
                  _buildScanCard(isHighContrast),
                  const SizedBox(height: 14),

                  // Instructions
                  _buildInstructionCard(isHighContrast),
                  const SizedBox(height: 14),

                  // Found Devices
                  if (_foundDevices.isNotEmpty)
                    _buildFoundDevicesCard(isHighContrast),

                  // Empty state during scan
                  if (_isScanning && _foundDevices.isEmpty)
                    _buildScanningIndicator(isHighContrast),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScanCard(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final textPrimary = AccessibleColors.textPrimary(isHighContrast);
    final textSecondary = AccessibleColors.textSecondary(isHighContrast);

    return _buildCard(
      isHighContrast: isHighContrast,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isScanning ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _isScanning
                        ? (isHighContrast
                            ? const Color(0xFF1E3A34)
                            : primaryLightTeal)
                        : (isHighContrast
                            ? const Color(0xFF1E2430)
                            : const Color(0xFFF3F4F6)),
                    shape: BoxShape.circle,
                    border: isHighContrast
                        ? Border.all(
                            color: _isScanning
                                ? const Color(0xFF80CBC4)
                                : const Color(0xFF4B5563),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Icon(
                    CupertinoIcons.bluetooth,
                    size: 42,
                    color: _isScanning
                        ? tealColor
                        : (isHighContrast
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF9CA3AF)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            _isScanning
                ? 'Mencari perangkat... (${_foundDevices.length} ditemukan)'
                : 'Siap Memindai',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: _isScanning ? tealColor : textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isScanning
                ? 'Pastikan perangkat Tuya berada dalam jangkauan Bluetooth HP'
                : 'Tekan tombol di bawah untuk mulai memindai tombol darurat terdekat',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? _stopScan : _startScan,
              icon: Icon(
                _isScanning
                    ? CupertinoIcons.stop_fill
                    : CupertinoIcons.bluetooth,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                _isScanning ? 'Hentikan Pemindaian' : 'Mulai Pindai BLE',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanning
                    ? (isHighContrast
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFDC2626))
                    : (isHighContrast
                        ? const Color(0xFF00897B)
                        : primaryTeal),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isHighContrast
                      ? BorderSide(
                          color: _isScanning
                              ? const Color(0xFFF87171)
                              : const Color(0xFF80CBC4),
                          width: 1.5,
                        )
                      : BorderSide.none,
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final textPrimary = AccessibleColors.textPrimary(isHighContrast);
    final textSecondary = AccessibleColors.textSecondary(isHighContrast);

    return _buildCard(
      isHighContrast: isHighContrast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? const Color(0xFF1E3A34)
                      : primaryLightTeal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.info_circle_fill,
                  color: tealColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Petunjuk Pairing Bluetooth',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '1. Pastikan Bluetooth di ponsel sudah menyala.\n'
            '2. Tekan & tahan tombol darurat Tuya selama 5 detik hingga lampu indikator berkedip.\n'
            '3. Perangkat akan terdeteksi pada daftar di bawah.\n'
            '4. Ketuk "Hubungkan" untuk menyelesaikan pairing.',
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundDevicesCard(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final textPrimary = AccessibleColors.textPrimary(isHighContrast);
    final textSecondary = AccessibleColors.textSecondary(isHighContrast);
    final itemBg = isHighContrast
        ? const Color(0xFF1E2430)
        : const Color(0xFFF9FAFB);
    final itemBorder = isHighContrast
        ? const Color(0xFF4B5563)
        : const Color(0xFFE5E7EB);

    return _buildCard(
      isHighContrast: isHighContrast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perangkat Ditemukan (${_foundDevices.length})',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(_foundDevices.length, (index) {
            final device = _foundDevices[index];
            final isPairing = _pairingDeviceId == device['id'];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: itemBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: itemBorder,
                  width: isHighContrast ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isHighContrast
                          ? const Color(0xFF1E3A34)
                          : primaryLightTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.antenna_radiowaves_left_right,
                      color: tealColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device['name'] ?? 'Perangkat Tuya',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${device['id'] ?? '-'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                        if (device['rssi'] != null)
                          Text(
                            'Sinyal: ${device['rssi']} dBm',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isPairing ? null : () => _pairDevice(device),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isHighContrast
                          ? const Color(0xFF00897B)
                          : primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isHighContrast
                            ? const BorderSide(
                                color: Color(0xFF80CBC4), width: 1.5)
                            : BorderSide.none,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      elevation: 0,
                    ),
                    child: isPairing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CupertinoActivityIndicator(
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Hubungkan',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
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

  Widget _buildScanningIndicator(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final textPrimary = AccessibleColors.textPrimary(isHighContrast);
    final textSecondary = AccessibleColors.textSecondary(isHighContrast);

    return _buildCard(
      isHighContrast: isHighContrast,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          CupertinoActivityIndicator(radius: 16, color: tealColor),
          const SizedBox(height: 16),
          Text(
            'Mencari perangkat BLE terdekat...',
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mohon dekatkan perangkat dengan HP Anda',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
