import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/accessibility_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/global_event_bus.dart' as event_bus;
import '../../../../routing/routes.dart';
import '../../data/datasources/profile_remote_data_source.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryTeal = Color(0xFF00695C);

  bool _isLoading = true;
  bool _isUpdatingLocation = false;
  Map<String, dynamic>? _fullUserData;

  String _name = 'Memuat...';
  String _email = '-';
  String _category = 'Umum';
  String _phone = '-';
  String _location = '-';
  String _address = '-';
  String? _avatarUrl;
  bool _avatarError = false;

  Dio get _dio => GetIt.instance<Dio>();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final prefs = GetIt.instance<SharedPreferences>();
    if (prefs.getString('user_role') == 'relawan') {
      if (mounted) {
        context.go(AppRoutes.homeVolunteer);
      }
      return;
    }

    try {
      final profileDataSource = GetIt.instance<ProfileRemoteDataSource>();
      final response = await profileDataSource.getProfile();

      final userData = response['data'] ?? response['user'];
      if (userData != null) {
        if (userData['role'] != null &&
            userData['role'].toString().toLowerCase() == 'relawan') {
          await prefs.setString('user_role', 'relawan');
          if (mounted) {
            context.go(AppRoutes.homeVolunteer);
          }
          return;
        }

        // Sinkronkan preferensi aksesibilitas dari backend ke singleton global
        AccessibilityService.instance.syncFromBackend(userData);

        if (mounted) {
          setState(() {
            _fullUserData = userData;
            _name = userData['name'] ?? 'Pengguna';
            _email = userData['email'] ?? '-';
            _phone = userData['no_telp'] ?? 'Belum diatur';
            _location = userData['lokasi_user'] ?? 'Lokasi belum tersedia';
            _address = userData['alamat'] ?? 'Alamat belum diatur';

            final rawCat = (userData['kategori_user'] as String?) ?? 'umum';
            final cat = rawCat.isEmpty ? 'umum' : rawCat;
            _category = cat.substring(0, 1).toUpperCase() + cat.substring(1);

            _avatarError = false;
            final rawFoto = userData['foto_profile_url'] ?? userData['foto_profile'];
            if (rawFoto != null && rawFoto.toString().isNotEmpty) {
              final String foto = rawFoto.toString();
              if (foto.startsWith('http://') || foto.startsWith('https://')) {
                _avatarUrl = foto;
              } else {
                String cleanPath =
                    foto.startsWith('/') ? foto.substring(1) : foto;
                if (cleanPath.startsWith('public/')) {
                  cleanPath = cleanPath.substring(7);
                }
                _avatarUrl = '${ApiConstants.storageUrl}/$cleanPath';
              }
            } else {
              _avatarUrl = null;
            }

            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      try {
        final token = prefs.getString('auth_token');
        if (token != null) {
          final dio = GetIt.instance<Dio>();
          final meRes = await dio.get(
            ApiConstants.me,
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            ),
          );
          if (meRes.statusCode == 200) {
            final uData = meRes.data['user'];
            if (uData != null && uData['role'] != null) {
              final role = uData['role'].toString().toLowerCase();
              await prefs.setString('user_role', role);
              if (role == 'relawan') {
                if (uData['id'] != null) {
                  await prefs.setInt(
                    'volunteer_id',
                    (uData['id'] is int)
                        ? uData['id']
                        : int.tryParse(uData['id'].toString()) ?? 0,
                  );
                }
                final verificationStatus =
                    (uData['status_verifikasi'] ?? 'pending')
                        .toString()
                        .toLowerCase();
                await prefs.setString(
                  'verification_status',
                  verificationStatus,
                );
                event_bus.GlobalEventBus.volunteerVerificationStatus.value =
                    (verificationStatus == 'terverifikasi');
                final isActive = (uData['is_active'] == true ||
                    uData['is_active'] == 1 ||
                    uData['is_active'] == '1');
                await prefs.setBool('user_is_active', isActive);
                event_bus.GlobalEventBus.volunteerActiveStatus.value = isActive;
                if (mounted) {
                  context.go(AppRoutes.homeVolunteer);
                  return;
                }
              }
            }
          }
        }
      } catch (meError) {
        debugPrint("Error resolving user/me in ProfileScreen: $meError");
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshGpsLocation() async {
    if (_isUpdatingLocation) return;
    setState(() => _isUpdatingLocation = true);

    try {
      final locationService = GetIt.instance<LocationService>();
      final hasPermission = await locationService.requestPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Izin akses GPS diperlukan untuk memperbarui lokasi.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));

      String detectedAddress =
          'Lat ${pos.latitude.toStringAsFixed(4)}, Long ${pos.longitude.toStringAsFixed(4)}';

      try {
        final placemarks = await geo.Geocoding().placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
          ].where((s) => s != null && s.trim().isNotEmpty).toList();
          if (parts.isNotEmpty) {
            detectedAddress = parts.join(', ');
          }
        }
      } catch (_) {}

      // Update ke backend
      final prefs = GetIt.instance<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token != null) {
        await _dio.post(
          ApiConstants.updateLocation,
          data: {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'lokasi_user': detectedAddress,
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          ),
        );
      }

      if (mounted) {
        setState(() {
          _location = detectedAddress;
        });
        AccessibilityService.instance.hapticLight();
        unawaited(AccessibilityService.instance
            .speak("Lokasi GPS berhasil diperbarui"));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi GPS berhasil diperbarui ke server.'),
            backgroundColor: primaryTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui lokasi GPS: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingLocation = false);
      }
    }
  }

  Future<void> _callPhone(String number) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        AccessibilityService.instance.hapticMedium();
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat melakukan panggilan ke $number'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      debugPrint('Gagal call: $e');
    }
  }

  void _showHelpCenterModal(BuildContext context, bool isHighContrast) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bg = isHighContrast ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor =
            isHighContrast ? Colors.white : const Color(0xFF111827);
        final subTextColor =
            isHighContrast ? Colors.grey.shade300 : const Color(0xFF4B5563);

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: isHighContrast
                ? Border.all(color: const Color(0xFF4B5563))
                : null,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.question_circle_fill,
                      color:
                          isHighContrast ? const Color(0xFF14B8A6) : primaryTeal,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pusat Bantuan & Panduan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: isHighContrast
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildHelpSection(
                      icon: CupertinoIcons.exclamationmark_triangle_fill,
                      iconColor: const Color(0xFFDC2626),
                      title: '1. Memicu Sinyal Darurat (SOS)',
                      content:
                          '• Ketukan 5 Kali Cepat: Tekan tombol merah SOS di Beranda 5 kali dalam waktu 2 detik untuk menghindari ketidaksengajaan.\n'
                          '• Tombol Fisik Tuya / Smartwatch: Tekan tombol darurat bluetooth yang terhubung ke aplikasi.\n'
                          '• Pembatalan SOS: Geser tombol "Geser untuk Batalkan" hingga penuh sebelum hitungan mundur 10 detik berakhir.',
                      isHighContrast: isHighContrast,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 16),
                    _buildHelpSection(
                      icon: CupertinoIcons.exclamationmark_bubble_fill,
                      iconColor: const Color(0xFF0284C7),
                      title: '2. Laporan Cepat (Quick Report)',
                      content:
                          'Gunakan formulir Laporan Cepat untuk melaporkan kejadian darurat di sekitar Anda (Medis, Kebakaran, Kriminal, dsb). '
                          'Sertakan foto bukti insiden dan deskripsi singkat. Lokasi GPS akan disematkan secara otomatis.',
                      isHighContrast: isHighContrast,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 16),
                    _buildHelpSection(
                      icon: CupertinoIcons.hand_raised_fill,
                      iconColor: const Color(0xFFD97706),
                      title: '3. Adaptasi Kebutuhan Disabilitas',
                      content:
                          'Aplikasi Sahabat SOS secara adaptif menyesuaikan fungsinya:\n'
                          '• Tunanetra: Panduan Suara TalkBack, Teks Besar, Kontras Tinggi, dan Umpan Balik Getaran aktif penuh.\n'
                          '• Tunarungu: Getaran taktil maksimal dan peringatan visual flash aktif (suara dinonaktifkan).\n'
                          '• Tunawicara: Respon getaran dan komunikasi darurat berbasis teks.',
                      isHighContrast: isHighContrast,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 16),
                    _buildHelpSection(
                      icon: CupertinoIcons.shield_fill,
                      iconColor: primaryTeal,
                      title: '4. Privasi & Keamanan Data',
                      content:
                          'Lokasi Anda hanya dikirim ke sistem ketika tombol SOS ditekan atau formulir laporan cepat dikirimkan. '
                          'Alamat tempat tinggal tetap disimpan aman dan hanya digunakan oleh relawan berwenang untuk penyelamatan.',
                      isHighContrast: isHighContrast,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelpSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required bool isHighContrast,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighContrast ? const Color(0xFF262626) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF404040)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: subTextColor,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  void _showContactSupportModal(BuildContext context, bool isHighContrast) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bg = isHighContrast ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor =
            isHighContrast ? Colors.white : const Color(0xFF111827);

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: isHighContrast
                ? Border.all(color: const Color(0xFF4B5563))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hubungi Bantuan Darurat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih nomor layanan darurat atau operator Sahabat SOS yang siap siaga 24/7:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isHighContrast
                      ? Colors.grey.shade400
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 20),
              _buildCallTile(
                title: 'Layanan Darurat Nasional (Bebas Pulsa)',
                number: '112',
                subtitle: 'Polisi, Pemadam Kebakaran & Ambulans Terpadu',
                icon: CupertinoIcons.phone_fill,
                color: const Color(0xFFDC2626),
                isHighContrast: isHighContrast,
                onTap: () {
                  Navigator.pop(ctx);
                  _callPhone('112');
                },
              ),
              const SizedBox(height: 10),
              _buildCallTile(
                title: 'Call Center Kepolisian RI',
                number: '110',
                subtitle: 'Pelaporan tindak kriminal & gangguan keamanan',
                icon: CupertinoIcons.shield_fill,
                color: const Color(0xFF1D4ED8),
                isHighContrast: isHighContrast,
                onTap: () {
                  Navigator.pop(ctx);
                  _callPhone('110');
                },
              ),
              const SizedBox(height: 10),
              _buildCallTile(
                title: 'Layanan Ambulans Medis Darurat',
                number: '119',
                subtitle: 'Pertolongan pertama gawat darurat medis',
                icon: CupertinoIcons.heart_fill,
                color: const Color(0xFF059669),
                isHighContrast: isHighContrast,
                onTap: () {
                  Navigator.pop(ctx);
                  _callPhone('119');
                },
              ),
              const SizedBox(height: 10),
              _buildCallTile(
                title: 'Hotline Operator Sahabat SOS',
                number: '1500000',
                subtitle: 'Bantuan teknis aplikasi & penanganan relawan',
                icon: CupertinoIcons.headphones,
                color: primaryTeal,
                isHighContrast: isHighContrast,
                onTap: () {
                  Navigator.pop(ctx);
                  _callPhone('1500000');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCallTile({
    required String title,
    required String number,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isHighContrast,
    required VoidCallback onTap,
  }) {
    final elementId = 'call_tile_$number';
    final isFocused = AccessibilityService.instance.isElementFocused(elementId);
    return InkWell(
      onTap: () {
        AccessibilityService.instance.handleTalkbackTap(
          id: elementId,
          speakText: "$title, nomor $number. $subtitle",
          hintText: "Tekan sekali lagi untuk menelepon nomor $number.",
          onAction: onTap,
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isHighContrast ? const Color(0xFF262626) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFocused
                ? (isHighContrast ? const Color(0xFF00FFCC) : const Color(0xFF00897B))
                : (isHighContrast
                    ? const Color(0xFF404040)
                    : const Color(0xFFE5E7EB)),
            width: isFocused ? 2.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isHighContrast
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isHighContrast
                          ? Colors.grey.shade400
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'tunanetra':
        return CupertinoIcons.eye_slash;
      case 'tunarungu':
        return CupertinoIcons.ear;
      case 'tunawicara':
        return CupertinoIcons.mic_slash;
      case 'umum':
      default:
        return CupertinoIcons.person;
    }
  }

  String _getCategoryAdaptiveDescription(String category) {
    switch (category.toLowerCase()) {
      case 'tunanetra':
        return 'Adaptasi: Panduan Suara, Teks Besar, Kontras Tinggi & Getaran Aktif';
      case 'tunarungu':
        return 'Adaptasi: Getaran Taktil Kuat & Kontras Visual Aktif';
      case 'tunawicara':
        return 'Adaptasi: Teks Cepat Non-Verbal & Respon Getaran Aktif';
      case 'umum':
      default:
        return 'Mode Aksesibilitas Standar';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled;
        final bgColor = isHighContrast ? Colors.black : const Color(0xFFF8FAFC);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: _buildAppBar(isHighContrast),
          body: _isLoading
              ? const Center(child: CupertinoActivityIndicator(radius: 16))
              : SafeArea(
                  child: RefreshIndicator(
                    onRefresh: _fetchProfile,
                    color: primaryTeal,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 110,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileHeader(isHighContrast),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSectionHeader(
                                  icon: CupertinoIcons.hand_raised,
                                  title: 'Aksesibilitas',
                                  isHighContrast: isHighContrast,
                                ),
                                const SizedBox(height: 12),
                                _buildSettingsCard(isHighContrast),
                                const SizedBox(height: 24),
                                _buildSectionHeader(
                                  icon: CupertinoIcons.shield,
                                  title: 'Privasi & Lokasi',
                                  isHighContrast: isHighContrast,
                                ),
                                const SizedBox(height: 12),
                                _buildPrivacyCard(isHighContrast),
                                const SizedBox(height: 24),
                                _buildSectionHeader(
                                  icon: CupertinoIcons.bluetooth,
                                  title: 'Perangkat Pintar',
                                  isHighContrast: isHighContrast,
                                ),
                                const SizedBox(height: 12),
                                _buildCard(
                                  isHighContrast: isHighContrast,
                                  child: _buildHelpTile(
                                    icon: CupertinoIcons
                                        .antenna_radiowaves_left_right,
                                    iconColor: isHighContrast
                                        ? const Color(0xFF14B8A6)
                                        : primaryTeal,
                                    iconBg: isHighContrast
                                        ? const Color(0xFF374151)
                                        : primaryTeal.withValues(alpha: 0.1),
                                    title: 'Kelola Tombol SOS (Tuya)',
                                    subtitle:
                                        'Hubungkan dan atur tombol fisik bluetooth',
                                    isHighContrast: isHighContrast,
                                    onTap: () =>
                                        context.push(AppRoutes.tuyaDevices),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildSectionHeader(
                                  icon: CupertinoIcons.clock,
                                  title: 'Riwayat Aktivitas',
                                  isHighContrast: isHighContrast,
                                ),
                                const SizedBox(height: 12),
                                _buildCard(
                                  isHighContrast: isHighContrast,
                                  child: _buildHelpTile(
                                    icon: CupertinoIcons.clock_fill,
                                    iconColor: isHighContrast
                                        ? const Color(0xFF14B8A6)
                                        : primaryTeal,
                                    iconBg: isHighContrast
                                        ? const Color(0xFF374151)
                                        : primaryTeal.withValues(alpha: 0.1),
                                    title: 'Semua Riwayat SOS & Laporan',
                                    subtitle:
                                        'Buka arsip riwayat panggilan dan laporan pada tab utama',
                                    isHighContrast: isHighContrast,
                                    onTap: () {
                                      // Alihkan secara konsisten ke Tab Riwayat (Index 3) di MainScreen
                                      event_bus.GlobalEventBus
                                          .changeUserTab.value = 3;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildSectionHeader(
                                  icon: CupertinoIcons.question_circle,
                                  title: 'Bantuan',
                                  isHighContrast: isHighContrast,
                                ),
                                const SizedBox(height: 12),
                                _buildHelpCard(isHighContrast),
                                const SizedBox(height: 32),
                                _buildLogoutButton(isHighContrast),
                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    'Sahabat SOS v1.0.0',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isHighContrast
                                          ? Colors.grey.shade500
                                          : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

  PreferredSizeWidget _buildAppBar(bool isHighContrast) {
    return AppBar(
      backgroundColor: isHighContrast ? Colors.black : const Color(0xFFF8FAFC),
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(
        color: isHighContrast ? const Color(0xFF14B8A6) : primaryTeal,
      ),
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 24, height: 24),
          const SizedBox(width: 8),
          Text(
            'Sahabat SOS',
            style: TextStyle(
              color: isHighContrast ? const Color(0xFF14B8A6) : primaryTeal,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () async {
            if (_fullUserData != null) {
              final result = await context.push<bool>(
                AppRoutes.editProfile,
                extra: _fullUserData,
              );
              if (result == true) {
                await _fetchProfile();
              }
            }
          },
          icon: Icon(
            CupertinoIcons.pencil,
            color: isHighContrast ? const Color(0xFF14B8A6) : primaryTeal,
            size: 24,
          ),
          tooltip: 'Edit Profil',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCard({
    required Widget child,
    BorderRadius? borderRadius,
    bool isHighContrast = false,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        color: isHighContrast ? const Color(0xFF121212) : Colors.white,
        borderRadius: radius,
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF4B5563)
              : const Color(0xFFE5E7EB),
          width: isHighContrast ? 1.5 : 1.0,
        ),
        boxShadow: isHighContrast
            ? null
            : const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _buildProfileHeader(bool isHighContrast) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 20,
        bottom: 28,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: isHighContrast ? const Color(0xFF121212) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF4B5563)
              : const Color(0xFFE5E7EB),
          width: isHighContrast ? 1.5 : 1.0,
        ),
        boxShadow: isHighContrast
            ? null
            : const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isHighContrast
                    ? Colors.white
                    : primaryTeal.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: isHighContrast
                  ? Colors.grey.shade800
                  : primaryTeal.withValues(alpha: 0.1),
              backgroundImage: (_avatarUrl != null &&
                      _avatarUrl!.isNotEmpty &&
                      !_avatarError)
                  ? NetworkImage(_avatarUrl!)
                  : null,
              onBackgroundImageError: (_avatarUrl != null &&
                      _avatarUrl!.isNotEmpty)
                  ? (_, _) {
                      if (mounted && !_avatarError) {
                        setState(() => _avatarError = true);
                      }
                    }
                  : null,
              child: (_avatarUrl == null ||
                      _avatarUrl!.isEmpty ||
                      _avatarError)
                  ? Icon(
                      CupertinoIcons.person_fill,
                      size: 44,
                      color: isHighContrast
                          ? const Color(0xFF14B8A6)
                          : primaryTeal,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color:
                        isHighContrast ? Colors.white : const Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.checkmark_seal_fill,
                color: primaryTeal,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _email,
            style: TextStyle(
              fontSize: 13,
              color: isHighContrast
                  ? Colors.grey.shade300
                  : const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Badge Kategori Disabilitas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isHighContrast
                  ? const Color(0xFF374151)
                  : const Color(0xFFFFE0B2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getCategoryIcon(_category),
                  color: isHighContrast
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFFEF6C00),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _category,
                  style: TextStyle(
                    fontSize: 13,
                    color: isHighContrast
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFEF6C00),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Keterangan Adaptasi Aksesibilitas Aktif
          Text(
            _getCategoryAdaptiveDescription(_category),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isHighContrast
                  ? const Color(0xFF14B8A6)
                  : const Color(0xFF00695C),
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoBox(
            icon: CupertinoIcons.phone,
            label: 'Telepon Darurat',
            value: _phone,
            caption: 'Kontak utama penanganan darurat',
            isHighContrast: isHighContrast,
          ),
          const SizedBox(height: 10),
          // Lokasi Terkini (Sensor GPS) dengan Tombol Refresh
          _buildInfoBox(
            icon: CupertinoIcons.location_solid,
            label: 'Lokasi Terkini (Sensor GPS)',
            value: _location,
            caption: 'Dideteksi otomatis saat bepergian & darurat',
            isHighContrast: isHighContrast,
            trailing: _isUpdatingLocation
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CupertinoActivityIndicator(radius: 10),
                  )
                : IconButton(
                    icon: Icon(
                      CupertinoIcons.arrow_clockwise_circle_fill,
                      color: isHighContrast
                          ? const Color(0xFF14B8A6)
                          : primaryTeal,
                      size: 24,
                    ),
                    tooltip: 'Perbarui Lokasi GPS',
                    onPressed: _refreshGpsLocation,
                  ),
          ),
          const SizedBox(height: 10),
          // Alamat Domisili Tetap
          _buildInfoBox(
            icon: CupertinoIcons.house,
            label: 'Alamat Tempat Tinggal (Domisili Tetap)',
            value: _address,
            caption: 'Alamat rujukan penyelamat saat panggilan darurat',
            isHighContrast: isHighContrast,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String label,
    required String value,
    String? caption,
    Widget? trailing,
    bool isHighContrast = false,
  }) {
    return Semantics(
      label: "$label: $value",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isHighContrast
              ? const Color(0xFF1E1E1E)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighContrast
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isHighContrast ? const Color(0xFF14B8A6) : primaryTeal,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isHighContrast
                          ? Colors.grey.shade400
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isHighContrast
                          ? Colors.white
                          : const Color(0xFF111827),
                    ),
                  ),
                  if (caption != null && caption.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isHighContrast
                            ? Colors.grey.shade500
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    bool isHighContrast = false,
  }) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(
            icon,
            color: isHighContrast ? const Color(0xFF14B8A6) : primaryTeal,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isHighContrast ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(bool isHighContrast) {
    final service = AccessibilityService.instance;
    return _buildCard(
      isHighContrast: isHighContrast,
      child: Column(
        children: [
          _buildToggleItem(
            icon: CupertinoIcons.speaker_2,
            title: 'TalkBack / Pembaca Layar',
            subtitle: 'Tekan 1x bersuara, tekan lagi untuk melakukan aksi.',
            value: service.isTalkbackEnabled,
            isHighContrast: isHighContrast,
            onChanged: (v) async {
              await service.setTalkback(v);
            },
          ),
          Divider(
            height: 1,
            indent: 56,
            color: isHighContrast
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
          ),
          _buildToggleItem(
            icon: CupertinoIcons.volume_up,
            title: 'Panduan Suara Otomatis (TTS)',
            subtitle: 'Narasi suara otomatis saat membuka layar dan tindakan.',
            value: service.isVoiceGuideEnabled,
            isHighContrast: isHighContrast,
            onChanged: (v) async {
              await service.setVoiceGuide(v);
            },
          ),
          Divider(
            height: 1,
            indent: 56,
            color: isHighContrast
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
          ),
          _buildToggleItem(
            icon: CupertinoIcons.waveform_path,
            title: 'Umpan Balik Getaran (Haptic)',
            subtitle: 'Getaran taktil tombol SOS dan geser batal.',
            value: service.isHapticEnabled,
            isHighContrast: isHighContrast,
            onChanged: (v) async {
              await service.setHaptic(v);
            },
          ),
          Divider(
            height: 1,
            indent: 56,
            color: isHighContrast
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
          ),
          _buildToggleItem(
            icon: CupertinoIcons.circle_lefthalf_fill,
            title: 'Kontras Tinggi (High Contrast)',
            subtitle: 'Tampilan tema kontras pekat di seluruh aplikasi.',
            value: service.isHighContrastEnabled,
            isHighContrast: isHighContrast,
            onChanged: (v) async {
              await service.setHighContrast(v);
            },
          ),
          Divider(
            height: 1,
            indent: 56,
            color: isHighContrast
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
          ),
          _buildToggleItem(
            icon: CupertinoIcons.textformat,
            title: 'Teks Besar (Large Text)',
            subtitle: 'Perbesar ukuran teks di seluruh aplikasi.',
            value: service.isLargeTextEnabled,
            isHighContrast: isHighContrast,
            onChanged: (v) async {
              await service.setLargeText(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isHighContrast = false,
  }) {
    final elementId = 'toggle_$title';
    final isFocused = AccessibilityService.instance.isElementFocused(elementId);
    return InkWell(
      onTap: () {
        AccessibilityService.instance.handleTalkbackTap(
          id: elementId,
          speakText: "$title, status: ${value ? 'Aktif' : 'Nonaktif'}",
          hintText: "Tekan sekali lagi untuk ${value ? 'menonaktifkan' : 'mengaktifkan'}.",
          onAction: () => onChanged(!value),
        );
      },
      child: Container(
        decoration: isFocused
            ? BoxDecoration(
                border: Border.all(
                  color: isHighContrast
                      ? const Color(0xFF00FFCC)
                      : const Color(0xFF00897B),
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isHighContrast
                    ? const Color(0xFF374151)
                    : primaryTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isHighContrast ? const Color(0xFF14B8A6) : primaryTeal,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color:
                          isHighContrast ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isHighContrast
                          ? Colors.grey.shade400
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: title,
              value: value ? 'Aktif' : 'Nonaktif',
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: primaryTeal,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: isHighContrast
                    ? Colors.grey.shade700
                    : Colors.grey.shade300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard(bool isHighContrast) {
    return _buildCard(
      isHighContrast: isHighContrast,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isHighContrast
                    ? const Color(0xFF374151)
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                CupertinoIcons.location_fill,
                color: isHighContrast
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFFEF6C00),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perlindungan Pelacakan',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isHighContrast
                          ? Colors.white
                          : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lokasi hanya dibagikan saat tombol SOS ditekan. Data dienkripsi secara penuh untuk keamanan Anda.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isHighContrast
                          ? Colors.grey.shade400
                          : const Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard(bool isHighContrast) {
    return _buildCard(
      isHighContrast: isHighContrast,
      child: Column(
        children: [
          _buildHelpTile(
            icon: CupertinoIcons.info,
            iconColor:
                isHighContrast ? Colors.lightBlueAccent : Colors.blue.shade700,
            iconBg: isHighContrast
                ? const Color(0xFF1E293B)
                : Colors.blue.shade50,
            title: 'Pusat Bantuan & Panduan',
            subtitle: 'FAQ, panduan gestur, tutorial penggunaan',
            isHighContrast: isHighContrast,
            onTap: () => _showHelpCenterModal(context, isHighContrast),
          ),
          Divider(
            height: 1,
            indent: 56,
            color: isHighContrast
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
          ),
          _buildHelpTile(
            icon: CupertinoIcons.headphones,
            iconColor:
                isHighContrast ? const Color(0xFFFBBF24) : Colors.orange.shade700,
            iconBg: isHighContrast
                ? const Color(0xFF374151)
                : Colors.orange.shade50,
            title: 'Hubungi Sahabat SOS',
            subtitle: 'Panggilan hotline & operator darurat 24/7',
            isHighContrast: isHighContrast,
            onTap: () => _showContactSupportModal(context, isHighContrast),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isHighContrast = false,
  }) {
    final elementId = 'help_tile_$title';
    final isFocused = AccessibilityService.instance.isElementFocused(elementId);
    return InkWell(
      onTap: onTap != null
          ? () {
              AccessibilityService.instance.handleTalkbackTap(
                id: elementId,
                speakText: "$title. $subtitle",
                hintText: "Tekan sekali lagi untuk membuka.",
                onAction: onTap,
              );
            }
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: isFocused
            ? BoxDecoration(
                border: Border.all(
                  color: isHighContrast
                      ? const Color(0xFF00FFCC)
                      : const Color(0xFF00897B),
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isHighContrast
                          ? Colors.white
                          : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isHighContrast
                          ? Colors.grey.shade400
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: isHighContrast
                  ? Colors.grey.shade400
                  : const Color(0xFF9CA3AF),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(bool isHighContrast) {
    final isFocused = AccessibilityService.instance.isElementFocused('profile_logout_btn');
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () {
          AccessibilityService.instance.handleTalkbackTap(
            id: 'profile_logout_btn',
            speakText: "Keluar Akun",
            hintText: "Tekan sekali lagi untuk membuka dialog konfirmasi keluar.",
            onAction: () async {
              final confirm = await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isHighContrast ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: isHighContrast
                    ? Border.all(color: const Color(0xFF4B5563))
                    : null,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isHighContrast
                            ? Colors.grey.shade700
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isHighContrast
                            ? const Color(0xFF3F1D1D)
                            : const Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.arrow_right_square,
                        color: Color(0xFFD32F2F),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keluar Akun',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isHighContrast
                            ? Colors.white
                            : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Apakah Anda yakin ingin keluar dari akun ini?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isHighContrast
                            ? Colors.grey.shade400
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  isHighContrast ? Colors.white : primaryTeal,
                              side: BorderSide(
                                color: isHighContrast
                                    ? Colors.grey.shade600
                                    : primaryTeal.withValues(alpha: 0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD32F2F),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Ya, Keluar',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
          if (confirm != true) return;
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          try {
            await _dio.post(
              ApiConstants.logout,
              options: Options(
                headers: {
                  'Authorization': 'Bearer $token',
                  'Accept': 'application/json',
                },
              ),
            );
          } catch (_) {}
          await prefs.remove('auth_token');
          await prefs.remove('is_profile_complete');
          if (!mounted) return;
          context.go(AppRoutes.login);
        },
      );
    },
    icon: const Icon(CupertinoIcons.arrow_right_square),
        label: const Text(
          'Keluar Akun',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isHighContrast ? const Color(0xFF3F1D1D) : const Color(0xFFFFEBEE),
          foregroundColor: const Color(0xFFEF4444),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isFocused
                ? BorderSide(
                    color: isHighContrast
                        ? const Color(0xFF00FFCC)
                        : const Color(0xFF00897B),
                    width: 2.5,
                  )
                : (isHighContrast
                    ? const BorderSide(color: Color(0xFFEF4444), width: 1.5)
                    : BorderSide.none),
          ),
        ),
      ),
    );
  }
}
