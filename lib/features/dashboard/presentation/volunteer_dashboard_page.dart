import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart' as import_event_bus;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../../volunteer_task/presentation/widgets/new_assignment_dialog.dart';
import '../../volunteer_task/presentation/widgets/glass_container.dart';
import '../../volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/di/injection.dart';

class VolunteerDashboardPage extends StatefulWidget {
  const VolunteerDashboardPage({super.key});

  @override
  State<VolunteerDashboardPage> createState() => _VolunteerDashboardPageState();
}

class _VolunteerDashboardPageState extends State<VolunteerDashboardPage> {
  static const Color bgColor = Color(0xFFF5F6F8);
  static const Color primaryTeal = Color(0xFF006D77);
  
  bool _isReady = false;
  int? _volunteerId;
  final _volunteerDataSource = sl<VolunteerRemoteDataSource>();

  Map<String, dynamic>? _berandaData;
  Map<String, dynamic>? _activeTask;
  List<dynamic> _riwayatList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initVolunteerData();
  }

  Future<void> _initVolunteerData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get dashboard data (which includes user and summary)
      final beranda = await _volunteerDataSource.getBeranda();
      _berandaData = beranda;

      // Get active tasks for this volunteer
      try {
        final tasks = await _volunteerDataSource.getRelawanTasks();
        if (tasks['data'] != null) {
          _activeTask = tasks['data'];
        } else {
          _activeTask = null;
        }
      } catch (e) {
        _activeTask = null;
      }
      
      // Get volunteer history
      try {
        final riwayatData = await _volunteerDataSource.getRelawanBerandaRiwayat();
        final List<dynamic> combinedHistory = [];
        if (riwayatData['laporan'] != null) {
          combinedHistory.addAll(riwayatData['laporan']);
        }
        if (riwayatData['sos'] != null) {
          combinedHistory.addAll(riwayatData['sos']);
        }
        
        // Sort newest first
        combinedHistory.sort((a, b) {
          final timeA = DateTime.tryParse(a['waktu'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final timeB = DateTime.tryParse(b['waktu'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return timeB.compareTo(timeA);
        });
        
        _riwayatList = combinedHistory;
      } catch (e) {
        _riwayatList = [];
        debugPrint("Gagal load riwayat: $e");
      }

      final userData = beranda['user'];
      
      if (userData != null && userData['id'] != null) {
        _volunteerId = userData['id'];
        
        final prefs = sl<SharedPreferences>();
        final token = prefs.getString('auth_token');
        if (token != null) {
          await WebsocketService.init(token);
        }

        WebsocketService.listenToNewSosForVolunteer(_volunteerId!, _onNewSosReceived);
      } else {
        debugPrint("⚠️ Gagal init websocket: Data user relawan kosong atau tidak memiliki ID.");
      }
    } catch (e) {
      debugPrint("Gagal load data beranda relawan: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onNewSosReceived(dynamic eventData) {
    debugPrint("SOS Baru Masuk via Websocket: $eventData");
    if (!mounted) return;
    _showNewAssignmentDialog(eventData);
  }

  @override
  void dispose() {
    if (_volunteerId != null) {
      WebsocketService.stopListeningNewSosForVolunteer(_volunteerId!);
    }
    super.dispose();
  }

  bool _isDialogShowing = false;
  final List<int> _rejectedSosIds = [];

  void _showNewAssignmentDialog(Map<String, dynamic> sosData) {
    if (_isDialogShowing) return;
    
    final sosId = sosData['id'] as int;
    if (_rejectedSosIds.contains(sosId)) {
      debugPrint('SOS #$sosId diabaikan karena sudah pernah ditolak.');
      return; 
    }

    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NewAssignmentDialog(
        sosData: sosData,
        onAccept: () async {
          _isDialogShowing = false;
          Navigator.pop(ctx);
          try {
            await _volunteerDataSource.updateSosStatus(sosId, 'proses');

            // Trigger navigasi otomatis ke tab Peta dengan rute
            import_event_bus.GlobalEventBus.navigateToMapWithSos.value = sosData;

            // Juga refresh data map
            import_event_bus.GlobalEventBus.refreshMap.value =
                !import_event_bus.GlobalEventBus.refreshMap.value;

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tugas diterima! Menuju lokasi korban...'),
                  backgroundColor: Color(0xFF006D77),
                ),
              );
              _initVolunteerData(); // Refresh data to show active task
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Gagal menerima tugas: $e')),
              );
            }
          }
        },
        onReject: () async {
          _isDialogShowing = false;
          _rejectedSosIds.add(sosId); 
          Navigator.pop(ctx);
          
          try {
            await _volunteerDataSource.rejectSos(sosId);
            
            import_event_bus.GlobalEventBus.refreshMap.value = !import_event_bus.GlobalEventBus.refreshMap.value;

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tugas dialihkan ke relawan lain.')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Gagal mengalihkan tugas: $e')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE0F7FA), Color(0xFFF1F8E9), Color(0xFFE3F2FD)],
                  ),
                ),
              ),
            ),
            const Center(child: CupertinoActivityIndicator(radius: 16)),
          ],
        ),
      );
    }

    final summary = _berandaData?['summary'] ?? {};
    final activeSosCount = summary['active_sos'] ?? 0;
    final totalLaporan = summary['total_laporan'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Gradient and Orbs
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE0F7FA), Color(0xFFF1F8E9), Color(0xFFE3F2FD)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.tealAccent.withValues(alpha: 0.3),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withValues(alpha: 0.2),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _initVolunteerData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Logo
                    Row(
                      children: [
                        Image.asset('assets/images/logo.png', width: 24, height: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Sahabat SOS',
                          style: TextStyle(
                            color: primaryTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Status Relawan Card
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Status Relawan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isReady 
                                      ? 'Anda saat ini sedang aktif menerima panggilan darurat.' 
                                      : 'Anda saat ini sedang tidak aktif menerima panggilan darurat.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              Switch(
                                value: _isReady,
                                onChanged: (val) {
                                  setState(() {
                                    _isReady = val;
                                  });
                                },
                                activeThumbColor: Colors.white,
                                activeTrackColor: primaryTeal,
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.grey.shade400,
                                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                              ),
                              Text(
                                _isReady ? 'Siap\nBertugas' : 'Tidak\nAktif',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _isReady ? primaryTeal : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Tugas Aktif (Dynamic)
                    if (_activeTask != null) ...[
                      const Text(
                        'Tugas Aktif',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GlassContainer(
                        padding: const EdgeInsets.all(16),
                        color: const Color(0xFFC62828).withValues(alpha: 0.75),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Darurat SOS Sedang Diproses',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _activeTask!['pengguna']?['nama_lengkap'] ?? 'Pengguna',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(CupertinoIcons.location, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Lat: ${_activeTask!['latitude']}, Lng: ${_activeTask!['longitude']}',
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    await _volunteerDataSource.updateSosStatus(_activeTask!['id'], 'selesai');
                                    import_event_bus.GlobalEventBus.refreshMap.value = !import_event_bus.GlobalEventBus.refreshMap.value;
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Tugas diselesaikan!')),
                                      );
                                      _initVolunteerData();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Gagal menyelesaikan tugas: $e')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(CupertinoIcons.checkmark_circle, color: Color(0xFF8B0000)),
                                label: const Text(
                                  'Selesaikan Tugas',
                                  style: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFCDD2).withValues(alpha: 0.9),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Peta Wilayah Info
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Peta Wilayah',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {},
                                child: Row(
                                  children: const [
                                    Text(
                                      'Buka Peta ',
                                      style: TextStyle(
                                        color: primaryTeal,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Icon(CupertinoIcons.arrow_right, color: primaryTeal, size: 14),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.map, size: 32, color: Colors.teal[700]),
                                  const SizedBox(height: 8),
                                  Text('Gunakan tab Peta untuk melihat laporan.', style: TextStyle(color: Colors.teal[800], fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Statistik Sistem
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Statistik Sistem Saat Ini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.red.withValues(alpha: 0.8),
                                  child: const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SOS AKTIF',
                                      style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '$activeSosCount Kasus',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: primaryTeal.withValues(alpha: 0.8),
                                  child: const Icon(CupertinoIcons.doc_text, color: Colors.white),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TOTAL LAPORAN',
                                      style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '$totalLaporan Laporan',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Riwayat Tugas Terselesaikan
                    const Text(
                      'Riwayat Tugas Terselesaikan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_riwayatList.isEmpty)
                      Center(
                        child: Text(
                          'Belum ada riwayat tugas',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    else
                      ..._riwayatList.map((item) {
                        final isSos = item['tipe'] == 'sos';
                        final title = isSos ? 'Keadaan Darurat (SOS)' : (item['kategori'] ?? 'Laporan');
                        final desc = isSos ? (item['lokasi'] ?? '') : (item['deskripsi'] ?? '');
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isSos ? Colors.red[100] : Colors.blue[100],
                                child: Icon(
                                  isSos ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.doc_text_fill,
                                  color: isSos ? Colors.red[700] : Colors.blue[700],
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      desc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    
                    const SizedBox(height: 80), 
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
