import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/services/websocket_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart'
    as import_event_bus;
import 'package:sahabat_sos_mobile/core/widgets/app_loading_indicator.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/widgets/volunteer_active_task_card.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/widgets/volunteer_duty_card.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/widgets/volunteer_quick_actions.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/widgets/volunteer_sop_modal.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/widgets/volunteer_stats_section.dart';
import 'package:sahabat_sos_mobile/features/volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';

class VolunteerDashboardPage extends StatefulWidget {
  const VolunteerDashboardPage({super.key});

  @override
  State<VolunteerDashboardPage> createState() => _VolunteerDashboardPageState();
}

class _VolunteerDashboardPageState extends State<VolunteerDashboardPage> {
  bool _isReady = false;
  int? _volunteerId;
  final _volunteerDataSource = sl<VolunteerRemoteDataSource>();

  Map<String, dynamic>? _berandaData;
  Map<String, dynamic>? _activeTask;
  String _activeTaskLokasi = '';
  List<dynamic> _riwayatList = [];
  bool _isLoading = true;
  int _visibleRiwayatCount = 5;

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

      if (isVerifiedAndActive) {
        try {
          final berandaRes = await _volunteerDataSource.getBeranda();
          _berandaData = berandaRes;
        } catch (e) {
          debugPrint("Gagal load beranda data: $e");
        }

        try {
          final tasks = await _volunteerDataSource.getRelawanTasks();
          if (tasks['data'] != null) {
            _activeTask = tasks['data'];
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

  /// Konversi koordinat lat/long menjadi nama wilayah atau gunakan fallback alamat tersimpan.
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
    // Relawan yang belum terverifikasi dicegah mengaktifkan radar tugas demi keamanan korban
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

    if (_volunteerId != null) {
      if (val) {
        debugPrint("Mengaktifkan langganan SOS WebSocket relawan ID: $_volunteerId");
        WebsocketService.listenToNewSosForVolunteer(
          _volunteerId!,
          _onNewSosReceived,
        );
      } else {
        debugPrint("Menghentikan langganan SOS WebSocket relawan ID: $_volunteerId");
        WebsocketService.stopListeningNewSosForVolunteer(_volunteerId!);
      }
    }

    try {
      final statusStr = val ? 'tersedia' : 'tidak_tersedia';
      await _volunteerDataSource.updateStatusKetersediaan(statusStr);
    } catch (e) {
      if (!mounted) return;

      // Rollback status lokal dan koneksi socket jika backend menolak pembaruan
      setState(() {
        _isReady = !val;
      });

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
    showVolunteerSopModal(context);
  }

  void _navigateToActiveTask() {
    context.push(
      AppRoutes.volunteerActiveTask,
      extra: _activeTask,
    ).then((_) => _initVolunteerData());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast = context.isHighContrast;
        final currentBg = AccessibleColors.scaffoldBackground(isHighContrast);
        final primaryTeal = AccessibleColors.primaryTeal(isHighContrast);
        final textPrimary = AccessibleColors.textPrimary(isHighContrast);
        final textSecondary = AccessibleColors.textSecondary(isHighContrast);

        if (_isLoading) {
          return Scaffold(
            backgroundColor: currentBg,
            body: AppLoadingIndicator(
              radius: 16,
              color: primaryTeal,
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
              color: primaryTeal,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Halo, $_userName',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
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
                                            fontSize: 11,
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
                              const SizedBox(height: 3),
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

                    VolunteerDutyCard(
                      isReady: _isReady,
                      isVerified: isVerified,
                      verificationStatus: _verificationStatus,
                      onToggleStatus: _toggleReadyStatus,
                    ),
                    const SizedBox(height: 20),

                    VolunteerActiveTaskCard(
                      activeTask: _activeTask,
                      activeTaskLokasi: _activeTaskLokasi,
                      onOpenTaskDetail: _navigateToActiveTask,
                    ),
                    const SizedBox(height: 20),

                    VolunteerQuickActions(
                      onOpenMap: () {
                        import_event_bus.GlobalEventBus.changeVolunteerTab
                            .value = 2;
                      },
                      onOpenTaskList: () {
                        import_event_bus.GlobalEventBus.changeVolunteerTab
                            .value = 1;
                      },
                      onCall112: _callEmergency,
                      onOpenSop: _showPanduanModal,
                    ),
                    const SizedBox(height: 24),

                    VolunteerStatsSection(
                      activeSosCount: activeSosCount,
                      totalLaporan: totalLaporan,
                      completedTaskCount: completedTaskCount,
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AccessibleColors.cardBackground(isHighContrast),
                        borderRadius: BorderRadius.circular(16),
                        border: AccessibleColors.cardBorder(isHighContrast),
                        boxShadow: isHighContrast
                            ? const []
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
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
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    import_event_bus.GlobalEventBus
                                        .changeVolunteerTab.value = 2;
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    constraints: const BoxConstraints(minHeight: 48),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Row(
                                      children: [
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
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                import_event_bus.GlobalEventBus.changeVolunteerTab
                                    .value = 2;
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 110,
                                decoration: BoxDecoration(
                                  color: isHighContrast
                                      ? const Color(0xFF1E2430)
                                      : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isHighContrast
                                        ? const Color(0xFF4B5563)
                                        : const Color(0xFFBBF7D0),
                                    width: 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.map_pin_ellipse,
                                        size: 32,
                                        color: primaryTeal,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Ketuk untuk melihat radar sebaran laporan & SOS',
                                        style: TextStyle(
                                          color: isHighContrast
                                              ? const Color(0xFF80CBC4)
                                              : primaryTeal,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

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
                            color: AccessibleColors.cardBackground(isHighContrast),
                            borderRadius: BorderRadius.circular(14),
                            border: AccessibleColors.cardBorder(isHighContrast),
                            boxShadow: isHighContrast
                                ? const []
                                : [
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
                                          fontSize: 11,
                                          color: textSecondary,
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
                          style: TextButton.styleFrom(
                            minimumSize: const Size(140, 48),
                          ),
                          onPressed: () {
                            setState(() {
                              _visibleRiwayatCount += 5;
                            });
                          },
                          icon: Icon(
                            CupertinoIcons.chevron_down,
                            size: 14,
                            color: primaryTeal,
                          ),
                          label: Text(
                            'Muat Lebih Banyak',
                            style: TextStyle(
                              color: primaryTeal,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 100,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
