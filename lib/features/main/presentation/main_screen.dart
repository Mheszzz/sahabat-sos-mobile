import 'package:flutter/material.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/dashboard_page.dart';
import 'package:sahabat_sos_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:sahabat_sos_mobile/features/reports/presentation/quick_report_screen.dart';
import 'package:sahabat_sos_mobile/features/history/presentation/history_screen.dart';

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
    const Center(child: Text('Devices Page')),
    const HistoryPage(),
    const ProfileScreen(),
  ];

  static const Color _unselectedColor = Color(0xFF37474F);

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    _NavItem(icon: Icons.campaign_outlined, selectedIcon: Icons.campaign, label: 'Report'),
    _NavItem(icon: Icons.settings_input_antenna_outlined, selectedIcon: Icons.settings_input_antenna, label: 'Devices'),
    _NavItem(icon: Icons.history_outlined, selectedIcon: Icons.history, label: 'History'),
    _NavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
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
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 20 : 12,
                      vertical: isSelected ? 12 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryTeal : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          color: isSelected ? Colors.white : _unselectedColor,
                          size: 26,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : _unselectedColor,
                            fontSize: 12,
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
