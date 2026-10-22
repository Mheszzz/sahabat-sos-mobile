import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../routing/routes.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/services/accessibility_service.dart';
import '../../../../core/theme/accessible_colors.dart';

import '../../../volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import '../../../../core/utils/global_event_bus.dart' as event_bus;

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  static const Color primaryTeal = Color(0xFF00695C);

  bool _isLoading = true;
  bool _isCheckingStatus = false;
  bool _isActive = true;
  Map<String, dynamic>? _fullUserData;

  String _name = 'Memuat...';
  String _email = '-';
  String _phone = '-';
  String _location = '-';
  String _address = '-';
  String _job = '-';
  String _reason = '-';
  String _verificationStatus = 'pending';
  String _avatarUrl = 'https://placehold.co/100x100.png';

  Dio get _dio => GetIt.instance<Dio>();

  @override
  void initState() {
    super.initState();
    final prefs = GetIt.instance<SharedPreferences>();
    _isActive = prefs.getBool('user_is_active') ?? true;
    _verificationStatus = prefs.getString('verification_status') ?? 'pending';
    _fetchProfile();
  }

  Future<void> _fetchProfile({bool isManualCheck = false}) async {
    if (isManualCheck) {
      setState(() {
        _isCheckingStatus = true;
      });
    }
    try {
      final volunteerDataSource = GetIt.instance<VolunteerRemoteDataSource>();
      final response = await volunteerDataSource.getRelawanProfile();

      final userData = response['user'];
      if (userData != null) {
        final bool wasActive = _isActive;
        final bool newIsActive = (userData['is_active'] == true || userData['is_active'] == 1 || userData['is_active'] == '1');
        final newStatus = (userData['status_verifikasi'] ?? 'pending').toString().toLowerCase();
        final wasVerified = _verificationStatus == 'terverifikasi';
        final isNowVerified = newStatus == 'terverifikasi';

        setState(() {
          _fullUserData = userData;
          _name = userData['name'] ?? 'Relawan';
          _phone = userData['no_telp'] ?? 'Belum diatur';
          _location = userData['lokasi_user'] ?? 'Lokasi belum tersedia';
          _address = userData['alamat'] ?? 'Alamat belum diatur';
          _job = userData['pekerjaan'] ?? 'Belum diatur';
          _reason = userData['alasan_relawan'] ?? 'Belum diatur';
          _verificationStatus = newStatus;
          _isActive = newIsActive;

          if (userData['email'] != null) {
            _email = userData['email'];
          }

          if (userData['foto_profile'] != null &&
              userData['foto_profile'].toString().isNotEmpty) {
            final String foto = userData['foto_profile'];
            if (foto.startsWith('http://') || foto.startsWith('https://')) {
              _avatarUrl = foto;
            } else {
              _avatarUrl = '${ApiConstants.baseUrl}/storage-file/$foto';
            }
          }

          _isLoading = false;
          _isCheckingStatus = false;
        });

        final prefs = GetIt.instance<SharedPreferences>();
        await prefs.setString('verification_status', newStatus);
        await prefs.setBool('user_is_active', newIsActive);
        event_bus.GlobalEventBus.volunteerActiveStatus.value = newIsActive;

        if (!newIsActive) {
          if (isManualCheck && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Akun Anda saat ini dinonaktifkan oleh administrator.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else if (!wasActive && newIsActive) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selamat! Akun Anda telah diaktifkan kembali oleh administrator.'),
                backgroundColor: primaryTeal,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else if (!wasVerified && isNowVerified) {
          event_bus.GlobalEventBus.volunteerVerificationStatus.value = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selamat! Akun Anda telah diverifikasi oleh admin. Seluruh fitur relawan kini dapat diakses.'),
                backgroundColor: primaryTeal,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else if (isManualCheck && mounted) {
          if (newStatus == 'pending') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Akun Anda masih dalam tahap verifikasi oleh admin. Mohon menunggu.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else if (newStatus == 'ditolak') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pengajuan akun relawan ditolak oleh admin.'),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Status akun aktif dan terverifikasi.'),
                backgroundColor: primaryTeal,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching volunteer profile: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCheckingStatus = false;
        });
        if (isManualCheck) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memeriksa status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
        final currentBg = isHighContrast ? Colors.black : const Color(0xFFF5F6F8);
        final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
        final textPrimary = AccessibleColors.textPrimary(isHighContrast);
        final textSecondary = AccessibleColors.textSecondary(isHighContrast);

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: currentBg,
          appBar: _buildAppBar(isHighContrast, currentBg, tealColor),
          body: Container(
            color: currentBg,
            child: _isLoading
                ? Center(
                    child: CupertinoActivityIndicator(
                      radius: 16,
                      color: tealColor,
                    ),
                  )
                : SafeArea(
                    child: RefreshIndicator(
                      onRefresh: _fetchProfile,
                      color: tealColor,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildProfileHeader(
                              isHighContrast: isHighContrast,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              tealColor: tealColor,
                            ),
                            if (!_isActive || _verificationStatus != 'terverifikasi') ...[
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildVerificationStatusCard(
                                  isHighContrast: isHighContrast,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSectionHeader(
                                    icon: CupertinoIcons.briefcase,
                                    title: 'Informasi Relawan',
                                    tealColor: tealColor,
                                    textPrimary: textPrimary,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildVolunteerInfoCard(
                                    isHighContrast: isHighContrast,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                    tealColor: tealColor,
                                  ),
                                  const SizedBox(height: 24),

                                  _buildSectionHeader(
                                    icon: CupertinoIcons.shield,
                                    title: 'Privasi & Lokasi',
                                    tealColor: tealColor,
                                    textPrimary: textPrimary,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildPrivacyCard(
                                    isHighContrast: isHighContrast,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                  const SizedBox(height: 24),

                                  _buildSectionHeader(
                                    icon: CupertinoIcons.question_circle,
                                    title: 'Bantuan',
                                    tealColor: tealColor,
                                    textPrimary: textPrimary,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildHelpCard(
                                    isHighContrast: isHighContrast,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                  const SizedBox(height: 32),

                                  _buildLogoutButton(
                                    isHighContrast: isHighContrast,
                                    tealColor: tealColor,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Text(
                                      'versi 1.0 Beta',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
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
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    bool isHighContrast,
    Color currentBg,
    Color tealColor,
  ) {
    return AppBar(
      backgroundColor: currentBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: tealColor),
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 24, height: 24),
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
          icon: Icon(CupertinoIcons.pencil, color: tealColor, size: 28),
          tooltip: 'Edit Profil',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    BorderRadius? borderRadius,
    bool isHighContrast = false,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isHighContrast ? 0.35 : 0.05),
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
            decoration: BoxDecoration(
              color: isHighContrast
                  ? const Color(0xFF121212)
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: radius,
              border: Border.all(
                color: isHighContrast
                    ? const Color(0xFF4B5563)
                    : Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required bool isHighContrast,
    required Color textPrimary,
    required Color textSecondary,
    required Color tealColor,
  }) {
    final bool isVerified = _verificationStatus == 'terverifikasi';

    return _buildGlassContainer(
      isHighContrast: isHighContrast,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(
          top: 24,
          bottom: 32,
          left: 16,
          right: 16,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: !_isActive
                      ? (isHighContrast ? const Color(0xFFFCA5A5) : Colors.red)
                      : (isVerified
                          ? tealColor
                          : (isHighContrast
                              ? const Color(0xFFFCD34D)
                              : Colors.orange.withValues(alpha: 0.3))),
                  width: 3,
                ),
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: isHighContrast
                    ? const Color(0xFF1E2430)
                    : Colors.grey.shade200,
                backgroundImage: NetworkImage(_avatarUrl),
                onBackgroundImageError: (_, _) {},
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                if (isVerified && _isActive)
                  Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    color: tealColor,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_email != '-')
              Text(
                _email,
                style: TextStyle(fontSize: 14, color: textSecondary),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isHighContrast
                    ? (!_isActive
                        ? const Color(0xFF450A0A)
                        : (isVerified
                            ? const Color(0xFF064E3B)
                            : (_verificationStatus == 'ditolak'
                                ? const Color(0xFF450A0A)
                                : const Color(0xFF451A03))))
                    : (!_isActive
                        ? const Color(0xFFFFEBEE)
                        : (isVerified
                            ? const Color(0xFFE0F2F1)
                            : (_verificationStatus == 'ditolak'
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xFFFFE0B2)))),
                borderRadius: BorderRadius.circular(20),
                border: isHighContrast
                    ? Border.all(
                        color: !_isActive
                            ? const Color(0xFFEF4444)
                            : (isVerified
                                ? const Color(0xFF10B981)
                                : (_verificationStatus == 'ditolak'
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFF59E0B))),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    !_isActive
                        ? CupertinoIcons.slash_circle_fill
                        : (isVerified
                            ? CupertinoIcons.checkmark_shield_fill
                            : (_verificationStatus == 'ditolak'
                                ? CupertinoIcons.clear_thick_circled
                                : CupertinoIcons.time)),
                    color: isHighContrast
                        ? (!_isActive
                            ? const Color(0xFFFCA5A5)
                            : (isVerified
                                ? const Color(0xFFA7F3D0)
                                : (_verificationStatus == 'ditolak'
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFFFDE68A))))
                        : (!_isActive
                            ? Colors.red.shade700
                            : (isVerified
                                ? primaryTeal
                                : (_verificationStatus == 'ditolak'
                                    ? Colors.red.shade700
                                    : const Color(0xFFEF6C00)))),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    !_isActive
                        ? 'Akun Dinonaktifkan'
                        : (isVerified
                            ? 'Relawan Terverifikasi'
                            : (_verificationStatus == 'ditolak'
                                ? 'Verifikasi Ditolak'
                                : 'Menunggu Verifikasi')),
                    style: TextStyle(
                      fontSize: 13,
                      color: isHighContrast
                          ? (!_isActive
                              ? const Color(0xFFFCA5A5)
                              : (isVerified
                                  ? const Color(0xFFA7F3D0)
                                  : (_verificationStatus == 'ditolak'
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFFFDE68A))))
                          : (!_isActive
                              ? Colors.red.shade700
                              : (isVerified
                                  ? primaryTeal
                                  : (_verificationStatus == 'ditolak'
                                      ? Colors.red.shade700
                                      : const Color(0xFFEF6C00)))),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoBox(
              icon: CupertinoIcons.phone,
              label: 'Nomor Telepon',
              value: _phone,
              isHighContrast: isHighContrast,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              tealColor: tealColor,
            ),
            const SizedBox(height: 6),
            _buildInfoBox(
              icon: CupertinoIcons.location_solid,
              label: 'Lokasi Saat Ini',
              value: _location,
              isHighContrast: isHighContrast,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              tealColor: tealColor,
            ),
            const SizedBox(height: 6),
            _buildInfoBox(
              icon: CupertinoIcons.house,
              label: 'Alamat Lengkap',
              value: _address,
              isHighContrast: isHighContrast,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              tealColor: tealColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationStatusCard({
    required bool isHighContrast,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    if (!_isActive) {
      return Container(
        decoration: BoxDecoration(
          color: isHighContrast ? const Color(0xFF1E2430) : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighContrast ? const Color(0xFFEF4444) : const Color(0xFFFFCDD2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isHighContrast ? 0.3 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isHighContrast ? const Color(0xFFEF4444) : Colors.red.shade700)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.slash_circle_fill,
                    color: isHighContrast ? const Color(0xFFFCA5A5) : Colors.red.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Akun Relawan Dinonaktifkan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isHighContrast ? const Color(0xFFFCA5A5) : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Akun relawan Anda saat ini dinonaktifkan oleh administrator. Akses ke seluruh fitur operasional relawan (Beranda, Tugas, Peta) dibekukan sementara. Silakan hubungi admin atau periksa kembali status akun Anda.',
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCheckingStatus
                    ? null
                    : () => _fetchProfile(isManualCheck: true),
                icon: _isCheckingStatus
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CupertinoActivityIndicator(radius: 8),
                      )
                    : const Icon(CupertinoIcons.arrow_2_circlepath, size: 16),
                label: Text(
                  _isCheckingStatus ? 'Memeriksa...' : 'Periksa Status Akun',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isHighContrast ? const Color(0xFFB91C1C) : Colors.red.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isHighContrast
                        ? const BorderSide(color: Color(0xFFFCA5A5), width: 1.5)
                        : BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isRejected = _verificationStatus == 'ditolak';
    final cardColor = isHighContrast
        ? const Color(0xFF1E2430)
        : (isRejected ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0));
    final borderColor = isHighContrast
        ? (isRejected ? const Color(0xFFEF4444) : const Color(0xFFF59E0B))
        : (isRejected ? const Color(0xFFFFCDD2) : const Color(0xFFFFE0B2));
    final iconColor = isHighContrast
        ? (isRejected ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D))
        : (isRejected ? Colors.red.shade700 : const Color(0xFFEF6C00));

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isHighContrast ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRejected
                      ? CupertinoIcons.clear_thick_circled
                      : CupertinoIcons.hourglass,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isRejected
                      ? 'Verifikasi Relawan Ditolak'
                      : 'Tahap Verifikasi Relawan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isRejected
                ? 'Pendaftaran akun relawan Anda ditolak oleh administrator. Silakan hubungi tim admin untuk informasi lebih detail.'
                : 'Akun Anda saat ini belum diverifikasi oleh admin. Semua fitur operasional relawan (Beranda, Tugas, Peta) dibatasi hingga akun disetujui.',
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCheckingStatus
                  ? null
                  : () => _fetchProfile(isManualCheck: true),
              icon: _isCheckingStatus
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CupertinoActivityIndicator(radius: 8),
                    )
                  : const Icon(CupertinoIcons.arrow_2_circlepath, size: 16),
              label: Text(
                _isCheckingStatus ? 'Memeriksa...' : 'Periksa Status Verifikasi',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isHighContrast
                    ? (isRejected ? const Color(0xFFB91C1C) : const Color(0xFFD97706))
                    : (isRejected ? Colors.red.shade700 : const Color(0xFFEF6C00)),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isHighContrast
                      ? BorderSide(color: iconColor, width: 1.5)
                      : BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolunteerInfoCard({
    required bool isHighContrast,
    required Color textPrimary,
    required Color textSecondary,
    required Color tealColor,
  }) {
    return _buildGlassContainer(
      isHighContrast: isHighContrast,
      child: Column(
        children: [
          _buildInfoTile(
            icon: CupertinoIcons.briefcase_fill,
            title: 'Pekerjaan',
            value: _job,
            isHighContrast: isHighContrast,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            tealColor: tealColor,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: isHighContrast ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          ),
          _buildInfoTile(
            icon: CupertinoIcons.heart_fill,
            title: 'Alasan Menjadi Relawan',
            value: _reason,
            isHighContrast: isHighContrast,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            tealColor: tealColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isHighContrast,
    required Color textPrimary,
    required Color textSecondary,
    required Color tealColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighContrast
                  ? tealColor.withValues(alpha: 0.2)
                  : primaryTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tealColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String label,
    required String value,
    required bool isHighContrast,
    required Color textPrimary,
    required Color textSecondary,
    required Color tealColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isHighContrast ? const Color(0xFF1E2430) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighContrast ? const Color(0xFF4B5563) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: tealColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  value.trim(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color tealColor,
    required Color textPrimary,
  }) {
    return Row(
      children: [
        Icon(icon, color: tealColor, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyCard({
    required bool isHighContrast,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighContrast ? const Color(0xFF1E2430) : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: isHighContrast
                  ? Border.all(color: const Color(0xFF4B5563))
                  : null,
            ),
            child: Icon(
              CupertinoIcons.location,
              color: isHighContrast ? const Color(0xFFFDBA74) : const Color(0xFFEF6C00),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Status Ketersediaan & Lokasi',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lokasi Anda dibagikan agar pengguna yang membutuhkan dapat menemukan relawan terdekat. Anda bisa mengatur privasi ini di pengaturan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard({
    required bool isHighContrast,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return _buildGlassContainer(
      isHighContrast: isHighContrast,
      child: Column(
        children: [
          _buildHelpTile(
            icon: CupertinoIcons.info,
            iconColor: isHighContrast ? const Color(0xFF93C5FD) : Colors.blue.shade700,
            iconBg: isHighContrast ? const Color(0xFF1E2430) : Colors.blue.shade50,
            title: 'Panduan Relawan',
            subtitle: 'SOP darurat, FAQ, cara menangani SOS',
            isHighContrast: isHighContrast,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: isHighContrast ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          ),
          _buildHelpTile(
            icon: CupertinoIcons.headphones,
            iconColor: isHighContrast ? const Color(0xFFFDBA74) : Colors.orange.shade700,
            iconBg: isHighContrast ? const Color(0xFF1E2430) : Colors.orange.shade50,
            title: 'Hubungi Admin',
            subtitle: 'Bantuan koordinasi laporan',
            isHighContrast: isHighContrast,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
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
    required bool isHighContrast,
    required Color textPrimary,
    required Color textSecondary,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
                border: isHighContrast
                    ? Border.all(color: const Color(0xFF4B5563))
                    : null,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: isHighContrast ? const Color(0xFF9CA3AF) : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton({
    required bool isHighContrast,
    required Color tealColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () async {
          final confirm = await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isHighContrast ? const Color(0xFF121212) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: isHighContrast
                    ? Border.all(color: const Color(0xFF4B5563), width: 1.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isHighContrast ? 0.35 : 0.1,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isHighContrast
                            ? const Color(0xFF4B5563)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isHighContrast
                            ? const Color(0xFF450A0A)
                            : const Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                        border: isHighContrast
                            ? Border.all(color: const Color(0xFFEF4444))
                            : null,
                      ),
                      child: Icon(
                        CupertinoIcons.arrow_right_square,
                        color: isHighContrast
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFD32F2F),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keluar Akun',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Apakah Anda yakin ingin keluar dari akun ini?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tealColor,
                              side: BorderSide(
                                color: isHighContrast
                                    ? const Color(0xFF4B5563)
                                    : tealColor.withValues(alpha: 0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isHighContrast
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFFD32F2F),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: isHighContrast
                                    ? const BorderSide(
                                        color: Color(0xFFFCA5A5),
                                        width: 1.5,
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                            child: const Text(
                              'Ya, Keluar',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
          await prefs.remove('user_role');
          if (!mounted) return;
          context.go(AppRoutes.login);
        },
        icon: const Icon(CupertinoIcons.arrow_right_square),
        label: const Text(
          'Keluar Akun',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isHighContrast
              ? const Color(0xFF450A0A)
              : const Color(0xFFFFEBEE),
          foregroundColor: isHighContrast
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFD32F2F),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isHighContrast
                ? const BorderSide(color: Color(0xFFEF4444), width: 1.5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
