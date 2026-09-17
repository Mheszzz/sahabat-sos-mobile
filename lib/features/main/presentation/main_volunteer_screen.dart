import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/volunteer_dashboard_page.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/map_page.dart';
import 'package:sahabat_sos_mobile/features/profile/presentation/screens/volunteer_profile_screen.dart';

class MainVolunteerScreen extends StatefulWidget {
  final int initialIndex;
  const MainVolunteerScreen({super.key, this.initialIndex = 0});

  @override
  State<MainVolunteerScreen> createState() => _MainVolunteerScreenState();
}

class _MainVolunteerScreenState extends State<MainVolunteerScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(MainVolunteerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _selectedIndex = widget.initialIndex;
    }
  }

  static const Color primaryTeal = Color(0xFF006D77);

  final List<Widget> _pages = [
    const VolunteerDashboardPage(),
    const Scaffold(body: Center(child: Text('Tugas Aktif (Segera Hadir)'))),
    const MapPage(),
    const VolunteerProfileScreen(),
  ];

  static const Color _unselectedColor = Colors.grey;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Beranda'),
    _NavItem(icon: Icons.assignment_outlined, selectedIcon: Icons.assignment, label: 'Tugas'),
    _NavItem(icon: Icons.map_outlined, selectedIcon: Icons.map, label: 'Peta'),
    _NavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profil'),
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
                color: Colors.white.withValues(alpha: 0.9),
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
