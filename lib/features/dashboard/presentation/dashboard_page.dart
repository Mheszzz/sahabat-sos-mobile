import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color sosRed = Color(
    0xFFE50000,
  ); // More vibrant red to match image

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _tapCount = 0;
  Timer? _tapTimer;

  // Beranda data from API
  String _userName = '';
  int _activeSos = 0;
  int _totalLaporan = 0;
  bool _isBerandaLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchBeranda();
  }

  Future<void> _fetchBeranda() async {
    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await sl<Dio>().get(
        ApiConstants.beranda,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        }),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        setState(() {
          _userName = data['user']?['name'] ?? '';
          _activeSos = data['summary']?['active_sos'] ?? 0;
          _totalLaporan = data['summary']?['total_laporan'] ?? 0;
          _isBerandaLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal fetch beranda: $e');
      if (mounted) {
        setState(() => _isBerandaLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Expanded(flex: 10, child: _buildSosButton()),
              const SizedBox(height: 16),
              const Text(
                'Tekan tombol 5 kali dengan cepat\nuntuk meminta bantuan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const Spacer(flex: 2),
              _buildDeviceStatusCard(),
              const SizedBox(height: 12),
              _buildMenuGrid(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFF5F6F8), // Match background
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          const Icon(Icons.accessibility_new, color: primaryTeal, size: 24),
          const SizedBox(width: 8),
          Text(
            _userName.isNotEmpty ? 'Halo, $_userName' : 'Sahabat SOS',
            style: const TextStyle(
              color: primaryTeal,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Tooltip(
            message: 'Lihat Peta',
            child: InkWell(
              onTap: () {
                context.push('/map'); // We will add this route
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.map_outlined, color: primaryTeal, size: 20),
                    SizedBox(width: 4),
                    Text(
                      'Peta',
                      style: TextStyle(
                        color: primaryTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSosButton() {
    return Center(
      child: Listener(
        onPointerDown: (_) => _animationController.forward(),
        onPointerUp: (_) => _animationController.reverse(),
        onPointerCancel: (_) => _animationController.reverse(),
        child: GestureDetector(
          onTap: () {
            _tapCount++;
            if (_tapCount >= 5) {
              _tapCount = 0;
              // TODO: trigger emergency SOS action
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('SOS Darurat Dipicu!')),
              );
            }

            _tapTimer?.cancel();
            _tapTimer = Timer(const Duration(seconds: 2), () {
              _tapCount = 0;
            });
          },
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FittedBox(
              fit: BoxFit.contain, // This allows it to grow or shrink perfectly to fill the flex space
              child: Padding(
                padding: const EdgeInsets.all(
                  16.0,
                ), // Give it some breathing room from the edges
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(
                        -0.3,
                        -0.5,
                      ), // Light source from top-left
                      radius: 0.8,
                      colors: [
                        const Color(0xFFFF6B6B), // Highlight (bright red/pink)
                        sosRed, // Base color
                        const Color(0xFF8B0000), // Shadow (dark red)
                      ],
                    ),
                    boxShadow: [
                      // Bottom right dark shadow
                      BoxShadow(
                        color: const Color(0xFF8B0000).withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 4,
                        offset: const Offset(8, 12),
                      ),
                      // Top left light highlight (Neumorphic effect)
                      const BoxShadow(
                        color: Colors.white,
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: Offset(-6, -6),
                      ),
                      // Additional soft glow around
                      BoxShadow(
                        color: sosRed.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 80,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            offset: Offset(2, 3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              offset: Offset(2, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'DARURAT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              offset: Offset(2, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: _isBerandaLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Row(
              children: [
                _buildStatItem(
                  icon: Icons.warning_amber_rounded,
                  label: 'SOS Aktif',
                  value: '$_activeSos',
                  color: Colors.red,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade200,
                ),
                _buildStatItem(
                  icon: Icons.description_outlined,
                  label: 'Total Laporan',
                  value: '$_totalLaporan',
                  color: primaryTeal,
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    final items = [
      _MenuItemData(
        icon: Icons.campaign,
        label: 'Kirim Laporan',
        route: '/quick-report',
      ),
      _MenuItemData(icon: Icons.cell_tower, label: 'Perangkat Saya'),
      _MenuItemData(icon: Icons.badge, label: 'Kontak Darurat'),
      _MenuItemData(icon: Icons.history, label: 'Riwayat Bantuan'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.8, // Make cards flatter/smaller vertically
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildMenuCard(item.icon, item.label, route: item.route);
      },
    );
  }

  Widget _buildMenuCard(IconData icon, String label, {String? route}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (route != null) {
            context.push(route);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primaryTeal, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String label;
  final String? route;
  _MenuItemData({required this.icon, required this.label, this.route});
}
