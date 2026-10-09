import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionGate extends StatefulWidget {
  final Widget child;
  const PermissionGate({Key? key, required this.child}) : super(key: key);

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> with WidgetsBindingObserver {
  bool _allGranted = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final location = await Permission.location.status;
    final notification = await Permission.notification.status;
    final microphone = await Permission.microphone.status;
    
    if (location.isGranted && notification.isGranted && microphone.isGranted) {
      if (mounted) {
        setState(() {
          _allGranted = true;
          _isChecking = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _allGranted = false;
          _isChecking = false;
        });
      }
      _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.notification,
      Permission.microphone,
    ].request();
    
    final location = await Permission.location.status;
    final notification = await Permission.notification.status;
    final microphone = await Permission.microphone.status;

    if (mounted) {
      if (location.isGranted && notification.isGranted && microphone.isGranted) {
        setState(() => _allGranted = true);
      } else {
        setState(() => _allGranted = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allGranted) return widget.child;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.shield, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Akses Wajib Diperlukan',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aplikasi Sahabat SOS membutuhkan akses Lokasi, Notifikasi, dan Mikrofon agar dapat berfungsi. Anda tidak dapat melanjutkan sebelum semua izin diberikan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                _isChecking 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        await _requestPermissions();
                        if (!_allGranted) {
                          openAppSettings();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Izinkan Akses',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
