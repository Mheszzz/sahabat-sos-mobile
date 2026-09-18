import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/dashboard_page.dart';
import 'package:sahabat_sos_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:sahabat_sos_mobile/features/reports/presentation/quick_report_screen.dart';
import 'package:sahabat_sos_mobile/features/history/presentation/history_screen.dart';
import 'package:sahabat_sos_mobile/features/device/presentation/pages/device_page.dart';


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

  static const Color _unselectedColor = Colors.grey;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: CupertinoIcons.house, selectedIcon: CupertinoIcons.house_fill, label: 'Home'),
    _NavItem(icon: CupertinoIcons.exclamationmark_bubble, selectedIcon: CupertinoIcons.exclamationmark_bubble_fill, label: 'Report'),
    _NavItem(icon: CupertinoIcons.antenna_radiowaves_left_right, selectedIcon: CupertinoIcons.antenna_radiowaves_left_right, label: 'Devices'),
    _NavItem(icon: CupertinoIcons.clock, selectedIcon: CupertinoIcons.clock_fill, label: 'History'),
    _NavItem(icon: CupertinoIcons.person, selectedIcon: CupertinoIcons.person_solid, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(_navItems.length, (index) {
                        final isSelected = _selectedIndex == index;
                        final item = _navItems[index];
                        return GestureDetector(
                          onTap: () {
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
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? item.selectedIcon : item.icon,
                                  color: isSelected ? primaryTeal : _unselectedColor,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isSelected ? primaryTeal : _unselectedColor,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
          ),
        ],
      ),
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
