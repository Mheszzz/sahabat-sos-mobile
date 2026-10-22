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
import '../../../core/services/accessibility_service.dart';
import '../../../core/theme/accessible_colors.dart';
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
    final double? lat = _toDouble(item['latitude']);
    final double? lng = _toDouble(item['longitude']);

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
    final isHighContrast =
        AccessibilityService.instance.isHighContrastEnabled ||
        Theme.of(context).brightness == Brightness.dark ||
        MediaQuery.of(context).highContrast;
    final sheetBg = AccessibleColors.cardBackground(isHighContrast);
    final textPrimary = AccessibleColors.textPrimary(isHighContrast);
    final textSecondary = AccessibleColors.textSecondary(isHighContrast);
    final tealColor =
        isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: isHighContrast
              ? const Border(
                  top: BorderSide(color: Color(0xFF4B5563), width: 1.5),
                  left: BorderSide(color: Color(0xFF4B5563), width: 1.5),
                  right: BorderSide(color: Color(0xFF4B5563), width: 1.5),
                )
              : null,
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
                      color: isHighContrast
                          ? const Color(0xFF4B5563)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(CupertinoIcons.book_fill, color: tealColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Panduan SOP Relawan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tealColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSopStep(
                  '1',
                  'Pastikan Kesiapan Diri',
                  'Jaga kondisi fisik, periksa baterai smartphone, dan pastikan GPS dalam keadaan aktif.',
                  isHighContrast,
                  textPrimary,
                  textSecondary,
                  tealColor,
                ),
                _buildSopStep(
                  '2',
                  'Konfirmasi Panggilan Darurat',
                  'Saat notifikasi darurat masuk, baca lokasi & jenis panggilan secara seksama sebelum menerima.',
                  isHighContrast,
                  textPrimary,
                  textSecondary,
                  tealColor,
                ),
                _buildSopStep(
                  '3',
                  'Menuju Lokasi & Komunikasi',
                  'Gunakan tab Peta untuk panduan rute. Hubungi korban atau kontak darurat bila situasi memungkinkan.',
                  isHighContrast,
                  textPrimary,
                  textSecondary,
                  tealColor,
                ),
                _buildSopStep(
                  '4',
                  'Pertolongan Pertama (P3K)',
                  'Amankan lokasi sekitar korban, berikan pertolongan pertama, dan hubungi faskes atau 112 jika kritis.',
                  isHighContrast,
                  textPrimary,
                  textSecondary,
                  tealColor,
                ),
                _buildSopStep(
                  '5',
                  'Selesaikan Tugas',
                  'Setelah korban aman atau tertangani oleh pihak medis/aparat, tekan tombol "Selesaikan Tugas".',
                  isHighContrast,
                  textPrimary,
                  textSecondary,
                  tealColor,
                ),
                Divider(
                  height: 28,
                  color: isHighContrast ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                ),
                Text(
                  'Nomor Darurat Penting',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildEmergencyChip(
                      '112',
                      'Panggilan Darurat Terpadu',
                      isHighContrast,
                      tealColor,
                    ),
                    _buildEmergencyChip(
                      '118 / 119',
                      'Ambulans / Faskes',
                      isHighContrast,
                      tealColor,
                    ),
                    _buildEmergencyChip(
                      '110',
                      'Kepolisian',
                      isHighContrast,
                      tealColor,
                    ),
                    _buildEmergencyChip(
                      '113',
                      'Pemadam Kebakaran',
                      isHighContrast,
                      tealColor,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isHighContrast ? const Color(0xFF00897B) : primaryTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isHighContrast
                            ? const BorderSide(color: Color(0xFF80CBC4), width: 1.5)
                            : BorderSide.none,
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

  Widget _buildSopStep(
    String number,
    String title,
    String description,
    bool isHighContrast,
    Color textPrimary,
    Color textSecondary,
    Color tealColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isHighContrast
                ? tealColor.withValues(alpha: 0.2)
                : primaryTeal.withValues(alpha: 0.15),
            child: Text(
              number,
              style: TextStyle(
                color: tealColor,
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyChip(
    String number,
    String label,
    bool isHighContrast,
    Color tealColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighContrast ? const Color(0xFF1E2430) : const Color(0xFFF0FDF4),
        border: Border.all(
          color: isHighContrast ? const Color(0xFF4B5563) : const Color(0xFFBBF7D0),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.phone_fill, size: 12, color: tealColor),
          const SizedBox(width: 6),
          Text(
            '$number ($label)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tealColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;
        final currentBg = isHighContrast ? Colors.black : bgColor;
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
        final textPrimary = AccessibleColors.textPrimary(isHighContrast);
        final textSecondary = AccessibleColors.textSecondary(isHighContrast);

        if (_isLoading) {
          return Scaffold(
            backgroundColor: currentBg,
            body: Center(
              child: CupertinoActivityIndicator(
                radius: 16,
                color: tealColor,
              ),
            ),
          );
        }

        final summary = _berandaData?['summary'] ?? {};
        final activeSosCount = summary['active_sos'] ?? 0;
        final totalLaporan = summary['total_laporan'] ?? 0;
        final completedTaskCount = _riwayatList.length;
        final isVerified = _verificationStatus == 'terverifikasi';

        return Scaffold(
          backgroundColor: currentBg,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _initVolunteerData,
              color: tealColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16.0,
                ),
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
                            Text(
                              'Sahabat SOS',
                              style: TextStyle(
                                color: tealColor,
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
                          backgroundColor: isHighContrast
                              ? const Color(0xFF1E2430)
                              : primaryTeal.withValues(alpha: 0.1),
                          backgroundImage: (_userAvatar != null &&
                                  _userAvatar!.isNotEmpty)
                              ? NetworkImage(
                                  _userAvatar!.startsWith('http')
                                      ? _userAvatar!
                                      : '${ApiConstants.storageUrl}/$_userAvatar',
                                )
                              : null,
                          child: (_userAvatar == null || _userAvatar!.isEmpty)
                              ? Icon(
                                  CupertinoIcons.person_solid,
                                  color: tealColor,
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
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
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
                                      color: isHighContrast
                                          ? (isVerified
                                              ? const Color(0xFF064E3B)
                                              : const Color(0xFF451A03))
                                          : (isVerified
                                              ? const Color(0xFFE8F5E9)
                                              : const Color(0xFFFFF3E0)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isHighContrast
                                            ? (isVerified
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFF59E0B))
                                            : (isVerified
                                                ? const Color(0xFFA5D6A7)
                                                : const Color(0xFFFFCC80)),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isVerified
                                              ? CupertinoIcons
                                                  .checkmark_seal_fill
                                              : CupertinoIcons.clock_fill,
                                          size: 12,
                                          color: isHighContrast
                                              ? (isVerified
                                                  ? const Color(0xFFA7F3D0)
                                                  : const Color(0xFFFDE68A))
                                              : (isVerified
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFEF6C00)),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isVerified ? 'Terverifikasi' : 'Pending',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isHighContrast
                                                ? (isVerified
                                                    ? const Color(0xFFA7F3D0)
                                                    : const Color(0xFFFDE68A))
                                                : (isVerified
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFFEF6C00)),
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
                                  color: textSecondary,
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
                              color: isHighContrast
                                  ? (_isReady
                                      ? const Color(0xFF064E3B)
                                      : const Color(0xFF1E2430))
                                  : (_isReady
                                      ? const Color(0xFFE8F5E9)
                                      : Colors.grey.shade200),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isReady
                                  ? CupertinoIcons.radiowaves_right
                                  : CupertinoIcons.slash_circle,
                              color: isHighContrast
                                  ? (_isReady
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFF9CA3AF))
                                  : (_isReady
                                      ? primaryTeal
                                      : Colors.grey.shade600),
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
                                    color: isHighContrast
                                        ? (_isReady
                                            ? const Color(0xFF80CBC4)
                                            : textSecondary)
                                        : (_isReady
                                            ? primaryTeal
                                            : Colors.grey.shade800),
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
                                    color: textSecondary,
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
                            activeTrackColor: isHighContrast
                                ? const Color(0xFF00897B)
                                : primaryTeal,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: isHighContrast
                                ? const Color(0xFF374151)
                                : (isVerified
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade300),
                            trackOutlineColor: WidgetStateProperty.all(
                              isHighContrast
                                  ? const Color(0xFF4B5563)
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Status Tugas Berjalan / Hero Banner
                    if (_activeTask != null) ...[
                      Text(
                        'Tugas Darurat Aktif',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isHighContrast
                              ? const Color(0xFFFCA5A5)
                              : sosRed,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GlassContainer(
                        padding: const EdgeInsets.all(16),
                        color: isHighContrast
                            ? const Color(0xFF450A0A)
                            : sosRed.withValues(alpha: 0.85),
                        border: Border.all(
                          color: isHighContrast
                              ? const Color(0xFFEF4444)
                              : Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
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
                                        _activeTask!['pengguna']
                                            ?['nama_lengkap'] ??
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
                                    icon: Icon(
                                      CupertinoIcons.map,
                                      size: 16,
                                      color: isHighContrast
                                          ? Colors.white
                                          : sosRed,
                                    ),
                                    label: Text(
                                      'Buka Rute & Detail',
                                      style: TextStyle(
                                        color: isHighContrast
                                            ? Colors.white
                                            : sosRed,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isHighContrast
                                          ? const Color(0xFFEF4444)
                                          : Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        side: isHighContrast
                                            ? const BorderSide(
                                                color: Color(0xFFFCA5A5),
                                                width: 1.5,
                                              )
                                            : BorderSide.none,
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
                                color: isHighContrast
                                    ? const Color(0xFF1E2430)
                                    : const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(16),
                                border: isHighContrast
                                    ? Border.all(
                                        color: const Color(0xFF4B5563))
                                    : null,
                              ),
                              child: Icon(
                                CupertinoIcons.shield_lefthalf_fill,
                                color: tealColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tidak Ada Tugas Berjalan',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Area aman. Notifikasi darurat akan langsung muncul saat warga membutuhkan pertolongan.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
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
                    Text(
                      'Aksi Cepat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
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
                          isHighContrast: isHighContrast,
                          textPrimary: textPrimary,
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
                          isHighContrast: isHighContrast,
                          textPrimary: textPrimary,
                        ),
                        const SizedBox(width: 10),
                        _buildQuickAction(
                          icon: CupertinoIcons.phone_fill,
                          label: 'Panggil 112',
                          color: sosRed,
                          onTap: _callEmergency,
                          isHighContrast: isHighContrast,
                          textPrimary: textPrimary,
                        ),
                        const SizedBox(width: 10),
                        _buildQuickAction(
                          icon: CupertinoIcons.book_fill,
                          label: 'Panduan SOP',
                          color: const Color(0xFFF57C00),
                          onTap: _showPanduanModal,
                          isHighContrast: isHighContrast,
                          textPrimary: textPrimary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 5. Statistik Sistem & Kontribusi
                    Text(
                      'Statistik & Situasi Terkini',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
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
                            isHighContrast: isHighContrast,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
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
                            isHighContrast: isHighContrast,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
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
                            isHighContrast: isHighContrast,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
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
                              Text(
                                'Peta Wilayah & Sebaran',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  import_event_bus.GlobalEventBus
                                      .changeVolunteerTab.value = 2;
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      'Buka Peta ',
                                      style: TextStyle(
                                        color: tealColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Icon(
                                      CupertinoIcons.arrow_right,
                                      color: tealColor,
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
                                color: isHighContrast
                                    ? const Color(0xFF1E2430)
                                    : Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isHighContrast
                                      ? const Color(0xFF4B5563)
                                      : Colors.white,
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
                                      color: tealColor,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Ketuk untuk melihat radar sebaran laporan & SOS',
                                      style: TextStyle(
                                        color: isHighContrast
                                            ? const Color(0xFF80CBC4)
                                            : Colors.teal.shade900,
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
                        Text(
                          'Riwayat Tugas Penanganan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          '$completedTaskCount tugas',
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
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
                                color: textSecondary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Belum ada riwayat penanganan tugas',
                                style: TextStyle(
                                  color: textSecondary,
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
                            final DateTime parsedDate =
                                DateTime.parse(parseableDate).toLocal();
                            final String year =
                                parsedDate.year.toString().padLeft(4, '0');
                            final String month =
                                parsedDate.month.toString().padLeft(2, '0');
                            final String day =
                                parsedDate.day.toString().padLeft(2, '0');
                            final String hour =
                                parsedDate.hour.toString().padLeft(2, '0');
                            final String minute =
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
                            color: isHighContrast
                                ? const Color(0xFF121212)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: isHighContrast
                                ? Border.all(
                                    color: const Color(0xFF4B5563),
                                    width: 1.5,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isHighContrast ? 0.35 : 0.04,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isHighContrast
                                    ? (isSos
                                        ? const Color(0xFF450A0A)
                                        : const Color(0xFF1E3A8A))
                                    : (isSos
                                        ? Colors.red.shade100
                                        : Colors.blue.shade100),
                                child: Icon(
                                  isSos
                                      ? CupertinoIcons
                                          .exclamationmark_triangle_fill
                                      : CupertinoIcons.doc_text_fill,
                                  color: isHighContrast
                                      ? (isSos
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFF93C5FD))
                                      : (isSos
                                          ? Colors.red.shade700
                                          : Colors.blue.shade700),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: textPrimary,
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
                                            color: isHighContrast
                                                ? const Color(0xFF064E3B)
                                                : const Color(0xFFE8F5E9),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: isHighContrast
                                                ? Border.all(
                                                    color: const Color(
                                                        0xFF10B981))
                                                : null,
                                          ),
                                          child: Text(
                                            'Selesai',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isHighContrast
                                                  ? const Color(0xFFA7F3D0)
                                                  : const Color(0xFF2E7D32),
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
                                        color: textSecondary,
                                      ),
                                    ),
                                    if (displayDate.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        displayDate,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isHighContrast
                                              ? const Color(0xFF9CA3AF)
                                              : Colors.grey.shade500,
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
                          icon: Icon(
                            CupertinoIcons.chevron_down,
                            size: 14,
                            color: tealColor,
                          ),
                          label: Text(
                            'Muat Lebih Banyak',
                            style: TextStyle(
                              color: tealColor,
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
      },
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isHighContrast,
    required Color textPrimary,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isHighContrast ? const Color(0xFF121212) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isHighContrast
                ? Border.all(color: const Color(0xFF4B5563))
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isHighContrast ? 0.35 : 0.04,
                ),
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
                  color: isHighContrast
                      ? color.withValues(alpha: 0.25)
                      : color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isHighContrast
                      ? (color == primaryTeal
                          ? const Color(0xFF80CBC4)
                          : (color == sosRed
                              ? const Color(0xFFFCA5A5)
                              : color))
                      : color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
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
    required bool isHighContrast,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: isHighContrast ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isHighContrast
            ? Border.all(color: const Color(0xFF4B5563))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isHighContrast ? 0.35 : 0.04,
            ),
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
            backgroundColor:
                isHighContrast ? const Color(0xFF1E2430) : bgIconColor,
            child: Icon(
              icon,
              color: isHighContrast
                  ? (iconColor == primaryTeal
                      ? const Color(0xFF80CBC4)
                      : (iconColor == sosRed
                          ? const Color(0xFFFCA5A5)
                          : iconColor))
                  : iconColor,
              size: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: textSecondary,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  color: textSecondary,
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
