import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import '../../../../features/tuya_device/data/services/tuya_channel_service.dart';
import '../../../../features/tuya_device/presentation/screens/tuya_device_list_screen.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final _tuyaService = GetIt.instance<TuyaChannelService>();
  bool _isLoading = true;

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

      if (mounted) {
        setState(() {
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
      return ListenableBuilder(
        listenable: AccessibilityService.instance,
        builder: (context, _) {
          final isHighContrast =
              AccessibilityService.instance.isHighContrastEnabled ||
              Theme.of(context).brightness == Brightness.dark ||
              MediaQuery.of(context).highContrast;
          return Scaffold(
            backgroundColor:
                isHighContrast ? Colors.black : const Color(0xFFF5F6F8),
            body: Center(
              child: CupertinoActivityIndicator(
                radius: 16,
                color: isHighContrast
                    ? const Color(0xFF80CBC4)
                    : const Color(0xFF00695C),
              ),
            ),
          );
        },
      );
    }

    return const TuyaDeviceListScreen(showBackButton: false);
  }
}
