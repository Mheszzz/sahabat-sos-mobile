import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_it/get_it.dart' as get_it;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/accessibility_service.dart';
import '../../../../core/theme/accessible_colors.dart';
import '../../../../routing/routes.dart';

enum _NeedType { tunanetra, tunarungu, tunawicara, umum }

enum _RoleType { pengguna, relawan }

class RegisterStep2Page extends StatefulWidget {
  const RegisterStep2Page({super.key});

  @override
  State<RegisterStep2Page> createState() => _RegisterStep2PageState();
}

class _RegisterStep2PageState extends State<RegisterStep2Page> {
  static const Color primaryDark = Color(0xFF006D77);
  static const Color accentTeal = Color(0xFF0E9F6E);
  static const Color fieldFill = Color(0xFFEFF1F8);
  static const Color mutedText = Color(0xFF6B7080);

  _RoleType _selectedRole = _RoleType.pengguna;
  _NeedType _selectedNeed = _NeedType.umum;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _userPhoneController = TextEditingController();
  final TextEditingController _jobController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  XFile? _kycDocument;

  bool _voiceGuidanceEnabled = true;
  bool _hapticVibrationEnabled = true;
  bool _talkbackEnabled = false;
  bool _largeTextEnabled = false;

  Future<void> _pickKycDocument() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _kycDocument = picked;
        });
      }
    } catch (e) {
      debugPrint('Gagal memilih berkas KYC: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final dio = get_it.GetIt.instance<Dio>();
    final prefs = get_it.GetIt.instance<SharedPreferences>();
    final token = prefs.getString('auth_token');

    if (token == null) return;

    try {
      final response = await dio.get(
        ApiConstants.me,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final userData = response.data['user'];
        if (userData != null && userData['name'] != null) {
          setState(() {
            _nameController.text = userData['name'];
          });
        }
      }
    } catch (e) {
      debugPrint('Gagal fetch profile: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _userPhoneController.dispose();
    _jobController.dispose();
    _reasonController.dispose();
    super.dispose();
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
        final currentBg =
            isHighContrast ? Colors.black : const Color(0xFFF5F6F8);
        final textPrimary = AccessibleColors.textPrimary(isHighContrast);
        final textSecondary = AccessibleColors.textSecondary(isHighContrast);
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryDark;
        final accent =
            isHighContrast ? const Color(0xFF80CBC4) : accentTeal;
        final cardBg =
            isHighContrast ? const Color(0xFF121212) : Colors.white;
        final cardBorder =
            isHighContrast ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);
        final inputBg =
            isHighContrast ? const Color(0xFF1E2430) : fieldFill;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: currentBg,
          body: Container(
            color: currentBg,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProgressSection(
                                  isHighContrast, textPrimary, tealColor, accent),
                              const SizedBox(height: 18),
                              _buildBrandRow(),
                              const SizedBox(height: 10),
                              Text(
                                'Personalisasi Perlindungan\nDarurat',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Penentuan profil disabilitas, sensor SOS &\nkontak darurat untuk ketepatan bantuan.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 22),
                              _buildSectionHeader(
                                CupertinoIcons.person_crop_circle_badge_checkmark,
                                'Pilih Peran',
                                textPrimary,
                              ),
                              const SizedBox(height: 12),
                              _buildRoleSelection(
                                  isHighContrast, cardBg, cardBorder, textPrimary),
                              const SizedBox(height: 22),
                              _buildSectionHeader(
                                CupertinoIcons.person,
                                'Informasi Pribadi',
                                textPrimary,
                              ),
                              const SizedBox(height: 12),
                              _buildPersonalInfoCard(
                                  isHighContrast,
                                  cardBg,
                                  cardBorder,
                                  inputBg,
                                  textPrimary,
                                  textSecondary),
                              if (_selectedRole == _RoleType.pengguna) ...[
                                const SizedBox(height: 22),
                                _buildSectionHeader(
                                  CupertinoIcons.person_2,
                                  'Kebutuhan Utama',
                                  textPrimary,
                                ),
                                const SizedBox(height: 12),
                                _buildNeedGrid(isHighContrast, cardBg,
                                    cardBorder, textPrimary),
                                const SizedBox(height: 22),
                                _buildSensorCard(isHighContrast, textPrimary,
                                    tealColor, accent),
                              ],
                              const Spacer(),
                              const SizedBox(height: 22),
                              _buildSubmitButton(isHighContrast, tealColor),
                              const SizedBox(height: 12),
                              _buildLogoutButton(isHighContrast, textPrimary,
                                  textSecondary, cardBg, cardBorder),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrandRow() {
    return Row(
      children: [Image.asset('assets/images/logo_full.png', height: 40)],
    );
  }

  Widget _buildProgressSection(bool isHighContrast, Color textPrimary,
      Color tealColor, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.checkmark_shield, size: 15, color: accent),
            const SizedBox(width: 6),
            Text(
              'Langkah 2 dari 2: Personalisasi Darurat',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: isHighContrast
                    ? const Color(0xFF1E2430)
                    : const Color(0xFFDCE6DF),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isHighContrast ? const Color(0xFF80CBC4) : primaryDark,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color textPrimary) {
    return Row(
      children: [
        Icon(icon, size: 18, color: textPrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoCard(
      bool isHighContrast,
      Color cardBg,
      Color cardBorder,
      Color inputBg,
      Color textPrimary,
      Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardBorder,
          width: isHighContrast ? 1.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isHighContrast ? 0.35 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nama Lengkap',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
              border: isHighContrast
                  ? Border.all(color: const Color(0xFF4B5563))
                  : null,
            ),
            child: TextField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              style: TextStyle(
                fontSize: 14,
                color: textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Contoh: Budi Santoso',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isHighContrast
                      ? const Color(0xFF6B7280)
                      : const Color(0xFFB0B4C4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                prefixIcon: Icon(
                  CupertinoIcons.person,
                  color: isHighContrast
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF8A8FA3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nomor Telepon Pribadi',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
              border: isHighContrast
                  ? Border.all(color: const Color(0xFF4B5563))
                  : null,
            ),
            child: TextField(
              controller: _userPhoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(
                fontSize: 14,
                color: textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Contoh: 081234567890',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isHighContrast
                      ? const Color(0xFF6B7280)
                      : const Color(0xFFB0B4C4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                prefixIcon: Icon(
                  CupertinoIcons.phone,
                  color: isHighContrast
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF8A8FA3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Alamat Lengkap',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
              border: isHighContrast
                  ? Border.all(color: const Color(0xFF4B5563))
                  : null,
            ),
            child: TextField(
              controller: _addressController,
              maxLines: 3,
              style: TextStyle(
                fontSize: 14,
                color: textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Masukkan alamat tempat tinggal...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isHighContrast
                      ? const Color(0xFF6B7280)
                      : const Color(0xFFB0B4C4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          if (_selectedRole == _RoleType.relawan) ...[
            const SizedBox(height: 16),
            Text(
              'Pekerjaan',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(12),
                border: isHighContrast
                    ? Border.all(color: const Color(0xFF4B5563))
                    : null,
              ),
              child: TextField(
                controller: _jobController,
                keyboardType: TextInputType.text,
                style: TextStyle(
                  fontSize: 14,
                  color: textPrimary,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Contoh: Mahasiswa, Pegawai Swasta',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isHighContrast
                        ? const Color(0xFF6B7280)
                        : const Color(0xFFB0B4C4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.briefcase,
                    color: isHighContrast
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF8A8FA3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Alasan Menjadi Relawan',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(12),
                border: isHighContrast
                    ? Border.all(color: const Color(0xFF4B5563))
                    : null,
              ),
              child: TextField(
                controller: _reasonController,
                maxLines: 3,
                style: TextStyle(
                  fontSize: 14,
                  color: textPrimary,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Berikan alasan singkat Anda...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isHighContrast
                        ? const Color(0xFF6B7280)
                        : const Color(0xFFB0B4C4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Dokumen Identitas & Kualifikasi (KYC)',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lampirkan foto KTP, KTA, atau sertifikat relawan untuk diverifikasi oleh administrator posko.',
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isHighContrast
                      ? const Color(0xFF4B5563)
                      : (_kycDocument != null ? const Color(0xFF10B981) : const Color(0xFFCBD0DE)),
                  width: _kycDocument != null ? 1.5 : 1.0,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _kycDocument != null
                        ? (isHighContrast ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                        : (isHighContrast ? const Color(0xFF1E2430) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _kycDocument != null
                        ? CupertinoIcons.doc_checkmark_fill
                        : CupertinoIcons.doc_text,
                    color: _kycDocument != null
                        ? (isHighContrast ? const Color(0xFF6EE7B7) : const Color(0xFF059669))
                        : (isHighContrast ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
                    size: 20,
                  ),
                ),
                title: Text(
                  _kycDocument != null
                      ? _kycDocument!.name
                      : 'Pilih Berkas KYC (Foto / Dokumen)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _kycDocument != null ? FontWeight.bold : FontWeight.w500,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _kycDocument != null
                      ? 'Dokumen siap dilampirkan'
                      : 'Format: JPG, PNG, atau scan dokumen',
                  style: TextStyle(
                    fontSize: 11,
                    color: _kycDocument != null
                        ? (isHighContrast ? const Color(0xFF6EE7B7) : const Color(0xFF059669))
                        : textSecondary,
                  ),
                ),
                trailing: _kycDocument != null
                    ? IconButton(
                        icon: const Icon(CupertinoIcons.clear_circled, size: 20),
                        color: Colors.redAccent,
                        tooltip: 'Hapus berkas',
                        onPressed: () => setState(() => _kycDocument = null),
                      )
                    : Icon(
                        CupertinoIcons.photo_camera,
                        size: 20,
                        color: isHighContrast ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                      ),
                onTap: _pickKycDocument,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleSelection(bool isHighContrast, Color cardBg,
      Color cardBorder, Color textPrimary) {
    return Row(
      children: [
        Expanded(
          child: _buildRoleCard(
            type: _RoleType.pengguna,
            icon: CupertinoIcons.person,
            label: 'Pengguna',
            isHighContrast: isHighContrast,
            cardBg: cardBg,
            cardBorder: cardBorder,
            textPrimary: textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRoleCard(
            type: _RoleType.relawan,
            icon: CupertinoIcons.person_2,
            label: 'Relawan',
            isHighContrast: isHighContrast,
            cardBg: cardBg,
            cardBorder: cardBorder,
            textPrimary: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required _RoleType type,
    required IconData icon,
    required String label,
    required bool isHighContrast,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
  }) {
    final bool selected = _selectedRole == type;
    final selectedBg =
        isHighContrast ? const Color(0xFF00897B) : primaryDark;
    final unselectedBg = cardBg;

    return Container(
      decoration: BoxDecoration(
        color: selected ? selectedBg : unselectedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? (isHighContrast ? const Color(0xFF80CBC4) : primaryDark)
              : cardBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isHighContrast ? 0.35 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedRole = type),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: selected ? Colors.white : textPrimary,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeedGrid(bool isHighContrast, Color cardBg, Color cardBorder,
      Color textPrimary) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildNeedCard(
                  type: _NeedType.tunanetra,
                  icon: CupertinoIcons.eye_slash,
                  label: 'Tunanetra',
                  isHighContrast: isHighContrast,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNeedCard(
                  type: _NeedType.tunarungu,
                  icon: CupertinoIcons.ear,
                  label: 'Tunarungu',
                  isHighContrast: isHighContrast,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildNeedCard(
                  type: _NeedType.tunawicara,
                  icon: CupertinoIcons.mic_slash,
                  label: 'Tunawicara',
                  isHighContrast: isHighContrast,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNeedCard(
                  type: _NeedType.umum,
                  icon: CupertinoIcons.person,
                  label: 'Umum',
                  isHighContrast: isHighContrast,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textPrimary: textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNeedCard({
    required _NeedType type,
    required IconData icon,
    required String label,
    required bool isHighContrast,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
  }) {
    final bool selected = _selectedNeed == type;
    final selectedBg =
        isHighContrast ? const Color(0xFF00897B) : primaryDark;
    final unselectedBg = cardBg;

    return Container(
      decoration: BoxDecoration(
        color: selected ? selectedBg : unselectedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? (isHighContrast ? const Color(0xFF80CBC4) : primaryDark)
              : cardBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isHighContrast ? 0.35 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedNeed = type;
              if (type == _NeedType.tunanetra) {
                _voiceGuidanceEnabled = true;
                _hapticVibrationEnabled = true;
                _talkbackEnabled = true;
                _largeTextEnabled = true;
              } else if (type == _NeedType.tunarungu) {
                _voiceGuidanceEnabled = false;
                _hapticVibrationEnabled = true;
                _talkbackEnabled = false;
                _largeTextEnabled = true;
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 26,
                      color: selected ? Colors.white : textPrimary,
                    ),
                    if (selected) ...[
                      const Spacer(),
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.white,
                        child: Icon(
                          CupertinoIcons.checkmark_alt,
                          size: 12,
                          color: selectedBg,
                        ),
                      ),
                    ] else ...[
                      const Spacer(),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isHighContrast
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFCBD0DE),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : textPrimary,
                      height: 1.2,
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

  Widget _buildSensorCard(bool isHighContrast, Color textPrimary,
      Color tealColor, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          CupertinoIcons.slider_horizontal_3,
          'Sensor & Aksesibilitas',
          textPrimary,
        ),
        const SizedBox(height: 16),
        _buildSensorToggleRow(
          icon: CupertinoIcons.speaker_2,
          label: 'Panduan Suara Otomatis',
          value: _voiceGuidanceEnabled,
          isHighContrast: isHighContrast,
          textPrimary: textPrimary,
          accent: accent,
          tealColor: tealColor,
          onChanged: (v) => setState(() => _voiceGuidanceEnabled = v),
        ),
        const SizedBox(height: 16),
        _buildSensorToggleRow(
          icon: CupertinoIcons.waveform_path,
          label: 'Getaran Haptik Penuh',
          value: _hapticVibrationEnabled,
          isHighContrast: isHighContrast,
          textPrimary: textPrimary,
          accent: accent,
          tealColor: tealColor,
          onChanged: (v) => setState(() => _hapticVibrationEnabled = v),
        ),
        const SizedBox(height: 16),
        _buildSensorToggleRow(
          icon: CupertinoIcons.speaker_2,
          label: 'TalkBack / Pembaca Layar',
          value: _talkbackEnabled,
          isHighContrast: isHighContrast,
          textPrimary: textPrimary,
          accent: accent,
          tealColor: tealColor,
          onChanged: (v) => setState(() => _talkbackEnabled = v),
        ),
        const SizedBox(height: 16),
        _buildSensorToggleRow(
          icon: CupertinoIcons.textformat,
          label: 'Teks Besar / High Contrast',
          value: _largeTextEnabled,
          isHighContrast: isHighContrast,
          textPrimary: textPrimary,
          accent: accent,
          tealColor: tealColor,
          onChanged: (v) => setState(() => _largeTextEnabled = v),
        ),
      ],
    );
  }

  Widget _buildSensorToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required bool isHighContrast,
    required Color textPrimary,
    required Color accent,
    required Color tealColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isHighContrast
                ? const Color(0xFF1E3A34)
                : const Color(0xFFDDF3EA),
            shape: BoxShape.circle,
            border: isHighContrast
                ? Border.all(color: const Color(0xFF00897B))
                : null,
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor:
              isHighContrast ? const Color(0xFF00897B) : primaryDark,
        ),
      ],
    );
  }

  Future<void> _submitProfile() async {
    final dio = get_it.GetIt.instance<Dio>();
    final prefs = get_it.GetIt.instance<SharedPreferences>();
    final token = prefs.getString('auth_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi tidak ditemukan, silakan login ulang.'),
        ),
      );
      return;
    }

    if (_nameController.text.isEmpty ||
        _addressController.text.trim().isEmpty ||
        _userPhoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama, Nomor Telepon & Alamat wajib diisi!'),
        ),
      );
      return;
    }

    if (_selectedRole == _RoleType.relawan) {
      if (_jobController.text.isEmpty || _reasonController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pekerjaan dan Alasan wajib diisi untuk Relawan!'),
          ),
        );
        return;
      }
    }

    String kategori = 'umum';
    if (_selectedNeed == _NeedType.tunanetra) kategori = 'tunanetra';
    if (_selectedNeed == _NeedType.tunarungu) kategori = 'tunarungu';
    if (_selectedNeed == _NeedType.tunawicara) kategori = 'tunawicara';

    try {
      // Menampilkan Loading
      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CupertinoActivityIndicator(radius: 16)),
        ),
      );

      final Map<String, dynamic> payload = {
        'name': _nameController.text,
        'alamat': _addressController.text.trim(),
        'no_telp': _userPhoneController.text,
        'role': _selectedRole == _RoleType.relawan ? 'relawan' : 'pengguna',
        'status_ketersediaan': _selectedRole == _RoleType.relawan ? 'tersedia' : 'aktif',
      };

      if (_selectedRole == _RoleType.relawan) {
        payload['pekerjaan'] = _jobController.text;
        payload['alasan_relawan'] = _reasonController.text;
      } else {
        payload['kategori_user'] = kategori;
        payload['getaran'] = _hapticVibrationEnabled;
        payload['talkback'] = _talkbackEnabled;
        payload['panduan_suara'] = _voiceGuidanceEnabled;
        payload['text_besar'] = _largeTextEnabled;
      }

      dynamic requestBody = payload;
      if (_selectedRole == _RoleType.relawan && _kycDocument != null) {
        final formMap = Map<String, dynamic>.from(payload);
        final bytes = await _kycDocument!.readAsBytes();
        formMap['dokumen_kyc'] = MultipartFile.fromBytes(
          bytes,
          filename: _kycDocument!.name,
        );
        requestBody = FormData.fromMap(formMap);
      }

      final response = await dio.post(
        ApiConstants.completeProfile,
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (!mounted) return;
      Navigator.pop(context); // Tutup Loading

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          await dio.put(
            ApiConstants.profile,
            data: {'name': _nameController.text},
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            ),
          );
        } catch (_) {}

        await prefs.setBool('is_profile_complete', true);
        await prefs.setString(
          'user_role',
          _selectedRole == _RoleType.relawan ? 'relawan' : 'pengguna',
        );
        if (_selectedRole == _RoleType.relawan) {
          final verificationStatus = (response.data['status_verifikasi'] ?? 'pending').toString().toLowerCase();
          await prefs.setString('verification_status', verificationStatus);
        } else {
          await AccessibilityService.instance.applyCategoryDefaults(kategori, syncBackend: false);
          await AccessibilityService.instance.setTalkback(_talkbackEnabled, syncBackend: false);
          await AccessibilityService.instance.setVoiceGuide(_voiceGuidanceEnabled, syncBackend: false);
          await AccessibilityService.instance.setHaptic(_hapticVibrationEnabled, syncBackend: false);
          await AccessibilityService.instance.setLargeText(_largeTextEnabled, syncBackend: false);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil disimpan!')),
        );
        if (_selectedRole == _RoleType.relawan) {
          context.go(AppRoutes.homeVolunteer);
        } else {
          context.go(AppRoutes.dashboard);
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan profil: ${response.data}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Tutup Loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
    }
  }

  Widget _buildSubmitButton(bool isHighContrast, Color tealColor) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _submitProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isHighContrast ? const Color(0xFF00897B) : primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.checkmark_shield, size: 18),
            SizedBox(width: 8),
            Text(
              'Simpan Registrasi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(
    bool isHighContrast,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color cardBorder,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
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
                    color: Colors.black
                        .withValues(alpha: isHighContrast ? 0.35 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                        Icons.cancel_outlined,
                        color: isHighContrast
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFD32F2F),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Batalkan Registrasi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Apakah Anda yakin ingin membatalkan registrasi dan keluar dari akun ini?',
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
                              foregroundColor: textPrimary,
                              side: BorderSide(
                                color: isHighContrast
                                    ? const Color(0xFF4B5563)
                                    : const Color(0xFF1A1A2E)
                                        .withValues(alpha: 0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Tidak',
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
          final prefs = get_it.GetIt.instance<SharedPreferences>();
          final token = prefs.getString('auth_token');
          // Revoke token di server
          try {
            final dio = get_it.GetIt.instance<Dio>();
            await dio.post(
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
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: cardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Batalkan & Kembali',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
