import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart'
    as import_event_bus;
import '../../volunteer_task/presentation/volunteer_active_task_page.dart'
    as import_active_task;
import '../../volunteer_task/presentation/widgets/glass_container.dart';
import '../../volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/di/injection.dart';
import '../../../core/constants/api_constants.dart';

class VolunteerDashboardPage extends StatefulWidget {
  const VolunteerDashboardPage({super.key});

  @override
  State<VolunteerDashboardPage> createState() => _VolunteerDashboardPageState();
}

class _VolunteerDashboardPageState extends State<VolunteerDashboardPage> {
  static const Color bgColor = Color(0xFFF5F6F8);
  static const Color primaryTeal = Color(0xFF006D77);
  static const Color sosRed = Color(0xFFC62828);

  bool _isReady = false;
  int? _volunteerId;
  final _volunteerDataSource = sl<VolunteerRemoteDataSource>();

  Map<String, dynamic>? _berandaData;
  Map<String, dynamic>? _activeTask;
  String _activeTaskLokasi = '';
  List<dynamic> _riwayatList = [];
  bool _isLoading = true;
  int _visibleRiwayatCount = 5;

  // Profil relawan
  String _userName = 'Relawan';
  String? _userAvatar;
  String _verificationStatus = 'pending';
  String _userLocation = '';

  @override
  void initState() {
    super.initState();
    _initVolunteerData();
    import_event_bus.GlobalEventBus.refreshMap.addListener(_onRefreshMapEvent);
  }

  void _onRefreshMapEvent() {
    if (mounted) {
      _initVolunteerData();
    }
  }

  Future<void> _initVolunteerData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = sl<SharedPreferences>();
      final cachedStatus = prefs.getString('verification_status');
      final cachedActive = prefs.getBool('user_is_active') ?? true;
      final isVerifiedAndActive = (cachedStatus == 'terverifikasi') && cachedActive;

      // 1. Ambil data beranda & statistik sistem (hanya jika terverifikasi dan aktif)
      if (isVerifiedAndActive) {
        try {
          final berandaRes = await _volunteerDataSource.getBeranda();
          _berandaData = berandaRes;
        } catch (e) {
          debugPrint("Gagal load beranda data: $e");
        }

        // 2. Ambil tugas aktif relawan ini
        try {
          final tasks = await _volunteerDataSource.getRelawanTasks();
          if (tasks['data'] != null) {
            _activeTask = tasks['data'];
            // Resolve lokasi tugas aktif ke nama wilayah
            _activeTaskLokasi = await _parseLokasiDisplay(_activeTask!);
          } else {
            _activeTask = null;
            _activeTaskLokasi = '';
          }
        } catch (e) {
          _activeTask = null;
          _activeTaskLokasi = '';
          debugPrint("Gagal load tugas aktif: $e");
        }

        // 3. Ambil riwayat penanganan tugas relawan
        try {
          final riwayatData =
              await _volunteerDataSource.getRelawanBerandaRiwayat();
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
                item['kategori_display'] = item['kategori'] ??
                    item['kategori_laporan'] ??
                    'Laporan';
                combinedHistory.add(item);
              } else {
                combinedHistory.add(item);
              }
            }
          }

          // Urutkan dari yang terbaru
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
      } else {
        _activeTask = null;
        _activeTaskLokasi = '';
        _riwayatList = [];
      }

      // 4. Ambil profil relawan untuk inisialisasi WebSocket & status verifikasi
      try {
        final profileRes = await _volunteerDataSource.getRelawanProfile();
        final userData = profileRes['user'];

        if (userData != null && userData['id'] != null) {
          _userName = userData['name'] ?? 'Relawan';
          _userAvatar = userData['foto_profile'];
          _verificationStatus =
              (userData['status_verifikasi'] ?? 'pending').toString().toLowerCase();
          _userLocation = userData['lokasi_user'] ?? '';

          final statusKetersediaan =
              userData['status_ketersediaan']?.toString().toLowerCase();
          _isReady = (statusKetersediaan == 'tersedia' ||
              statusKetersediaan == 'aktif' ||
              statusKetersediaan == null);

          _volunteerId = (userData['id'] is int)
              ? userData['id'] as int
              : int.tryParse(userData['id'].toString());

          final isActive = (userData['is_active'] == true || userData['is_active'] == 1);
          if (_volunteerId != null) {
            await prefs.setInt('volunteer_id', _volunteerId!);
          }
          await prefs.setString('verification_status', _verificationStatus);
          await prefs.setBool('user_is_active', isActive);
          import_event_bus.GlobalEventBus.volunteerVerificationStatus.value = (_verificationStatus == 'terverifikasi');
          import_event_bus.GlobalEventBus.volunteerActiveStatus.value = isActive;

          if (_verificationStatus == 'terverifikasi' && isActive) {
            final token = prefs.getString('auth_token');
            if (token != null) {
              await WebsocketService.init(token);
            }

            if (_volunteerId != null && _isReady) {
              WebsocketService.listenToNewSosForVolunteer(
                _volunteerId!,
                _onNewSosReceived,
              );
            }
          }
        }
      } catch (e) {
        debugPrint("Gagal load profil relawan: $e");
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
    debugPrint("SOS Baru Masuk via Websocket di Dashboard: $eventData");
  }

  @override
  void dispose() {
    import_event_bus.GlobalEventBus.refreshMap.removeListener(_onRefreshMapEvent);
    super.dispose();
  }



  /// Resolve lokasi item menjadi teks dukuh/desa/kecamatan/kabupaten.
  Future<String> _parseLokasiDisplay(Map<String, dynamic> item) async {
    double? lat = _toDouble(item['latitude']);
    double? lng = _toDouble(item['longitude']);

    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = [
            place.subLocality,
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ].where((e) => e != null && e.isNotEmpty).toList();
          if (parts.isNotEmpty) return parts.join(', ');
        }
      } catch (_) {}
    }

    final raw = (item['lokasi_user'] ??
            item['lokasi_laporan'] ??
            item['lokasi'] ??
            '')
        .toString();
    final alamatMatch = RegExp(r'alamat:\s*([^,}]+)').firstMatch(raw);
    if (alamatMatch != null) {
      final alamat = alamatMatch.group(1)!.trim();
      if (alamat.isNotEmpty) return alamat;
    }
    if (raw.isNotEmpty && raw != 'null') return raw;
    return 'Lokasi tidak tersedia';
  }

  double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  Future<void> _toggleReadyStatus(bool val) async {
    // Cegah aktivasi jika akun relawan belum terverifikasi oleh admin
    if (val && _verificationStatus != 'terverifikasi') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _verificationStatus == 'ditolak'
                ? 'Akun relawan Anda telah ditolak oleh admin.'
                : 'Akun Anda masih dalam verifikasi admin. Belum dapat mengaktifkan status siaga.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      _isReady = val;
    });

    // Sesuaikan langganan WebSocket secara real-time
    if (_volunteerId != null) {
      if (val) {
        debugPrint("🟢 Mengaktifkan penerimaan panggilan SOS untuk relawan ID: $_volunteerId");
        WebsocketService.listenToNewSosForVolunteer(
          _volunteerId!,
          _onNewSosReceived,
        );
      } else {
        debugPrint("🔴 Menonaktifkan penerimaan panggilan SOS untuk relawan ID: $_volunteerId");
        WebsocketService.stopListeningNewSosForVolunteer(_volunteerId!);
      }
    }

    try {
      final statusStr = val ? 'tersedia' : 'tidak_tersedia';
      await _volunteerDataSource.updateStatusKetersediaan(statusStr);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isReady = !val;
      });

      // Rollback status socket jika API gagal
      if (_volunteerId != null) {
        if (!val) {
          WebsocketService.listenToNewSosForVolunteer(
            _volunteerId!,
            _onNewSosReceived,
          );
        } else {
          WebsocketService.stopListeningNewSosForVolunteer(_volunteerId!);
        }
      }

      final errorMsg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _callEmergency() async {
    final uri = Uri.parse('tel:112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat melakukan panggilan ke 112')),
      );
    }
  }

  void _showPanduanModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Icon(CupertinoIcons.book_fill, color: primaryTeal, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Panduan SOP Relawan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryTeal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSopStep(
                  '1',
                  'Pastikan Kesiapan Diri',
                  'Jaga kondisi fisik, periksa baterai smartphone, dan pastikan GPS dalam keadaan aktif.',
                ),
                _buildSopStep(
                  '2',
                  'Konfirmasi Panggilan Darurat',
                  'Saat notifikasi darurat masuk, baca lokasi & jenis panggilan secara seksama sebelum menerima.',
                ),
                _buildSopStep(
                  '3',
                  'Menuju Lokasi & Komunikasi',
                  'Gunakan tab Peta untuk panduan rute. Hubungi korban atau kontak darurat bila situasi memungkinkan.',
                ),
                _buildSopStep(
                  '4',
                  'Pertolongan Pertama (P3K)',
                  'Amankan lokasi sekitar korban, berikan pertolongan pertama, dan hubungi faskes atau 112 jika kritis.',
                ),
                _buildSopStep(
                  '5',
                  'Selesaikan Tugas',
                  'Setelah korban aman atau tertangani oleh pihak medis/aparat, tekan tombol "Selesaikan Tugas".',
                ),
                const Divider(height: 28),
                const Text(
                  'Nomor Darurat Penting',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildEmergencyChip('112', 'Panggilan Darurat Terpadu'),
                    _buildEmergencyChip('118 / 119', 'Ambulans / Faskes'),
                    _buildEmergencyChip('110', 'Kepolisian'),
                    _buildEmergencyChip('113', 'Pemadam Kebakaran'),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Saya Mengerti',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSopStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: primaryTeal.withValues(alpha: 0.15),
            child: Text(
              number,
              style: const TextStyle(
                color: primaryTeal,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyChip(String number, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.phone_fill, size: 12, color: primaryTeal),
          const SizedBox(width: 6),
          Text(
            '$number ($label)',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: primaryTeal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CupertinoActivityIndicator(radius: 16)),
      );
    }

    final summary = _berandaData?['summary'] ?? {};
    final activeSosCount = summary['active_sos'] ?? 0;
    final totalLaporan = summary['total_laporan'] ?? 0;
    final completedTaskCount = _riwayatList.length;
    final isVerified = _verificationStatus == 'terverifikasi';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _initVolunteerData,
          color: primaryTeal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header & Identitas Relawan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 28,
                          height: 28,
                        ),
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
                  ],
                ),
                const SizedBox(height: 16),

                // Greeting Relawan
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: primaryTeal.withValues(alpha: 0.1),
                      backgroundImage: (_userAvatar != null &&
                              _userAvatar!.isNotEmpty)
                          ? NetworkImage(
                              _userAvatar!.startsWith('http')
                                  ? _userAvatar!
                                  : '${ApiConstants.storageUrl}/$_userAvatar',
                            )
                          : null,
                      child: (_userAvatar == null || _userAvatar!.isEmpty)
                          ? const Icon(
                              CupertinoIcons.person_solid,
                              color: primaryTeal,
                              size: 24,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Halo, $_userName 👋',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isVerified
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isVerified
                                        ? const Color(0xFFA5D6A7)
                                        : const Color(0xFFFFCC80),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isVerified
                                          ? CupertinoIcons.checkmark_seal_fill
                                          : CupertinoIcons.clock_fill,
                                      size: 12,
                                      color: isVerified
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFEF6C00),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isVerified ? 'Terverifikasi' : 'Pending',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isVerified
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFEF6C00),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _userLocation.isNotEmpty
                                ? 'Wilayah Siaga: $_userLocation'
                                : 'Siap memberikan bantuan darurat',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. Status Kesiagaan Relawan (Duty Switch)
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isReady
                              ? const Color(0xFFE8F5E9)
                              : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isReady
                              ? CupertinoIcons.radiowaves_right
                              : CupertinoIcons.slash_circle,
                          color: _isReady ? primaryTeal : Colors.grey.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isReady
                                  ? 'Status: Siap Bertugas'
                                  : 'Status: Tidak Aktif',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _isReady
                                    ? primaryTeal
                                    : Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              !isVerified
                                  ? (_verificationStatus == 'ditolak'
                                      ? 'Akun ditolak. Hubungi admin untuk verifikasi ulang.'
                                      : 'Menunggu verifikasi admin. Radar darurat belum dapat diaktifkan.')
                                  : (_isReady
                                      ? 'Radar aktif. Anda dapat menerima panggilan darurat otomatis.'
                                      : 'Sedang istirahat. Sistem tidak akan mengirim panggilan darurat.'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _isReady,
                        onChanged: isVerified
                            ? _toggleReadyStatus
                            : (val) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _verificationStatus == 'ditolak'
                                          ? 'Akun relawan Anda telah ditolak oleh admin.'
                                          : 'Akun relawan Anda belum diverifikasi oleh admin.',
                                    ),
                                    backgroundColor: Colors.orange.shade800,
                                  ),
                                );
                              },
                        activeThumbColor: Colors.white,
                        activeTrackColor: primaryTeal,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: isVerified
                            ? Colors.grey.shade400
                            : Colors.grey.shade300,
                        trackOutlineColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Status Tugas Berjalan / Hero Banner
                if (_activeTask != null) ...[
                  const Text(
                    'Tugas Darurat Aktif',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: sosRed,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    color: sosRed.withValues(alpha: 0.85),
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
                            Expanded(
                              child: Text(
                                'Panggilan Darurat Sedang Ditangani',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
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
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _activeTask!['pengguna']?['name'] ??
                                    _activeTask!['pengguna']?['nama_lengkap'] ??
                                    'Pengguna Korban',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              CupertinoIcons.location_solid,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _activeTaskLokasi.isNotEmpty
                                    ? _activeTaskLokasi
                                    : 'Memuat lokasi...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          import_active_task
                                              .VolunteerActiveTaskPage(
                                        initialTask: _activeTask,
                                      ),
                                    ),
                                  ).then((_) => _initVolunteerData());
                                },
                                icon: const Icon(
                                  CupertinoIcons.map,
                                  size: 16,
                                  color: sosRed,
                                ),
                                label: const Text(
                                  'Buka Rute & Detail',
                                  style: TextStyle(
                                    color: sosRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  // Card Status Siaga Tenang
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2F1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            CupertinoIcons.shield_lefthalf_fill,
                            color: primaryTeal,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tidak Ada Tugas Berjalan',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Area aman. Notifikasi darurat akan langsung muncul saat warga membutuhkan pertolongan.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 4. Aksi Cepat Relawan (Quick Actions)
                const Text(
                  'Aksi Cepat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildQuickAction(
                      icon: CupertinoIcons.map_fill,
                      label: 'Radar Peta',
                      color: primaryTeal,
                      onTap: () {
                        import_event_bus.GlobalEventBus.changeVolunteerTab
                            .value = 2; // Pindah ke tab Peta
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildQuickAction(
                      icon: CupertinoIcons.doc_text_fill,
                      label: 'Daftar Tugas',
                      color: const Color(0xFF1976D2),
                      onTap: () {
                        import_event_bus.GlobalEventBus.changeVolunteerTab
                            .value = 1; // Pindah ke tab Tugas
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildQuickAction(
                      icon: CupertinoIcons.phone_fill,
                      label: 'Panggil 112',
                      color: sosRed,
                      onTap: _callEmergency,
                    ),
                    const SizedBox(width: 10),
                    _buildQuickAction(
                      icon: CupertinoIcons.book_fill,
                      label: 'Panduan SOP',
                      color: const Color(0xFFF57C00),
                      onTap: _showPanduanModal,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 5. Statistik Sistem & Kontribusi
                const Text(
                  'Statistik & Situasi Terkini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatTile(
                        icon: CupertinoIcons.exclamationmark_triangle_fill,
                        iconColor: sosRed,
                        title: 'SOS AKTIF',
                        value: '$activeSosCount',
                        unit: 'Kasus',
                        bgIconColor: Colors.red.shade50,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatTile(
                        icon: CupertinoIcons.doc_text_fill,
                        iconColor: const Color(0xFF1976D2),
                        title: 'LAPORAN',
                        value: '$totalLaporan',
                        unit: 'Warga',
                        bgIconColor: Colors.blue.shade50,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatTile(
                        icon: CupertinoIcons.checkmark_seal_fill,
                        iconColor: primaryTeal,
                        title: 'KONTRIBUSI',
                        value: '$completedTaskCount',
                        unit: 'Selesai',
                        bgIconColor: const Color(0xFFE0F2F1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 6. Preview Peta Wilayah
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Peta Wilayah & Sebaran',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              import_event_bus.GlobalEventBus
                                  .changeVolunteerTab.value = 2;
                            },
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
                      GestureDetector(
                        onTap: () {
                          import_event_bus.GlobalEventBus.changeVolunteerTab
                              .value = 2;
                        },
                        child: Container(
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.map_pin_ellipse,
                                  size: 32,
                                  color: Colors.teal.shade700,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Ketuk untuk melihat radar sebaran laporan & SOS',
                                  style: TextStyle(
                                    color: Colors.teal.shade900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 7. Riwayat Tugas Terselesaikan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Riwayat Tugas Penanganan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '$completedTaskCount tugas',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_riwayatList.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.tray,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada riwayat penanganan tugas',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._riwayatList.take(_visibleRiwayatCount).map((item) {
                    final isSos = item['tipe'] == 'sos';
                    final title = item['kategori_display'] ??
                        (isSos ? 'Keadaan Darurat (SOS)' : 'Laporan Warga');

                    String desc = item['lokasi_display'] ?? '';
                    if (isSos &&
                        (desc.isEmpty ||
                            desc == 'Lokasi tidak diketahui' ||
                            desc == 'null')) {
                      desc = item['deskripsi_display'] ??
                          'Permintaan bantuan darurat SOS';
                    }

                    final timeStr = item['waktu_display'] ?? '';
                    String displayDate = timeStr;
                    try {
                      if (timeStr.isNotEmpty) {
                        String parseableDate = timeStr.replaceAll(' ', 'T');
                        if (!parseableDate.endsWith('Z') &&
                            !parseableDate.contains('+') &&
                            (!parseableDate.contains('T') ||
                                parseableDate.indexOf(
                                      '-',
                                      parseableDate.indexOf('T'),
                                    ) ==
                                    -1)) {
                          parseableDate += 'Z';
                        }
                        DateTime parsedDate =
                            DateTime.parse(parseableDate).toLocal();
                        String year =
                            parsedDate.year.toString().padLeft(4, '0');
                        String month =
                            parsedDate.month.toString().padLeft(2, '0');
                        String day =
                            parsedDate.day.toString().padLeft(2, '0');
                        String hour =
                            parsedDate.hour.toString().padLeft(2, '0');
                        String minute =
                            parsedDate.minute.toString().padLeft(2, '0');
                        displayDate = '$year-$month-$day $hour:$minute';
                      }
                    } catch (_) {
                      if (timeStr.length >= 16) {
                        displayDate =
                            timeStr.replaceAll('T', ' ').substring(0, 16);
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
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
                            radius: 18,
                            backgroundColor: isSos
                                ? Colors.red.shade100
                                : Colors.blue.shade100,
                            child: Icon(
                              isSos
                                  ? CupertinoIcons
                                      .exclamationmark_triangle_fill
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
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius:
                                            BorderRadius.circular(6),
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
                                const SizedBox(height: 3),
                                Text(
                                  desc,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                if (displayDate.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    displayDate,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
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
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _visibleRiwayatCount += 5;
                        });
                      },
                      icon: const Icon(
                        CupertinoIcons.chevron_down,
                        size: 14,
                        color: primaryTeal,
                      ),
                      label: const Text(
                        'Muat Lebih Banyak',
                        style: TextStyle(
                          color: primaryTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String unit,
    required Color bgIconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: bgIconColor,
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
