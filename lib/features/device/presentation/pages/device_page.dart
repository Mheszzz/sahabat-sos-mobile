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
        title: const Text(
          'Perangkat Saya',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFE53935),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFE53935),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(
              icon: Icon(Icons.radio_button_checked, size: 20),
              text: 'Tombol IoT Tuya',
            ),
            Tab(
              icon: Icon(Icons.watch, size: 20),
              text: 'Smartwatch',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Tuya Devices
          const TuyaDeviceListScreen(showBackButton: false),

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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.health_and_safety_outlined, color: Color(0xFFE53935), size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Sambungkan smartwatch Huawei atau BLE untuk mendeteksi darurat, detak jantung, dan jatuh.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Smartwatch Terhubung',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SmartwatchScanScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah Jam'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE53935),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (pairedList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.watch_off_outlined, size: 56, color: Colors.grey),
                      const SizedBox(height: 14),
                      const Text(
                        'Belum Ada Smartwatch',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pasangkan Huawei Watch, Wear OS, atau smartband BLE Anda untuk memicu SOS langsung dari pergelangan tangan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SmartwatchScanScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.bluetooth_searching),
                        label: const Text('Pindai & Sambungkan Smartwatch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      final isConnected = active != null && active.id == device.id && active.isConnected;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 1,
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
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.watch,
                                    color: Color(0xFFE53935),
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
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isConnected ? Colors.green : Colors.grey,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isConnected ? 'Terhubung (Siaga)' : 'Terputus',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isConnected ? Colors.green : Colors.grey,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Text(' • ', style: TextStyle(color: Colors.grey)),
                                          Text(
                                            device.brandDisplay,
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
