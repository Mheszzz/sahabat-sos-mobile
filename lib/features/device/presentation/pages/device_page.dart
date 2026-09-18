import 'package:flutter/material.dart';

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../features/tuya_device/data/services/tuya_channel_service.dart';
import '../../../../features/tuya_device/presentation/screens/tuya_device_list_screen.dart';
import '../../../../features/tuya_device/presentation/screens/tuya_device_detail_screen.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final _tuyaService = GetIt.instance<TuyaChannelService>();
  bool _isLoading = true;
  String? _firstDeviceId;

  @override
  void initState() {
    super.initState();
    _initDevice();
  }

  Future<void> _initDevice() async {
    try {
      await _tuyaService.initTuya();
      final prefs = GetIt.instance<SharedPreferences>();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        await _tuyaService.loginAnonymous(token);
      }
      final devices = await _tuyaService.getDeviceList();
      if (mounted) {
        setState(() {
          _firstDeviceId = devices.isNotEmpty ? devices.first.deviceId : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF005C61),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_firstDeviceId != null) {
      return TuyaDeviceDetailScreen(deviceId: _firstDeviceId!, showBackButton: false);
    }

    return const TuyaDeviceListScreen(showBackButton: false);
  }
}
