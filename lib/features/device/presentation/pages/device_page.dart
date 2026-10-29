import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import '../../../tuya_device/data/services/tuya_channel_service.dart';
import '../../../tuya_device/presentation/screens/tuya_device_list_screen.dart';
import '../screens/smartband_screen.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final _tuyaService = GetIt.instance<TuyaChannelService>();
  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0: Smartband, 1: Tuya SOS

  static const Color primaryTeal = Color(0xFF00695C);

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

    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;
        final bg = isHighContrast ? Colors.black : const Color(0xFFF5F6F8);
        final tabContainerBg = AccessibleColors.cardBackground(isHighContrast);
        final tabContainerBorder = AccessibleColors.cardBorder(isHighContrast);
        final activeColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
        final activeTextColor = isHighContrast ? Colors.black : Colors.white;
        final inactiveTextColor =
            AccessibleColors.textSecondary(isHighContrast);

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Column(
              children: [
                // Segmented Control Selector di Bagian Atas
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: tabContainerBg,
                      borderRadius: BorderRadius.circular(14),
                      border: tabContainerBorder,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isHighContrast ? 0.3 : 0.03,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabPill(
                            index: 0,
                            title: 'Huawei / Smartband',
                            icon: Icons.watch_rounded,
                            activeColor: activeColor,
                            activeTextColor: activeTextColor,
                            inactiveTextColor: inactiveTextColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildTabPill(
                            index: 1,
                            title: 'Tombol Fisik (Tuya)',
                            icon: Icons.radio_button_checked_rounded,
                            activeColor: activeColor,
                            activeTextColor: activeTextColor,
                            inactiveTextColor: inactiveTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Konten Tab
                Expanded(
                  child: _selectedTabIndex == 0
                      ? const SmartbandScreen(showBackButton: false)
                      : const TuyaDeviceListScreen(showBackButton: false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabPill({
    required int index,
    required String title,
    required IconData icon,
    required Color activeColor,
    required Color activeTextColor,
    required Color inactiveTextColor,
  }) {
    final isSelected = _selectedTabIndex == index;

    return GestureDetector(
      onTap: () {
        if (_selectedTabIndex != index) {
          setState(() => _selectedTabIndex = index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeTextColor : inactiveTextColor,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeTextColor : inactiveTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}