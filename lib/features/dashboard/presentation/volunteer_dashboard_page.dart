import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart'
    as import_event_bus;
import '../../volunteer_task/presentation/volunteer_active_task_page.dart'
    as import_active_task;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
  int _visibleRiwayatCount = 5;

  @override
  void initState() {
    super.initState();
    _initVolunteerData();
    import_event_bus.GlobalEventBus.showSosAssignmentPopup.addListener(_onShowSosAssignmentPopup);
    
    // Gunakan addPostFrameCallback agar showDialog dipanggil 
    // SETELAH proses build/initState pertama selesai.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onShowSosAssignmentPopup();
    });
  }

  void _onShowSosAssignmentPopup() {
    final sosData = import_event_bus.GlobalEventBus.showSosAssignmentPopup.value;
    if (sosData != null) {
      _showNewAssignmentDialog(sosData);
      import_event_bus.GlobalEventBus.showSosAssignmentPopup.value = null; // reset
    }
  }

  Future<void> _initVolunteerData() async {
    setState(() {
      _isLoading = true;
    });

    try {
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
        final riwayatData = await _volunteerDataSource
            .getRelawanBerandaRiwayat();
        final List<dynamic> combinedHistory = [];
        
        final rawData = riwayatData['data'];

        if (rawData != null && rawData is List) {
          for (var item in rawData) {
            if (item is Map<String, dynamic>) {
              item['tipe'] = item['tipe'] ?? 'laporan';
              item['waktu_display'] = item['waktu'] ?? item['waktu_laporan'] ?? item['waktu_sos'] ?? item['created_at'] ?? '';
              item['lokasi_display'] = item['lokasi'] ?? item['lokasi_laporan'] ?? item['lokasi_user'] ?? 'Lokasi tidak diketahui';
              item['deskripsi_display'] = item['deskripsi'] ?? '';
              item['kategori_display'] = item['kategori'] ?? item['kategori_laporan'] ?? 'Laporan';
              combinedHistory.add(item);
            } else {
              combinedHistory.add(item);
            }
          }
        }

        // Sort newest first
        combinedHistory.sort((a, b) {
          final String dateA = a is Map ? (a['waktu_display'] ?? '') : '';
          final String dateB = b is Map ? (b['waktu_display'] ?? '') : '';
          
          final timeA =
              DateTime.tryParse(dateA) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final timeB =
              DateTime.tryParse(dateB) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return timeB.compareTo(timeA);
        });

        _riwayatList = combinedHistory;
      } catch (e) {
        _riwayatList = [];
        debugPrint("Gagal load riwayat: $e");
      }

      // 4. Get User Profile for Websocket
      final profileRes = await _volunteerDataSource.getRelawanProfile();
      final userData = profileRes['user'];

      if (userData != null && userData['id'] != null) {
        final statusKetersediaan = userData['status_ketersediaan']?.toString().toLowerCase();
        _isReady = (statusKetersediaan == 'tersedia');
        
        _volunteerId = (userData['id'] is int) 
            ? userData['id'] as int 
            : int.tryParse(userData['id'].toString());

        final prefs = sl<SharedPreferences>();
        if (_volunteerId != null) {
          await prefs.setInt('volunteer_id', _volunteerId!);
        }
        final token = prefs.getString('auth_token');
        if (token != null) {
          await WebsocketService.init(token);
        }

        WebsocketService.listenToNewSosForVolunteer(
          _volunteerId!,
          _onNewSosReceived,
        );
      } else {
        debugPrint(
          "⚠️ Gagal init websocket: Data user relawan kosong atau tidak memiliki ID.",
        );
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
    import_event_bus.GlobalEventBus.showSosAssignmentPopup.removeListener(_onShowSosAssignmentPopup);
    if (_volunteerId != null) {
      WebsocketService.stopListeningNewSosForVolunteer(_volunteerId!);
    }
    super.dispose();
  }

  bool _isDialogShowing = false;
  final List<int> _rejectedSosIds = [];

  void _showNewAssignmentDialog(dynamic eventData) {
    if (_isDialogShowing) return;
    if (eventData == null) return;
    
    Map<String, dynamic> sosData;
    if (eventData is Map) {
      sosData = Map<String, dynamic>.from(eventData);
    } else {
      return; // Tidak bisa diproses
    }

    final dynamic rawId = sosData['id'];
    final sosId = (rawId is int) ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0;
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

            // Langsung navigasi ke halaman detail tugas
            if (mounted) {
              import_event_bus.GlobalEventBus.refreshMap.value = !import_event_bus.GlobalEventBus.refreshMap.value;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const import_active_task.VolunteerActiveTaskPage(),
                ),
              ).then((_) => _initVolunteerData()); // Refresh on back
            }

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

            import_event_bus.GlobalEventBus.refreshMap.value =
                !import_event_bus.GlobalEventBus.refreshMap.value;

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tugas dialihkan ke relawan lain.'),
                ),
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
                color: const Color(0xFFF5F6F8),
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
              color: const Color(0xFFF5F6F8),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: _initVolunteerData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Logo
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 24,
                          height: 24,
                        ),
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
                                onChanged: (val) async {
                                  // Optimistic UI update
                                  setState(() {
                                    _isReady = val;
                                  });
                                  
                                  try {
                                    final statusStr = val ? 'tersedia' : 'tidak_tersedia';
                                    await _volunteerDataSource.updateStatusKetersediaan(statusStr);
                                  } catch (e) {
                                    // Revert on failure
                                    setState(() {
                                      _isReady = !val;
                                    });
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Gagal memperbarui status'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                activeThumbColor: Colors.white,
                                activeTrackColor: primaryTeal,
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.grey.shade400,
                                trackOutlineColor: WidgetStateProperty.all(
                                  Colors.transparent,
                                ),
                              ),
                              Text(
                                _isReady ? 'Siap\nBertugas' : 'Tidak\nAktif',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _isReady
                                      ? primaryTeal
                                      : Colors.grey.shade600,
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
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  CupertinoIcons.exclamationmark_triangle_fill,
                                  color: Colors.white,
                                  size: 20,
                                ),
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
                                const Icon(
                                  CupertinoIcons.person_fill,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _activeTask!['pengguna']?['nama_lengkap'] ??
                                        'Pengguna',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  CupertinoIcons.location,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Lat: ${_activeTask!['latitude']}, Lng: ${_activeTask!['longitude']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
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
                                    await _volunteerDataSource.updateSosStatus(
                                      _activeTask!['id'],
                                      'selesai',
                                    );
                                    import_event_bus
                                        .GlobalEventBus
                                        .refreshMap
                                        .value = !import_event_bus
                                        .GlobalEventBus
                                        .refreshMap
                                        .value;
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Tugas diselesaikan!'),
                                        ),
                                      );
                                      _initVolunteerData();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Gagal menyelesaikan tugas: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(
                                  CupertinoIcons.checkmark_circle,
                                  color: Color(0xFF8B0000),
                                ),
                                label: const Text(
                                  'Selesaikan Tugas',
                                  style: TextStyle(
                                    color: Color(0xFF8B0000),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(
                                    0xFFFFCDD2,
                                  ).withValues(alpha: 0.9),
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
                                    Icon(
                                      CupertinoIcons.arrow_right,
                                      color: primaryTeal,
                                      size: 14,
                                    ),
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
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.8),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.map,
                                    size: 32,
                                    color: Colors.teal[700],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Gunakan tab Peta untuk melihat laporan.',
                                    style: TextStyle(
                                      color: Colors.teal[800],
                                      fontSize: 12,
                                    ),
                                  ),
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
                                  backgroundColor: Colors.red.withValues(
                                    alpha: 0.8,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons
                                        .exclamationmark_triangle_fill,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SOS AKTIF',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '$activeSosCount Kasus',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                  backgroundColor: primaryTeal.withValues(
                                    alpha: 0.8,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.doc_text,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TOTAL LAPORAN',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '$totalLaporan Laporan',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                      ..._riwayatList.take(_visibleRiwayatCount).map((item) {
                        final isSos = item['tipe'] == 'sos';
                        final title = item['kategori_display'] ?? (isSos ? 'Keadaan Darurat (SOS)' : 'Laporan');
                        
                        String desc = item['lokasi_display'] ?? '';
                        if (isSos && (desc.isEmpty || desc == 'Lokasi tidak diketahui' || desc == 'null')) {
                          desc = item['deskripsi_display'] ?? 'Permintaan bantuan darurat SOS';
                        }
                        
                        final timeStr = item['waktu_display'] ?? '';

                        String displayDate = timeStr;
                        try {
                           if (timeStr.isNotEmpty) {
                             String parseableDate = timeStr.replaceAll(' ', 'T');
                             if (!parseableDate.endsWith('Z') &&
                                 !parseableDate.contains('+') &&
                                 (!parseableDate.contains('T') ||
                                     parseableDate.indexOf('-', parseableDate.indexOf('T')) == -1)) {
                               parseableDate += 'Z';
                             }
                             DateTime parsedDate = DateTime.parse(parseableDate).toLocal();
                             String year = parsedDate.year.toString().padLeft(4, '0');
                             String month = parsedDate.month.toString().padLeft(2, '0');
                             String day = parsedDate.day.toString().padLeft(2, '0');
                             String hour = parsedDate.hour.toString().padLeft(2, '0');
                             String minute = parsedDate.minute.toString().padLeft(2, '0');
                             displayDate = '$year-$month-$day $hour:$minute';
                           }
                        } catch (e) {
                           if (timeStr.length >= 16) {
                             displayDate = timeStr.replaceAll('T', ' ').substring(0, 16);
                           }
                        }

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
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isSos
                                    ? Colors.red[100]
                                    : Colors.blue[100],
                                child: Icon(
                                  isSos
                                      ? CupertinoIcons
                                            .exclamationmark_triangle_fill
                                      : CupertinoIcons.doc_text_fill,
                                  color: isSos
                                      ? Colors.red[700]
                                      : Colors.blue[700],
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      desc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    if (displayDate.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        displayDate,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    if (_visibleRiwayatCount < _riwayatList.length)
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _visibleRiwayatCount += 5;
                            });
                          },
                          child: const Text('Muat Lebih Banyak'),
                        ),
                      ),
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

