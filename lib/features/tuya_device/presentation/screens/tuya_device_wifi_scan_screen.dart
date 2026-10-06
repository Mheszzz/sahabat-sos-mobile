import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/services/tuya_channel_service.dart';
import '../../data/models/tuya_dp_event_model.dart';

class TuyaDeviceWifiScanScreen extends StatefulWidget {
  const TuyaDeviceWifiScanScreen({super.key});

  @override
  State<TuyaDeviceWifiScanScreen> createState() =>
      _TuyaDeviceWifiScanScreenState();
}

class _TuyaDeviceWifiScanScreenState extends State<TuyaDeviceWifiScanScreen> {
  final _tuyaService = GetIt.instance<TuyaChannelService>();
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
      _pairingStatus = 'Mengambil token dari Tuya Cloud...';
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
              'Sekarang:\n'
              '1. Buka Pengaturan Wi-Fi HP\n'
              '2. Sambung ke jaringan "SmartLife-XXXX"\n'
              '3. Kembali ke sini\n'
              '4. Tekan tombol "Lanjutkan Pairing" di bawah';
        });
      } else {
        await _tuyaService.startWifiPairing(ssid, password);
        setState(() {
          _pairingStatus =
              'Mengirimkan sandi ke alat SOS...\nPastikan alat berkedip cepat!';
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
          'Mengirimkan info Wi-Fi ke alat SOS...\nTunggu 1-2 menit...';
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _stopPairing() async {
    try {
      await _tuyaService.stopWifiPairing();
    } catch (_) {}
    _eventSubscription?.cancel();
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
        final msg = event.dps['error_msg']?.toString() ?? 'Unknown error';
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
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: CupertinoColors.activeGreen,
                size: 72,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sukses!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Alat SOS berhasil terhubung ke Wi-Fi dan terdaftar ke akun Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Tutup',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pairing Wi-Fi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                _buildInstructionCard(),
                const SizedBox(height: 16),
                _buildModeSelector(),
                const SizedBox(height: 16),
                _buildWifiForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Mode Pairing',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _isPairing
                      ? null
                      : () => setState(() => _selectedMode = 'ap'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedMode == 'ap'
                          ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                          : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedMode == 'ap'
                            ? const Color(0xFF007AFF)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          CupertinoIcons.wifi,
                          color: _selectedMode == 'ap'
                              ? const Color(0xFF007AFF)
                              : Colors.black54,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AP Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _selectedMode == 'ap'
                                ? const Color(0xFF007AFF)
                                : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '(Disarankan)',
                          style: TextStyle(
                            fontSize: 11,
                            color: _selectedMode == 'ap'
                                ? const Color(0xFF34C759)
                                : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _isPairing
                      ? null
                      : () => setState(() => _selectedMode = 'ez'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedMode == 'ez'
                          ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                          : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedMode == 'ez'
                            ? const Color(0xFF007AFF)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          CupertinoIcons.wifi,
                          color: _selectedMode == 'ez'
                              ? const Color(0xFF007AFF)
                              : Colors.black54,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'EZ Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _selectedMode == 'ez'
                                ? const Color(0xFF007AFF)
                                : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '(SmartConfig)',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
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
    return _buildGlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Informasi Wi-Fi Rumah',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ssidController,
            enabled: !_isPairing,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Nama Wi-Fi (SSID)',
              labelStyle: const TextStyle(color: Colors.black54),
              hintText: 'Contoh: Indihome_Rumah',
              hintStyle: const TextStyle(color: Colors.black38),
              prefixIcon: const Icon(
                CupertinoIcons.wifi,
                color: Colors.black54,
              ),
              filled: true,
              fillColor: const Color(0xFFF2F2F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF007AFF)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            enabled: !_isPairing,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Password Wi-Fi',
              labelStyle: const TextStyle(color: Colors.black54),
              prefixIcon: const Icon(
                CupertinoIcons.lock_fill,
                color: Colors.black54,
              ),
              filled: true,
              fillColor: const Color(0xFFF2F2F7),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? CupertinoIcons.eye_slash
                      : CupertinoIcons.eye,
                  color: Colors.black54,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF007AFF)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_isPairing)
            Column(
              children: [
                if (!_waitingForSmartLife) ...[
                  const CircularProgressIndicator(color: Color(0xFF007AFF)),
                  const SizedBox(height: 16),
                ],
                Text(
                  _pairingStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!_waitingForSmartLife) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Proses ini memakan waktu 1-2 menit...',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                if (_waitingForSmartLife) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _startApStep2,
                    icon: const Icon(
                      CupertinoIcons.play_arrow_solid,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Lanjutkan Pairing',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _stopPairing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF3B30),
                    side: const BorderSide(color: Color(0xFFFF3B30)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Batalkan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: _startWifiPairing,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                _selectedMode == 'ap'
                    ? 'Mulai Pairing (AP Mode)'
                    : 'Mulai Pairing (EZ Mode)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard() {
    final isAP = _selectedMode == 'ap';
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAP
                      ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                      : const Color(0xFFFF9500).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isAP
                      ? CupertinoIcons.info_circle_fill
                      : CupertinoIcons.exclamationmark_triangle_fill,
                  color: isAP
                      ? const Color(0xFF007AFF)
                      : const Color(0xFFFF9500),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isAP ? 'Langkah AP Mode' : 'Langkah EZ Mode',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isAP
                ? '1. Tekan & tahan tombol alat SOS sampai lampunya berkedip LAMBAT (mode AP).\n'
                      '2. Masukkan nama Wi-Fi rumah dan password di bawah.\n'
                      '3. Tekan "Mulai Pairing".\n'
                      '4. Buka pengaturan Wi-Fi HP → Sambung ke jaringan "SmartLife-XXXX".\n'
                      '5. Kembali ke aplikasi ini dan tunggu hingga selesai.'
                : '1. Hubungkan HP Anda ke Wi-Fi 2.4GHz.\n'
                      '2. Tekan & tahan tombol alat SOS sampai lampunya berkedip SANGAT CEPAT (mode EZ).\n'
                      '3. Jika berkedip lambat, tekan & tahan lagi sampai berkedip cepat.\n'
                      '4. Masukkan nama Wi-Fi dan password dengan teliti (huruf besar/kecil berpengaruh).',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
