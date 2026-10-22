import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/dashboard_page.dart';
import 'package:sahabat_sos_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:sahabat_sos_mobile/features/reports/presentation/quick_report_screen.dart';
import 'package:sahabat_sos_mobile/features/history/presentation/history_screen.dart';
import 'package:sahabat_sos_mobile/features/device/presentation/pages/device_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart';
import '../../../routing/routes.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    final prefs = GetIt.instance<SharedPreferences>();
    if (prefs.getString('user_role') == 'relawan') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.homeVolunteer);
      });
      return;
    }
    _initLocationTracking();
    GlobalEventBus.changeUserTab.addListener(_onChangeUserTab);
  }

  void _onChangeUserTab() {
    final targetIndex = GlobalEventBus.changeUserTab.value;
    if (targetIndex != null && targetIndex >= 0 && targetIndex < _pages.length) {
      if (mounted) {
        setState(() {
          _selectedIndex = targetIndex;
        });
      }
      GlobalEventBus.changeUserTab.value = null;
    }
  }

  @override
  void dispose() {
    GlobalEventBus.changeUserTab.removeListener(_onChangeUserTab);
    super.dispose();
  }

  Future<void> _initLocationTracking() async {
    final locationService = GetIt.instance<LocationService>();
    final hasPermission = await locationService.requestPermission();
    if (hasPermission) {
      locationService.startTracking();
    }
  }

  @override
  void didUpdateWidget(MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _selectedIndex = widget.initialIndex;
    }
  }

  static const Color primaryTeal = Color(0xFF00695C);

  final List<Widget> _pages = [
    const DashboardPage(),
    const QuickReportScreen(),
    const DevicePage(),
    const HistoryPage(),
    const ProfileScreen(),
  ];

  static const Color _unselectedColor = Color(0xFF6B7280);

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: 'Home',
    ),
    _NavItem(
      icon: CupertinoIcons.exclamationmark_bubble,
      selectedIcon: CupertinoIcons.exclamationmark_bubble_fill,
      label: 'Report',
    ),
    _NavItem(
      icon: CupertinoIcons.antenna_radiowaves_left_right,
      selectedIcon: CupertinoIcons.antenna_radiowaves_left_right,
      label: 'Devices',
    ),
    _NavItem(
      icon: CupertinoIcons.clock,
      selectedIcon: CupertinoIcons.clock_fill,
      label: 'History',
    ),
    _NavItem(
      icon: CupertinoIcons.person,
      selectedIcon: CupertinoIcons.person_solid,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;
        final selectedColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
        final unselectedColor =
            isHighContrast ? const Color(0xFFD1D5DB) : _unselectedColor;

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              IndexedStack(index: _selectedIndex, children: _pages),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: isHighContrast
                        ? const Color(0xFF121212)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isHighContrast
                          ? const Color(0xFF4B5563)
                          : const Color(0xFFE5E7EB),
                      width: isHighContrast ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isHighContrast ? 0.35 : 0.08,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(_navItems.length, (index) {
                          final isSelected = _selectedIndex == index;
                          final item = _navItems[index];
                          return GestureDetector(
                            onTap: () {
                              AccessibilityService.instance.hapticSelection();
                              AccessibilityService.instance.speak("Tab ${item.label}");
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected && isHighContrast
                                    ? const Color(0xFF1E2430)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    color: isSelected
                                        ? selectedColor
                                        : unselectedColor,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? selectedColor
                                          : unselectedColor,
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
