import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../routing/routes.dart';
import '../../../../core/services/accessibility_service.dart';
import '../../../../core/theme/accessible_colors.dart';
import '../../../volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import '../../../../core/utils/global_event_bus.dart' as event_bus;
import '../../../dashboard/presentation/widgets/volunteer_sop_modal.dart';

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
  String? _rejectionReason;
  String? _avatarUrl;

  Dio get _dio => GetIt.instance<Dio>();

  @override
  void initState() {
    super.initState();
    final prefs = GetIt.instance<SharedPreferences>();
    _isActive = prefs.getBool('user_is_active') ?? true;
    _verificationStatus = prefs.getString('verification_status') ?? 'pending';
    _rejectionReason = prefs.getString('rejection_reason');
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
        final bool newIsActive = (userData['is_active'] == true ||
            userData['is_active'] == 1 ||
            userData['is_active'] == '1');
        final newStatus = (userData['status_verifikasi'] ?? 'pending')
            .toString()
            .toLowerCase();
        final wasVerified = _verificationStatus == 'terverifikasi';
        final isNowVerified = newStatus == 'terverifikasi';
        final reason = userData['alasan_penolakan']?.toString();

        final prefs = GetIt.instance<SharedPreferences>();
        if (reason != null && reason.isNotEmpty) {
          await prefs.setString('rejection_reason', reason);
        } else {
          await prefs.remove('rejection_reason');
        }

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
          _rejectionReason = reason;

          if (userData['email'] != null) {
            _email = userData['email'];
          }

          final rawFoto = userData['foto_profile_url'] ?? userData['foto_profile'];
          if (rawFoto != null &&
              rawFoto.toString().isNotEmpty) {
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
          _isCheckingStatus = false;
        });

        await prefs.setString('verification_status', newStatus);
        await prefs.setBool('user_is_active', newIsActive);
        event_bus.GlobalEventBus.volunteerActiveStatus.value = newIsActive;

        if (!newIsActive) {
          if (isManualCheck && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Akun Anda saat ini dinonaktifkan oleh administrator.'),
                backgroundColor: Color(0xFFDC2626),
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else if (!wasActive && newIsActive) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Akun Anda telah diaktifkan kembali oleh administrator.'),
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
                content: Text(
                  'Selamat! Akun relawan Anda telah diverifikasi oleh admin.',
                ),
                backgroundColor: primaryTeal,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else if (isManualCheck && mounted) {
          if (newStatus == 'pending') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Akun Anda masih dalam tahap verifikasi oleh admin.'),
                backgroundColor: Color(0xFFD97706),
              ),
            );
          } else if (newStatus == 'ditolak') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pengajuan akun relawan belum disetujui admin.'),
                backgroundColor: Color(0xFFDC2626),
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
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCallAdmin() async {
    final uri = Uri.parse('tel:112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat melakukan panggilan ke 112.')),
        );
      }
    }
  }

  void _showHelpActionSheet(
    bool isHighContrast,
    Color tealColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AccessibleColors.cardBackground(isHighContrast),
          borderRadius: BorderRadius.circular(20),
          border: AccessibleColors.cardBorder(isHighContrast),
          boxShadow: isHighContrast
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tealColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.headphones,
                        color: tealColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Bantuan & Koordinasi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Pusat layanan siaga dan koordinasi penanganan darurat bagi relawan Sahabat SOS.',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isHighContrast
                          ? const Color(0xFF1E2430)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.phone_fill,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Panggilan Darurat (112)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Layanan darurat nasional bebas pulsa',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleCallAdmin();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isHighContrast
                          ? const Color(0xFF1E2430)
                          : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CupertinoIcons.book_fill,
                      color: tealColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Panduan SOP Lengkap',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Tata cara penanganan dan keselamatan di lapangan',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    showVolunteerSopModal(context);
                  },
                ),
              ],
            ),
          ),
        ),
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
        final currentBg = AccessibleColors.scaffoldBackground(isHighContrast);
        final tealColor = AccessibleColors.primaryTeal(isHighContrast);
        final textPrimary = AccessibleColors.textPrimary(isHighContrast);
        final textSecondary = AccessibleColors.textSecondary(isHighContrast);

        return Scaffold(
          backgroundColor: currentBg,
          appBar: _buildAppBar(isHighContrast, currentBg, tealColor),
          body: _isLoading
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
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        MediaQuery.of(context).padding.bottom + 110,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileCard(
                            isHighContrast: isHighContrast,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            tealColor: tealColor,
                          ),
                          if (!_isActive ||
                              _verificationStatus != 'terverifikasi') ...[
                            const SizedBox(height: 16),
                            _buildVerificationStatusCard(
                              isHighContrast: isHighContrast,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ],
                          const SizedBox(height: 20),
                          _buildSectionHeader(
                            icon: CupertinoIcons.person_badge_plus_fill,
                            title: 'Informasi Penugasan',
                            tealColor: tealColor,
                            textPrimary: textPrimary,
                          ),
                          const SizedBox(height: 10),
                          _buildVolunteerInfoCard(
                            isHighContrast: isHighContrast,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            tealColor: tealColor,
                          ),
                          const SizedBox(height: 20),
                          _buildSectionHeader(
                            icon: CupertinoIcons.shield_fill,
                            title: 'Privasi & Lokasi Respon',
                            tealColor: tealColor,
                            textPrimary: textPrimary,
                          ),
                          const SizedBox(height: 10),
                          _buildPrivacyCard(
                            isHighContrast: isHighContrast,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            tealColor: tealColor,
                          ),
                          const SizedBox(height: 20),
                          _buildSectionHeader(
                            icon: CupertinoIcons.question_circle_fill,
                            title: 'Dukungan & Bantuan',
                            tealColor: tealColor,
                            textPrimary: textPrimary,
                          ),
                          const SizedBox(height: 10),
                          _buildHelpCard(
                            isHighContrast: isHighContrast,
                            tealColor: tealColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(height: 28),
                          _buildLogoutButton(
                            isHighContrast: isHighContrast,
                            tealColor: tealColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              'Sahabat SOS v1.0.0',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
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

  PreferredSizeWidget _buildAppBar(
    bool isHighContrast,
    Color currentBg,
    Color tealColor,
  ) {
    return AppBar(
      backgroundColor: currentBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 26, height: 26),
          const SizedBox(width: 10),
          Text(
            'Profil Relawan',
            style: TextStyle(
              color: tealColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
            icon: Icon(CupertinoIcons.pencil, color: tealColor, size: 22),
            tooltip: 'Edit Profil',
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required Widget child,
    BorderRadius? borderRadius,
    bool isHighContrast = false,
    EdgeInsetsGeometry? padding,
    Color? customBg,
    Border? customBorder,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: customBg ?? AccessibleColors.cardBackground(isHighContrast),
        borderRadius: radius,
        border: customBorder ?? AccessibleColors.cardBorder(isHighContrast),
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
      child: child,
    );
  }

  Widget _buildProfileCard({
    required bool isHighContrast,
    required Color textPrimary,
    required Color textSecondary,
    required Color tealColor,
  }) {
    final bool isVerified = _verificationStatus == 'terverifikasi';
    final hasAvatar = _avatarUrl != null && _avatarUrl!.isNotEmpty;

    return _buildCard(
      isHighContrast: isHighContrast,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: !_isActive
                      ? (isHighContrast ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                      : (isVerified
                          ? tealColor
                          : (isHighContrast
                              ? const Color(0xFFFCD34D)
                              : const Color(0xFFD97706))),
                  width: 3,
                ),
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: isHighContrast
                    ? const Color(0xFF1E2430)
                    : tealColor.withValues(alpha: 0.1),
                backgroundImage: hasAvatar ? NetworkImage(_avatarUrl!) : null,
                onBackgroundImageError: hasAvatar ? (_, _) {} : null,
                child: !hasAvatar
                    ? Text(
                        _name.isNotEmpty ? _name.trim().substring(0, 1).toUpperCase() : 'R',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: tealColor,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isVerified && _isActive) ...[
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  color: tealColor,
                  size: 20,
                ),
              ],
            ],
          ),
          if (_email != '-') ...[
            const SizedBox(height: 4),
            Text(
              _email,
              style: TextStyle(fontSize: 13, color: textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          if (!isVerified || !_isActive) ...[
            const SizedBox(height: 12),
            _buildVerificationBadge(
              isHighContrast: isHighContrast,
              isVerified: isVerified,
              tealColor: tealColor,
            ),
          ],
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: AccessibleColors.cardBorderColor(isHighContrast),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: CupertinoIcons.phone,
            label: 'Nomor Telepon',
            value: _phone,
            isHighContrast: isHighContrast,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            tealColor: tealColor,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: _phone));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nomor telepon disalin ke papan klip.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: CupertinoIcons.location_solid,
            label: 'Lokasi Terdaftar',
            value: _location,
            isHighContrast: isHighContrast,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            tealColor: tealColor,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: CupertinoIcons.house,
            label: 'Alamat Domisili',
            value: _address,
            isHighContrast: isHighContrast,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            tealColor: tealColor,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBadge({
    required bool isHighContrast,
    required bool isVerified,
    required Color tealColor,
  }) {
    if (isVerified && _isActive) {
      return const SizedBox.shrink();
    }

    Color bg;
    Color border;
    Color text;
    IconData icon;
    String label;

    if (_verificationStatus == 'ditolak') {
      bg = isHighContrast ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
      border = const Color(0xFFDC2626);
      text = isHighContrast ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
      icon = CupertinoIcons.clear_thick_circled;
      label = 'Verifikasi Ditolak';
    } else if (!_isActive) {
      bg = isHighContrast ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
      border = const Color(0xFFDC2626);
      text = isHighContrast ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
      icon = CupertinoIcons.slash_circle_fill;
      label = 'Akun Dinonaktifkan';
    } else {
      bg = isHighContrast ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      border = isHighContrast ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
      text = isHighContrast ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
      icon = CupertinoIcons.time;
      label = 'Menunggu Verifikasi Admin';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: text, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isHighContrast,
    required Color textPrimary,
    required Color textSecondary,
    required Color tealColor,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isHighContrast
                ? const Color(0xFF1E2430)
                : tealColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: isHighContrast
                ? Border.all(color: const Color(0xFF4B5563))
                : null,
          ),
          child: Icon(icon, color: tealColor, size: 18),
        ),
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
              const SizedBox(height: 2),
              Text(
                value.trim(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: EdgeInsets.zero,
            icon: Icon(CupertinoIcons.doc_on_doc, size: 18, color: tealColor),
            tooltip: 'Salin',
            onPressed: onCopy,
          ),
      ],
    );
  }

  Widget _buildVerificationStatusCard({
    required bool isHighContrast,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final bool isRejected = _verificationStatus == 'ditolak';
    final bool isInactive = !_isActive && !isRejected;

    final Color cardColor = isHighContrast
        ? const Color(0xFF1E2430)
        : (isInactive || isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB));
    final Color borderColor = isInactive || isRejected
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);
    final Color iconColor = isHighContrast
        ? (isInactive || isRejected ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D))
        : (isInactive || isRejected ? const Color(0xFFDC2626) : const Color(0xFFD97706));

    final String title = isInactive
        ? 'Akun Relawan Dinonaktifkan'
        : (isRejected ? 'Pengajuan Verifikasi Ditolak' : 'Proses Verifikasi Berkas');

    final String message = isInactive
        ? 'Akun Anda dinonaktifkan sementara oleh administrator. Akses fitur penugasan darurat dibekukan hingga akun diaktifkan kembali.'
        : (isRejected
            ? (_rejectionReason != null && _rejectionReason!.trim().isNotEmpty
                ? 'Alasan penolakan dari admin: "$_rejectionReason"\n\nSilakan perbaiki berkas atau hubungi posko koordinasi untuk informasi lebih lanjut.'
                : 'Pengajuan relawan Anda belum memenuhi kualifikasi verifikasi administrator. Silakan hubungi admin untuk konfirmasi lebih lanjut.')
            : 'Akun Anda sedang ditinjau oleh administrator. Anda akan menerima notifikasi segera setelah akun resmi disetujui.');

    final String buttonLabel = _isCheckingStatus
        ? 'Memeriksa...'
        : (isInactive ? 'Periksa Status Akun' : 'Periksa Status Verifikasi');

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
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
                  isInactive
                      ? CupertinoIcons.slash_circle_fill
                      : (isRejected
                          ? CupertinoIcons.clear_thick_circled
                          : CupertinoIcons.hourglass),
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isCheckingStatus
                  ? null
                  : () => _fetchProfile(isManualCheck: true),
              icon: _isCheckingStatus
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CupertinoActivityIndicator(radius: 8),
                    )
                  : const Icon(CupertinoIcons.arrow_2_circlepath, size: 16),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isHighContrast
                    ? (isInactive || isRejected
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFFB45309))
                    : (isInactive || isRejected
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFD97706)),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
    return _buildCard(
      isHighContrast: isHighContrast,
      child: Column(
        children: [
          _buildInfoTile(
            icon: CupertinoIcons.briefcase_fill,
            title: 'Pekerjaan Utama',
            value: _job,
            isHighContrast: isHighContrast,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            tealColor: tealColor,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: AccessibleColors.cardBorderColor(isHighContrast),
          ),
          _buildInfoTile(
            icon: CupertinoIcons.heart_fill,
            title: 'Motivasi Relawan',
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
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighContrast
                  ? tealColor.withValues(alpha: 0.2)
                  : tealColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tealColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
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

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color tealColor,
    required Color textPrimary,
  }) {
    return Row(
      children: [
        Icon(icon, color: tealColor, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
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
    required Color tealColor,
  }) {
    return _buildCard(
      isHighContrast: isHighContrast,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighContrast
                  ? const Color(0xFF1E2430)
                  : tealColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.location_circle_fill,
              color: tealColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Transparansi Lokasi GPS',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Koordinat lokasi Anda hanya dikirim saat bersiaga untuk memetakan respon darurat tercepat menuju korban yang membutuhkan bantuan.',
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
    required Color tealColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return _buildCard(
      isHighContrast: isHighContrast,
      child: Column(
        children: [
          _buildHelpTile(
            icon: CupertinoIcons.book_fill,
            iconColor: tealColor,
            iconBg: isHighContrast
                ? const Color(0xFF1E2430)
                : tealColor.withValues(alpha: 0.1),
            title: 'Panduan Relawan',
            subtitle: 'SOP darurat, etika pertolongan, dan panduan mitigasi',
            isHighContrast: isHighContrast,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => showVolunteerSopModal(context),
          ),
          Divider(
            height: 1,
            indent: 56,
            color: AccessibleColors.cardBorderColor(isHighContrast),
          ),
          _buildHelpTile(
            icon: CupertinoIcons.headphones,
            iconColor: const Color(0xFF2563EB),
            iconBg: isHighContrast
                ? const Color(0xFF1E2430)
                : const Color(0xFFEFF6FF),
            title: 'Pusat Bantuan & Koordinasi',
            subtitle: 'Hubungi administrator dan saluran siaga 112',
            isHighContrast: isHighContrast,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => _showHelpActionSheet(
              isHighContrast,
              tealColor,
              textPrimary,
              textSecondary,
            ),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
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
              size: 16,
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
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () async {
          final confirm = await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AccessibleColors.cardBackground(isHighContrast),
                borderRadius: BorderRadius.circular(20),
                border: AccessibleColors.cardBorder(isHighContrast),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isHighContrast ? 0.35 : 0.08,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isHighContrast
                            ? const Color(0xFF4B5563)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isHighContrast
                            ? const Color(0xFF450A0A)
                            : const Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                        border: isHighContrast
                            ? Border.all(color: const Color(0xFFEF4444))
                            : null,
                      ),
                      child: Icon(
                        CupertinoIcons.square_arrow_right,
                        color: isHighContrast
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFDC2626),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Keluar dari Akun',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sistem akan menghentikan pelacakan lokasi dan status siaga relawan setelah keluar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textPrimary,
                                side: BorderSide(
                                  color: AccessibleColors.cardBorderColor(isHighContrast),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Batal',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Ya, Keluar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
        icon: const Icon(CupertinoIcons.square_arrow_right, size: 18),
        label: const Text(
          'Keluar Akun',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isHighContrast
              ? const Color(0xFF450A0A)
              : const Color(0xFFFEE2E2),
          foregroundColor: isHighContrast
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFDC2626),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isHighContrast
                ? const BorderSide(color: Color(0xFFEF4444), width: 1.5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
