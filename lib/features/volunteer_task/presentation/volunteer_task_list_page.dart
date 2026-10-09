import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/presentation/volunteer_active_task_page.dart';
import 'dart:ui';
import 'package:sahabat_sos_mobile/features/volunteer_task/presentation/widgets/glass_container.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart' as import_event_bus;

class VolunteerTaskListPage extends StatefulWidget {
  const VolunteerTaskListPage({super.key});

  @override
  State<VolunteerTaskListPage> createState() => _VolunteerTaskListPageState();
}

class _VolunteerTaskListPageState extends State<VolunteerTaskListPage> {
  static const Color primaryTeal = Color(0xFF006D77);
  static const Color sosRed = Color(0xFFC62828);
  static const Color bgColor = Color(0xFFF5F6F8);

  final _dataSource = sl<VolunteerRemoteDataSource>();
  bool _isLoading = true;
  List<dynamic> _availableSosList = [];
  List<dynamic> _availableLaporanList = [];
  Map<String, dynamic>? _activeTask;

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Mendengarkan trigger pembaruan dari WebSocket
    import_event_bus.GlobalEventBus.refreshMap.addListener(_onWebSocketUpdate);
  }

  @override
  void dispose() {
    import_event_bus.GlobalEventBus.refreshMap.removeListener(_onWebSocketUpdate);
    super.dispose();
  }

  void _onWebSocketUpdate() {
    if (mounted) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Cek apakah ada tugas yang sedang ditangani
      final activeRes = await _dataSource.getRelawanTasks();
      if (activeRes['data'] != null) {
        _activeTask = activeRes['data'];
      } else {
        _activeTask = null;
      }

      // Ambil daftar tugas relawan
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      final dio = sl<Dio>();
      final response = await dio.get(
        ApiConstants.tugasRelawan,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> allData = response.data['data'] is List 
            ? response.data['data'] 
            : [];
        
        setState(() {
          _availableSosList = allData.where((e) => e['tipe'] == 'sos' || e['kategori_laporan'] == 'SOS').toList();
          _availableLaporanList = allData.where((e) => e['tipe'] == 'laporan' || (e['tipe'] != 'sos' && e['kategori_laporan'] != 'SOS')).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetch task list: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VolunteerActiveTaskPage(),
      ),
    ).then((_) => _fetchData()); // Refresh after returning
  }

  Future<void> _acceptTask(int id) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 16)),
      );
      await _dataSource.updateSosStatus(id, 'proses');
      if (mounted) Navigator.pop(context); // close dialog
      _navigateToDetail();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil tugas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: const Color(0xFFF5F6F8),
        child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F6F8),
          appBar: AppBar(
            backgroundColor: Colors.white.withOpacity(0.15),
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
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
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.refresh, color: primaryTeal),
                onPressed: _fetchData,
              )
            ],
            bottom: const TabBar(
              labelColor: primaryTeal,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primaryTeal,
              tabs: [
                Tab(text: "Kasus SOS"),
                Tab(text: "Laporan Aktif"),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CupertinoActivityIndicator(radius: 16))
              : TabBarView(
                  children: [
                    _buildTabContent(_availableSosList, true),
                    _buildTabContent(_availableLaporanList, false),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTabContent(List<dynamic> list, bool isSos) {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_activeTask != null) ...[
            const Text(
              'Sedang Ditangani',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTeal),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _navigateToDetail,
              child: GlassContainer(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sosRed.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.shield_fill, color: sosRed, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kasus Aktif (ID: ${_activeTask!['id']})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _activeTask!['pengguna']?['name'] ?? 'Pelapor Anonim',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            isSos ? 'Kasus SOS Tersedia' : 'Laporan Tersedia',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTeal),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(CupertinoIcons.checkmark_shield, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(isSos ? 'Belum ada kasus darurat baru' : 'Belum ada laporan baru', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ...list.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(isSos ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.doc_text, color: isSos ? sosRed : primaryTeal, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (isSos ? 'Darurat SOS' : 'Laporan') + ' - ID: ${item['id']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Baru saja',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(CupertinoIcons.person_solid, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(item['pengguna']?['name'] ?? item['relawan']?['name'] ?? 'Korban', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryTeal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            if (_activeTask != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Selesaikan tugas aktif Anda terlebih dahulu!')),
                              );
                            } else {
                              _acceptTask(item['id']);
                            }
                          },
                          child: Text(isSos ? 'Tolong Sekarang' : 'Tangani Laporan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}