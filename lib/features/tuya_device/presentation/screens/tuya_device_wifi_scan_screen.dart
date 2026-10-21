import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sahabat_sos_mobile/core/di/injection.dart';
import '../../data/services/tuya_channel_service.dart';
import '../../data/models/tuya_dp_event_model.dart';

class TuyaDeviceWifiScanScreen extends StatefulWidget {
  const TuyaDeviceWifiScanScreen({super.key});

  @override
  State<TuyaDeviceWifiScanScreen> createState() =>
      _TuyaDeviceWifiScanScreenState();
}

class _TuyaDeviceWifiScanScreenState extends State<TuyaDeviceWifiScanScreen> {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color primaryLightTeal = Color(0xFFE0F2F1);

  final _tuyaService = sl<TuyaChannelService>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPairing = false;
  bool _obscurePassword = true;
  bool _waitingForSmartLife = false;
  String _pairingStatus = '';
  String _selectedMode = 'ap'; // Default to AP mode
  String? _apToken;
  StreamSubscription<dynamic>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _eventSubscription?.cancel();
    if (_isPairing) {
      _tuyaService.stopWifiPairing();
    }
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  void _startWifiPairing() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text.trim();

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama Wi-Fi (SSID) tidak boleh kosong')),
      );
      return;
    }

    setState(() {
      _isPairing = true;
      _pairingStatus = 'Mengambil token pairing dari Tuya Cloud...';
    });

    try {
      _tuyaService.startEventListening();
      _listenForWifiEvents();

      if (_selectedMode == 'ap') {
        final tokenResult = await _tuyaService.getWifiToken();
        final token = tokenResult['token'] as String;

        setState(() {
          _apToken = token;
          _waitingForSmartLife = true;
          _pairingStatus =
              'Token berhasil didapat! ✅\n\n'
              'Langkah berikutnya:\n'
              '1. Buka Pengaturan Wi-Fi HP Anda\n'
              '2. Sambungkan ke jaringan Wi-Fi "SmartLife-XXXX"\n'
              '3. Kembali ke aplikasi Sahabat SOS ini\n'
              '4. Tekan tombol "Lanjutkan Pairing" di bawah';
        });
      } else {
        await _tuyaService.startWifiPairing(ssid, password);
        setState(() {
          _pairingStatus =
              'Mengirimkan informasi Wi-Fi ke alat SOS...\nPastikan lampu indikator berkedip cepat!';
        });
      }
    } catch (e) {
      setState(() {
        _isPairing = false;
        _pairingStatus = '';
        _waitingForSmartLife = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _startApStep2() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _waitingForSmartLife = false;
      _pairingStatus =
          'Mengonfigurasi Wi-Fi ke tombol SOS...\nProses ini membutuhkan waktu 1-2 menit...';
    });

    try {
      await _tuyaService.startApPairingWithToken(ssid, password, _apToken!);
    } catch (e) {
      setState(() {
        _isPairing = false;
        _pairingStatus = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _stopPairing() async {
    try {
      await _tuyaService.stopWifiPairing();
    } catch (_) {}
    await _eventSubscription?.cancel();
    if (mounted) {
      setState(() {
        _isPairing = false;
        _pairingStatus = '';
        _waitingForSmartLife = false;
        _apToken = null;
      });
    }
  }

  void _listenForWifiEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = _tuyaService.dpEventStream.listen((event) {
      if (!mounted) return;

      if (event.eventType == TuyaEventType.wifiPairingSuccess) {
        _onPairingSuccess();
      } else if (event.eventType == TuyaEventType.wifiPairingError) {
        final code = event.dps['error_code']?.toString() ?? 'N/A';
        final msg = event.dps['error_msg']?.toString() ?? 'Terjadi kesalahan';
        _onPairingError('$msg (code: $code)');
      }
    }, onError: (_) {});
  }

  void _onPairingSuccess() {
    if (!mounted) return;
    setState(() {
      _isPairing = false;
      _pairingStatus = '';
    });

    _eventSubscription?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: primaryLightTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: primaryTeal,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pairing Berhasil!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Perangkat SOS berhasil terhubung ke jaringan Wi-Fi dan terdaftar di akun Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF4B5563),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Selesai',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPairingError(String errorMsg) {
    if (!mounted) return;
    setState(() {
      _isPairing = false;
      _pairingStatus = '';
      _waitingForSmartLife = false;
      _apToken = null;
    });

    _eventSubscription?.cancel();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal: $errorMsg'),
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: primaryTeal),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: primaryTeal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 24, height: 24),
            const SizedBox(width: 8),
            const Text(
              'Sahabat SOS',
              style: TextStyle(
                color: primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pairing Wi-Fi',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sambungkan perangkat SOS ke koneksi Wi-Fi rumah 2.4GHz.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 18),
              _buildInstructionCard(),
              const SizedBox(height: 14),
              _buildModeSelector(),
              const SizedBox(height: 14),
              _buildWifiForm(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Metode Pairing',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isPairing
                        ? null
                        : () => setState(() => _selectedMode = 'ap'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedMode == 'ap'
                            ? primaryLightTeal
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedMode == 'ap'
                              ? primaryTeal
                              : const Color(0xFFE5E7EB),
                          width: _selectedMode == 'ap' ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.wifi,
                            color: _selectedMode == 'ap'
                                ? primaryTeal
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'AP Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: _selectedMode == 'ap'
                                  ? primaryTeal
                                  : const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '(Disarankan)',
                            style: TextStyle(
                              fontSize: 11,
                              color: _selectedMode == 'ap'
                                  ? primaryTeal
                                  : const Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isPairing
                        ? null
                        : () => setState(() => _selectedMode = 'ez'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedMode == 'ez'
                            ? primaryLightTeal
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedMode == 'ez'
                              ? primaryTeal
                              : const Color(0xFFE5E7EB),
                          width: _selectedMode == 'ez' ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.wifi,
                            color: _selectedMode == 'ez'
                                ? primaryTeal
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'EZ Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: _selectedMode == 'ez'
                                  ? primaryTeal
                                  : const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '(SmartConfig)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWifiForm() {
    return _buildCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Informasi Wi-Fi Rumah',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ssidController,
            enabled: !_isPairing,
            style: const TextStyle(color: Color(0xFF111827), fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Nama Wi-Fi (SSID)',
              labelStyle: const TextStyle(color: Color(0xFF6B7280)),
              hintText: 'Contoh: Wi-Fi_Rumah_2.4G',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              prefixIcon: const Icon(
                CupertinoIcons.wifi,
                color: Color(0xFF6B7280),
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: primaryTeal, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            enabled: !_isPairing,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Color(0xFF111827), fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Kata Sandi Wi-Fi',
              labelStyle: const TextStyle(color: Color(0xFF6B7280)),
              prefixIcon: const Icon(
                CupertinoIcons.lock_fill,
                color: Color(0xFF6B7280),
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? CupertinoIcons.eye_slash
                      : CupertinoIcons.eye,
                  color: const Color(0xFF6B7280),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: primaryTeal, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_isPairing)
            Column(
              children: [
                if (!_waitingForSmartLife) ...[
                  const CupertinoActivityIndicator(radius: 16, color: primaryTeal),
                  const SizedBox(height: 14),
                ],
                Text(
                  _pairingStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                if (!_waitingForSmartLife) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Mohon tunggu sebentar...',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
                if (_waitingForSmartLife) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _startApStep2,
                      icon: const Icon(
                        CupertinoIcons.play_arrow_solid,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Lanjutkan Pairing',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTeal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _stopPairing,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Batalkan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _startWifiPairing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _selectedMode == 'ap'
                      ? 'Mulai Pairing (AP Mode)'
                      : 'Mulai Pairing (EZ Mode)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard() {
    final isAP = _selectedMode == 'ap';

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryLightTeal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.info_circle_fill,
                  color: primaryTeal,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isAP ? 'Petunjuk Pairing AP Mode' : 'Petunjuk Pairing EZ Mode',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isAP
                ? '1. Tekan & tahan tombol alat SOS hingga lampu berkedip LAMBAT (mode AP).\n'
                  '2. Masukkan nama Wi-Fi rumah (2.4GHz) dan kata sandinya di bawah.\n'
                  '3. Tekan "Mulai Pairing".\n'
                  '4. Buka pengaturan Wi-Fi HP → sambungkan ke Wi-Fi "SmartLife-XXXX".\n'
                  '5. Kembali ke aplikasi ini dan tekan "Lanjutkan Pairing".'
                : '1. Pastikan HP terhubung ke Wi-Fi 2.4GHz.\n'
                  '2. Tekan & tahan tombol alat SOS hingga lampu berkedip CEPAT (mode EZ).\n'
                  '3. Masukkan nama Wi-Fi dan kata sandi dengan benar.\n'
                  '4. Tekan "Mulai Pairing" dan tunggu hingga selesai.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
