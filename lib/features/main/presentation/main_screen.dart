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

  static const Color primaryTeal = Color(0xFF00695C);

  final List<Widget> _pages = [
    const DashboardPage(),
    const QuickReportScreen(),
    const Center(child: Text('Devices Page')),
    const HistoryPage(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: primaryTeal.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: primaryTeal),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign, color: primaryTeal),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_input_antenna_outlined),
            selectedIcon: Icon(Icons.settings_input_antenna, color: primaryTeal),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: primaryTeal),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: primaryTeal),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
