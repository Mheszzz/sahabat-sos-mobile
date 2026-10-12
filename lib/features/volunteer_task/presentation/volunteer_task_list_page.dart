import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geocoding/geocoding.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/presentation/volunteer_active_task_page.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/presentation/widgets/glass_container.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart' as import_event_bus;

class VolunteerTaskListPage extends StatefulWidget {
  const VolunteerTaskListPage({super.key});

  @override
  State<VolunteerTaskListPage> createState() => _VolunteerTaskListPageState();
}

class _VolunteerTaskListPageState extends State<VolunteerTaskListPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryTeal = Color(0xFF006D77);
  static const Color sosRed = Color(0xFFC62828);
  static const Color bgColor = Color(0xFFF5F6F8);

  final _dataSource = sl<VolunteerRemoteDataSource>();
  bool _isLoading = true;
  List<dynamic> _availableSosList = [];
  List<dynamic> _availableLaporanList = [];
  Map<String, dynamic>? _activeTask;
  List<dynamic> _riwayatList = [];
  int _visibleRiwayatCount = 5;
  // Cache lokasi yang sudah di-resolve (key: item id sebagai string)
  final Map<String, String> _lokasiCache = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
    import_event_bus.GlobalEventBus.refreshMap.addListener(_onWebSocketUpdate);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      final prefs = sl<SharedPreferences>();
      final cachedStatus = prefs.getString('verification_status');
      final cachedActive = prefs.getBool('user_is_active') ?? true;
      if (cachedStatus != 'terverifikasi' || !cachedActive) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 1. Tugas aktif relawan
      final activeRes = await _dataSource.getRelawanTasks();
      _activeTask = activeRes['data'];

      // 2. Daftar tugas tersedia
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
        final List<dynamic> allData =
            response.data['data'] is List ? response.data['data'] : [];
        // Exclude item yang sedang ditangani (id sama dengan tugas aktif)
        final activeId = _activeTask?['id'];
        final filtered = allData.where((e) => e['id'] != activeId).toList();
        _availableSosList = filtered
            .where((e) => e['tipe'] == 'sos' || e['kategori_laporan'] == 'SOS')
            .toList();
        _availableLaporanList = filtered
            .where((e) =>
                e['tipe'] == 'laporan' ||
                (e['tipe'] != 'sos' && e['kategori_laporan'] != 'SOS'))
            .toList();
      }

      // 3. Riwayat tugas selesai
      try {
        final riwayatData = await _dataSource.getRelawanBerandaRiwayat();
        final List<dynamic> combinedHistory = [];
        final rawData = riwayatData['data'];

        if (rawData != null && rawData is List) {
          for (var item in rawData) {
            if (item is Map<String, dynamic>) {
              item['tipe'] = item['tipe'] ?? 'laporan';
              item['waktu_display'] = item['waktu'] ??
                  item['waktu_laporan'] ??
                  item['waktu_sos'] ??
                  item['created_at'] ??
                  '';
              item['lokasi_display'] = item['lokasi'] ??
                  item['lokasi_laporan'] ??
                  item['lokasi_user'] ??
                  'Lokasi tidak diketahui';
              item['deskripsi_display'] = item['deskripsi'] ?? '';
              item['kategori_display'] =
                  item['kategori'] ?? item['kategori_laporan'] ?? 'Laporan';
              combinedHistory.add(item);
            } else {
              combinedHistory.add(item);
            }
          }
        }

        combinedHistory.sort((a, b) {
          final String dateA = a is Map ? (a['waktu_display'] ?? '') : '';
          final String dateB = b is Map ? (b['waktu_display'] ?? '') : '';
          final timeA = DateTime.tryParse(dateA) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final timeB = DateTime.tryParse(dateB) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return timeB.compareTo(timeA);
        });

        _riwayatList = combinedHistory;
      } catch (e) {
        _riwayatList = [];
        debugPrint('Gagal load riwayat tugas: $e');
      }

      // 4. Resolve lokasi semua item ke cache (SOS, Laporan, Riwayat)
      final allItems = [
        ..._availableSosList,
        ..._availableLaporanList,
        ..._riwayatList,
        ...?(_activeTask != null ? [_activeTask!] : null),
      ];
      await Future.wait(allItems.map((item) async {
        final key = '${item['id']}_${item['tipe'] ?? ''}';
        if (!_lokasiCache.containsKey(key)) {
          _lokasiCache[key] = await _parseLokasiDisplay(item);
        }
      }));
    } catch (e) {
      debugPrint('Error fetch task list: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getLokasi(Map<String, dynamic> item) {
    final key = '${item['id']}_${item['tipe'] ?? ''}';
    return _lokasiCache[key] ?? 'Memuat lokasi...';
  }

  void _navigateToDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VolunteerActiveTaskPage()),
    ).then((_) => _fetchData());
  }

  /// Parse lokasi menjadi teks dukuh/desa/kecamatan/kabupaten.
  /// 1. Coba geocoding dari lat/lng
  /// 2. Fallback: parse field 'alamat:...' dari string lokasi
  /// 3. Fallback: nilai string mentah
  Future<String> _parseLokasiDisplay(Map<String, dynamic> item) async {
    // Ambil lat/lng dari berbagai kemungkinan field
    double? lat = _toDouble(item['latitude']);
    double? lng = _toDouble(item['longitude']);

    // Jika ada koordinat valid, geocode ke nama wilayah
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = [
            place.subLocality,       // dukuh/kelurahan
            place.locality,          // desa/kota
            place.subAdministrativeArea, // kecamatan
            place.administrativeArea,    // kabupaten/provinsi
          ].where((e) => e != null && e.isNotEmpty).toList();
          if (parts.isNotEmpty) return parts.join(', ');
        }
      } catch (_) {}
    }

    // Fallback: parse string lokasi
    final raw = (item['lokasi_user'] ??
            item['lokasi_laporan'] ??
            item['lokasi'] ??
            item['lokasi_display'] ??
            '')
        .toString();

    // Coba ekstrak field 'alamat:' dari string JSON-like
    final alamatMatch =
        RegExp(r'alamat:\s*([^,}]+)').firstMatch(raw);
    if (alamatMatch != null) {
      final alamat = alamatMatch.group(1)!.trim();
      if (alamat.isNotEmpty) return alamat;
    }

    if (raw.isNotEmpty &&
        raw != 'Lokasi tidak diketahui' &&
        raw != 'null') {
      return raw;
    }

    return 'Lokasi tidak tersedia';
  }

  double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  Future<void> _acceptTask(int id) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CupertinoActivityIndicator(radius: 16)),
      );
      await _dataSource.updateSosStatus(id, 'ditangani');
      if (mounted) Navigator.pop(context);
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

  String _formatDate(String timeStr) {
    try {
      if (timeStr.isEmpty) return '';
      String parseableDate = timeStr.replaceAll(' ', 'T');
      if (!parseableDate.endsWith('Z') &&
          !parseableDate.contains('+') &&
          (!parseableDate.contains('T') ||
              parseableDate.indexOf('-', parseableDate.indexOf('T')) == -1)) {
        parseableDate += 'Z';
      }
      final parsedDate = DateTime.parse(parseableDate).toLocal();
      final y = parsedDate.year.toString().padLeft(4, '0');
      final mo = parsedDate.month.toString().padLeft(2, '0');
      final d = parsedDate.day.toString().padLeft(2, '0');
      final h = parsedDate.hour.toString().padLeft(2, '0');
      final mi = parsedDate.minute.toString().padLeft(2, '0');
      return '$y-$mo-$d $h:$mi';
    } catch (_) {
      return timeStr.length >= 16
          ? timeStr.replaceAll('T', ' ').substring(0, 16)
          : timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header (sama dengan Beranda) ──────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/images/logo.png',
                          width: 28, height: 28),
                      const SizedBox(width: 8),
                      const Text(
                        'Sahabat SOS',
                        style: TextStyle(
                          color: primaryTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _fetchData,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(CupertinoIcons.refresh,
                          color: primaryTeal, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab Bar ───────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: primaryTeal,
                unselectedLabelColor: Colors.grey,
                indicator: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'SOS Darurat'),
                  Tab(text: 'Laporan'),
                  Tab(text: 'Riwayat'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Tab Content ───────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CupertinoActivityIndicator(radius: 16))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAvailableTab(_availableSosList, true),
                        _buildAvailableTab(_availableLaporanList, false),
                        _buildRiwayatTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Kasus SOS & Laporan ─────────────────────────────────────────────
  Widget _buildAvailableTab(List<dynamic> list, bool isSos) {
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: primaryTeal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          // Tugas aktif (sedang ditangani)
          if (_activeTask != null) ...[
            const Text(
              'Sedang Ditangani',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: sosRed,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _navigateToDetail,
              child: GlassContainer(
                padding: const EdgeInsets.all(16),
                color: sosRed.withValues(alpha: 0.85),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.shield_fill,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kasus Aktif (ID: ${_activeTask!['id']})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _activeTask!['pengguna']?['name'] ??
                                'Pelapor Anonim',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_right,
                        color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Label tersedia
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSos ? 'SOS Darurat Tersedia' : 'Laporan Tersedia',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSos
                      ? sosRed.withValues(alpha: 0.1)
                      : primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${list.length} kasus',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSos ? sosRed : primaryTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (list.isEmpty)
            _buildEmptyState(
              icon: CupertinoIcons.checkmark_shield,
              message: isSos
                  ? 'Belum ada SOS darurat baru'
                  : 'Belum ada laporan baru',
            )
          else
            ...list.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSos
                                    ? sosRed.withValues(alpha: 0.1)
                                    : primaryTeal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isSos
                                    ? CupertinoIcons
                                        .exclamationmark_triangle_fill
                                    : CupertinoIcons.doc_text_fill,
                                color: isSos ? sosRed : primaryTeal,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${isSos ? 'SOS Darurat' : 'Laporan'} · ID ${item['id']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Baru',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.person_solid,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item['pengguna']?['name'] ??
                                    item['relawan']?['name'] ??
                                    'Korban',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.location_solid,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _getLokasi(item),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isSos ? sosRed : primaryTeal,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            icon: Icon(
                              isSos
                                  ? CupertinoIcons.shield_fill
                                  : CupertinoIcons.checkmark_circle_fill,
                              color: Colors.white,
                              size: 16,
                            ),
                            onPressed: () {
                              if (_activeTask != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Selesaikan tugas aktif Anda terlebih dahulu!')),
                                );
                              } else {
                                _acceptTask(item['id']);
                              }
                            },
                            label: Text(
                              isSos ? 'Tolong Sekarang' : 'Tangani Laporan',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  // ── Tab Riwayat ─────────────────────────────────────────────────────────
  Widget _buildRiwayatTab() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: primaryTeal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          // Stat kecil
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Riwayat Tugas Selesai',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_riwayatList.length} tugas',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_riwayatList.isEmpty)
            _buildEmptyState(
              icon: CupertinoIcons.tray,
              message: 'Belum ada riwayat tugas yang diselesaikan',
            )
          else ...[
            ..._riwayatList.take(_visibleRiwayatCount).map((item) {
              final isSos = item['tipe'] == 'sos';
              final title = item['kategori_display'] ??
                  (isSos ? 'SOS Darurat' : 'Laporan Warga');
              final lokasi = _getLokasi(item);
              final displayDate =
                  _formatDate(item['waktu_display'] ?? '');

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isSos
                          ? Colors.red.shade100
                          : Colors.blue.shade100,
                      child: Icon(
                        isSos
                            ? CupertinoIcons.exclamationmark_triangle_fill
                            : CupertinoIcons.doc_text_fill,
                        color: isSos
                            ? Colors.red.shade700
                            : Colors.blue.shade700,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Selesai',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Nama pelapor
                          Row(
                            children: [
                              Icon(CupertinoIcons.person_solid,
                                  size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item['pengguna']?['name'] ??
                                      item['pengguna']?['nama_lengkap'] ??
                                      item['relawan']?['name'] ??
                                      'Anonim',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // Lokasi
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(CupertinoIcons.location_solid,
                                  size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  lokasi,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (displayDate.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(CupertinoIcons.clock,
                                    size: 11,
                                    color: Colors.grey.shade400),
                                const SizedBox(width: 4),
                                Text(
                                  displayDate,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
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
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _visibleRiwayatCount += 5);
                  },
                  icon: const Icon(CupertinoIcons.chevron_down,
                      size: 14, color: primaryTeal),
                  label: const Text(
                    'Muat Lebih Banyak',
                    style: TextStyle(
                      color: primaryTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
