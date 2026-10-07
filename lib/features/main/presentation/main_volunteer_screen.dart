import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/volunteer_dashboard_page.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/presentation/volunteer_task_list_page.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/volunteer_map_page.dart';
import 'package:sahabat_sos_mobile/features/profile/presentation/screens/volunteer_profile_screen.dart';

import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/services/websocket_service.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart'
    as event_bus;
import 'package:shared_preferences/shared_preferences.dart';

class MainVolunteerScreen extends StatefulWidget {
  final int initialIndex;
  const MainVolunteerScreen({super.key, this.initialIndex = 0});

  @override
  State<MainVolunteerScreen> createState() => _MainVolunteerScreenState();
}

class _MainVolunteerScreenState extends State<MainVolunteerScreen> {
  late int _selectedIndex;
  final LocationService _locationService = sl<LocationService>();

  // Key untuk akses langsung ke VolunteerMapPage state
  final GlobalKey<VolunteerMapPageState> _mapPageKey =
      GlobalKey<VolunteerMapPageState>();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _initVolunteerServices();
    event_bus.GlobalEventBus.navigateToMapWithSos.addListener(_onNavigateToMap);
  }

  /// Dipanggil saat relawan menerima tugas → pindah ke tab Peta & tampilkan rute
  void _onNavigateToMap() {
    final sosData = event_bus.GlobalEventBus.navigateToMapWithSos.value;
    if (sosData == null) return;

    setState(() {
      _selectedIndex = 2; // Tab Peta
    });

    // Beri sedikit jeda agar tab Peta sudah ter-render
    Future.delayed(const Duration(milliseconds: 400), () {
      _mapPageKey.currentState?.acceptSosAndRoute(sosData);
      // Reset event agar tidak trigger ulang
      event_bus.GlobalEventBus.navigateToMapWithSos.value = null;
    });
  }

  @override
  void dispose() {
    event_bus.GlobalEventBus.navigateToMapWithSos.removeListener(
      _onNavigateToMap,
    );
    _locationService.stopTracking();
    super.dispose();
  }

  Future<void> _initVolunteerServices() async {
    // 1. Start Location Tracking
    final hasPerm = await _locationService.requestPermission();
    if (hasPerm) {
      _locationService.startTracking();
    }

    // 2. Initialize WebSocket so popup notifications can arrive
    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token != null) {
        await WebsocketService.init(token);
      }
    } catch (e) {
      debugPrint('WebSocket init error in MainVolunteer: $e');
    }
  }

  @override
  void didUpdateWidget(MainVolunteerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }
  }

  static const Color primaryTeal = Color(0xFF006D77);
  static const Color _unselectedColor = Colors.grey;

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: 'Beranda',
    ),
    _NavItem(
      icon: CupertinoIcons.doc_text,
      selectedIcon: CupertinoIcons.doc_text_fill,
      label: 'Tugas',
    ),
    _NavItem(
      icon: CupertinoIcons.map,
      selectedIcon: CupertinoIcons.map_fill,
      label: 'Peta',
    ),
    _NavItem(
      icon: CupertinoIcons.person,
      selectedIcon: CupertinoIcons.person_solid,
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const VolunteerDashboardPage(),
      const VolunteerTaskListPage(),
      VolunteerMapPage(key: _mapPageKey),
      const VolunteerProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: pages),
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
                                  color: isSelected
                                      ? primaryTeal
                                      : _unselectedColor,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? primaryTeal
                                        : _unselectedColor,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
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
