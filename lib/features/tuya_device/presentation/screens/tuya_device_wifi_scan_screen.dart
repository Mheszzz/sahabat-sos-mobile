import 'dart:async';

import 'package:flutter/material.dart';
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
  String _pairingStatus = '';
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
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    // Wi-Fi scanning (to get current SSID if we wanted to auto-fill) 
    // and Tuya Wi-Fi activation often require Location permissions on Android.
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
      _pairingStatus = 'Menghubungkan ke Tuya Cloud...';
    });

    try {
      // Start listening to events from native (success/error)
      _tuyaService.startEventListening();
      _listenForWifiEvents();

      await _tuyaService.startWifiPairing(ssid, password);
      
      setState(() {
        _pairingStatus = 'Mengirimkan sandi ke alat SOS...\nPastikan alat berkedip cepat!';
      });
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

  void _listenForWifiEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = _tuyaService.dpEventStream.listen(
      (event) {
        if (!mounted) return;
        
        if (event.eventType == TuyaEventType.wifiPairingSuccess) {
          _onPairingSuccess();
        } else if (event.eventType == TuyaEventType.wifiPairingError) {
          _onPairingError(event.dps['error_msg']?.toString() ?? 'Error');
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
      builder: (context) => AlertDialog(
        title: const Text('Sukses!'),
        content: const Text('Alat SOS berhasil terhubung ke Wi-Fi dan terdaftar ke akun Anda.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to list screen
            },
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _onPairingError(String payload) {
    if (!mounted) return;
    setState(() {
      _isPairing = false;
      _pairingStatus = '';
    });
    
    _eventSubscription?.cancel();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gagal menghubungkan. Pastikan password Wi-Fi benar dan alat berkedip cepat.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Pairing Wi-Fi (EZ Mode)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstructionCard(),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Informasi Wi-Fi Rumah',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ssidController,
                    enabled: !_isPairing,
                    decoration: InputDecoration(
                      labelText: 'Nama Wi-Fi (SSID)',
                      hintText: 'Contoh: Indihome_Rumah',
                      prefixIcon: const Icon(Icons.wifi),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    enabled: !_isPairing,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password Wi-Fi',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isPairing)
                    Column(
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF005C61)),
                        const SizedBox(height: 16),
                        Text(
                          _pairingStatus,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFF005C61), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Proses ini memakan waktu 1-2 menit...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: _startWifiPairing,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005C61),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Mulai Pairing',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text(
                'Langkah Wajib!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '1. Hubungkan HP Anda ke Wi-Fi 2.4GHz.\n'
            '2. Tekan & tahan tombol alat SOS sampai lampunya berkedip SANGAT CEPAT (mode EZ).\n'
            '3. Jika berkedip lambat, tekan & tahan lagi sampai berkedip cepat.\n'
            '4. Masukkan nama Wi-Fi dan password dengan teliti (huruf besar/kecil berpengaruh).',
            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
          ),
        ],
      ),
    );
  }
}
