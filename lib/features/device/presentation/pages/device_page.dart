import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../features/tuya_device/data/services/tuya_channel_service.dart';
import '../../../../features/tuya_device/presentation/screens/tuya_device_list_screen.dart';
import '../../../smartwatch/data/models/smartwatch_device_model.dart';
import '../../../smartwatch/data/services/smartwatch_manager.dart';
import '../../../smartwatch/presentation/screens/smartwatch_scan_screen.dart';
import '../../../smartwatch/presentation/screens/smartwatch_detail_screen.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> with SingleTickerProviderStateMixin {
  static const Color primaryTeal = Color(0xFF00695C);

  final _tuyaService = GetIt.instance<TuyaChannelService>();
  final _smartwatchManager = GetIt.instance<SmartwatchManager>();
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initDevice();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initDevice() async {
    try {
      await _tuyaService.initTuya();
      final prefs = GetIt.instance<SharedPreferences>();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        await _tuyaService.loginAnonymous(token);
      }
      await _smartwatchManager.init();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
    BorderRadius? borderRadius,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withValues(alpha: 0.65),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F6F8),
        body: Center(
          child: CupertinoActivityIndicator(radius: 16),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 24, height: 24),
            const SizedBox(width: 8),
            const Text(
              'Sahabat SOS',
              style: TextStyle(
                color: primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.2,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black54,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: primaryTeal,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: primaryTeal.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 16),
                      SizedBox(width: 6),
                      Text('Tombol IoT'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.watch, size: 16),
                      SizedBox(width: 6),
                      Text('Smartwatch'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Tuya Devices (embedded without redundant inner AppBar)
          const TuyaDeviceListScreen(showBackButton: false, showAppBar: false),

          // Tab 2: Smartwatch Devices
          _buildSmartwatchTab(),
        ],
      ),
    );
  }

  Widget _buildSmartwatchTab() {
    return ValueListenableBuilder<List<SmartwatchDeviceModel>>(
      valueListenable: _smartwatchManager.pairedDevices,
      builder: (context, pairedList, _) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Page Title & Subtitle
              const Text(
                'Smartwatch',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pantau detak jantung, deteksi jatuh, dan picu sinyal SOS darurat dari pergelangan tangan.',
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Banner info
              _buildGlassContainer(
                color: primaryTeal.withValues(alpha: 0.08),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryTeal.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.checkmark_shield_fill,
                        color: primaryTeal,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Mendukung Huawei Watch (via Huawei Health / Health Connect) dan BLE Smartband untuk deteksi darurat otomatis.',
                        style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Header bar: Smartwatch Terhubung & Tambah Jam
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Smartwatch Terhubung',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pairedList.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SmartwatchScanScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryTeal.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.plus, size: 14, color: primaryTeal),
                          SizedBox(width: 4),
                          Text(
                            'Tambah Jam',
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
                ],
              ),

              const SizedBox(height: 12),

              if (pairedList.isEmpty)
                _buildGlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.watch_outlined,
                          size: 46,
                          color: Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum Ada Smartwatch',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sambungkan Huawei Watch, Wear OS, atau smartband BLE Anda untuk memicu SOS dan mengirim telemetri detak jantung saat darurat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SmartwatchScanScreen(),
                            ),
                          );
                        },
                        icon: const Icon(CupertinoIcons.bluetooth, size: 18),
                        label: const Text(
                          'Pindai & Sambungkan Smartwatch',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...pairedList.map((device) {
                  return ValueListenableBuilder<SmartwatchDeviceModel?>(
                    valueListenable: _smartwatchManager.activeDevice,
                    builder: (context, active, _) {
                      final isThisDevice = active != null && active.id == device.id;
                      final isConnected = isThisDevice && active.isConnected;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildGlassContainer(
                          padding: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SmartwatchDetailScreen(device: device),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: primaryTeal.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.watch,
                                      color: primaryTeal,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          device.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: isConnected
                                                    ? const Color(0xFF34C759)
                                                    : Colors.grey,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            if (isThisDevice)
                                              Expanded(
                                                child: ValueListenableBuilder<String?>(
                                                  valueListenable:
                                                      _smartwatchManager.connectionStatus,
                                                  builder: (context, status, _) {
                                                    return Text(
                                                      status ??
                                                          (isConnected
                                                              ? 'Terhubung (Siaga)'
                                                              : 'Terputus'),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: isConnected
                                                            ? const Color(0xFF34C759)
                                                            : Colors.grey,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    );
                                                  },
                                                ),
                                              )
                                            else
                                              Expanded(
                                                child: Text(
                                                  'Tidak aktif',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade500,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                                            Text(
                                              device.brandDisplay,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  isConnected
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 9,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF34C759).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(0xFF34C759).withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: const Text(
                                                'Siaga',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF2E7D32),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(
                                              CupertinoIcons.chevron_right,
                                              size: 16,
                                              color: Colors.black38,
                                            ),
                                          ],
                                        )
                                      : ValueListenableBuilder<String?>(
                                          valueListenable: _smartwatchManager.connectingDeviceId,
                                          builder: (context, connectingId, _) {
                                            final isThisConnecting = connectingId == device.id;
                                            final isAnyConnecting = connectingId != null;

                                            return ElevatedButton.icon(
                                              onPressed: isAnyConnecting
                                                  ? null
                                                  : () async {
                                                      final ok = await _smartwatchManager
                                                          .connectDevice(device);
                                                      if (!context.mounted) return;
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            ok
                                                                ? 'Berhasil terhubung ke ${device.name}'
                                                                : 'Gagal terhubung ke ${device.name}. Pastikan layar jam menyala & aplikasi bawaan ditutup.',
                                                          ),
                                                          backgroundColor: ok ? primaryTeal : Colors.red,
                                                        ),
                                                      );
                                                    },
                                              icon: isThisConnecting
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child: CupertinoActivityIndicator(
                                                        color: Colors.white,
                                                        radius: 7,
                                                      ),
                                                    )
                                                  : const Icon(CupertinoIcons.bluetooth, size: 14),
                                              label: Text(
                                                isThisConnecting
                                                    ? 'Menghubungkan...'
                                                    : 'Sambungkan',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: primaryTeal,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),

              const SizedBox(height: 100), // Reserve space for bottom floating navbar
            ],
          ),
        );
      },
    );
  }
}
