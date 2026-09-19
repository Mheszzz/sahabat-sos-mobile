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
          _pairingStatus = 'Mengirimkan sandi ke alat SOS...\nPastikan alat berkedip cepat!';
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
      _pairingStatus = 'Mengirimkan info Wi-Fi ke alat SOS...\nTunggu 1-2 menit...';
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
    _eventSubscription = _tuyaService.dpEventStream.listen(
      (event) {
        if (!mounted) return;
        
        if (event.eventType == TuyaEventType.wifiPairingSuccess) {
          _onPairingSuccess();
        } else if (event.eventType == TuyaEventType.wifiPairingError) {
          final code = event.dps['error_code']?.toString() ?? 'N/A';
          final msg = event.dps['error_msg']?.toString() ?? 'Unknown error';
          _onPairingError('$msg (code: $code)');
        }
      },
      onError: (_) {},
    );
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
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
                      color: const Color(0xFF005C61),
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Tutup',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Pairing Wi-Fi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF005C61)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F7FA), Color(0xFFF5F6F8), Color(0xFFE0F2F1)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInstructionCard(),
                const SizedBox(height: 20),
                _buildModeSelector(),
                const SizedBox(height: 20),
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _isPairing ? null : () => setState(() => _selectedMode = 'ap'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedMode == 'ap'
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedMode == 'ap'
                            ? Colors.black87
                            : Colors.black87.withValues(alpha: 0.3),
                        width: _selectedMode == 'ap' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          CupertinoIcons.wifi,
                          color: _selectedMode == 'ap' ? Colors.black87 : Colors.black54,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AP Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _selectedMode == 'ap' ? Colors.black87 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '(Disarankan)',
                          style: TextStyle(
                            fontSize: 10,
                            color: _selectedMode == 'ap' ? Colors.greenAccent : Colors.black54,
                            fontWeight: FontWeight.bold,
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
                  onTap: _isPairing ? null : () => setState(() => _selectedMode = 'ez'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedMode == 'ez'
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedMode == 'ez'
                            ? Colors.black87
                            : Colors.black87.withValues(alpha: 0.3),
                        width: _selectedMode == 'ez' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          CupertinoIcons.wifi,
                          color: _selectedMode == 'ez' ? Colors.black87 : Colors.black54,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'EZ Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _selectedMode == 'ez' ? Colors.black87 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '(SmartConfig)',
                          style: TextStyle(fontSize: 10, color: Colors.black54),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Informasi Wi-Fi Rumah',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
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
              prefixIcon: const Icon(CupertinoIcons.wifi, color: Colors.black54),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.black87.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.black87),
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
              prefixIcon: const Icon(CupertinoIcons.lock_fill, color: Colors.black54),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                  color: Colors.black54,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.black87.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_isPairing)
            Column(
              children: [
                if (!_waitingForSmartLife) ...[
                  const CircularProgressIndicator(color: Color(0xFF005C61)),
                  const SizedBox(height: 16),
                ],
                Text(
                  _pairingStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
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
                    icon: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white),
                    label: const Text(
                      'Lanjutkan Pairing',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF005C61),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _stopPairing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Batalkan'),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: _startWifiPairing,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005C61),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                _selectedMode == 'ap' ? 'Mulai Pairing (AP Mode)' : 'Mulai Pairing (EZ Mode)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              Icon(
                isAP ? CupertinoIcons.info_circle : CupertinoIcons.exclamationmark_triangle_fill,
                color: Colors.black87,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isAP ? 'Langkah AP Mode' : 'Langkah EZ Mode',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
            style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
          ),
        ],
      ),
    );
  }
}




