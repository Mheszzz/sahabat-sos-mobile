import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';
import 'package:get_it/get_it.dart' as get_it;
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import 'package:sahabat_sos_mobile/core/widgets/google_logo.dart';
import 'package:sahabat_sos_mobile/features/auth/data/datasources/auth_remote_data_source.dart';

class RegisterStep1Page extends StatefulWidget {
  const RegisterStep1Page({super.key});

  @override
  State<RegisterStep1Page> createState() => _RegisterStep1PageState();
}

class _RegisterStep1PageState extends State<RegisterStep1Page> {
  static const Color primaryDark = Color(0xFF006D77);
  static const Color accentTeal = Color(0xFF0E9F6E);

  bool _agreedToTerms = true;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _showTermsDialog(
            context,
            'Ketentuan Layanan',
            'Ketentuan Layanan Sahabat SOS:\n\n'
            '1. Layanan Sahabat SOS disediakan untuk membantu situasi darurat, pendampingan difabel, dan respons kebencanaan.\n\n'
            '2. Pengguna wajib memberikan data identitas dan kontak darurat yang benar.\n\n'
            '3. Tombol SOS hanya boleh digunakan untuk keadaan darurat nyata. Penyalahgunaan sinyal darurat dapat dikenai penonaktifan akun sesuai ketentuan yang berlaku.\n\n'
            '4. Relawan bertindak sesuai SOP dan panduan keselamatan resmi.',
          );
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _showTermsDialog(
            context,
            'Perlindungan Data Pribadi',
            'Kebijakan Perlindungan Data Pribadi:\n\n'
            '1. Data lokasi GPS Anda hanya dikirim dan diakses saat Anda memicu sinyal SOS atau mengirimkan Laporan Cepat.\n\n'
            '2. Data kontak darurat disimpan secara terenkripsi dan hanya digunakan untuk mengirimkan pemberitahuan otomatis saat terjadi keadaan darurat.\n\n'
            '3. Rekaman suara dan foto laporan hanya dapat diakses oleh relawan terverifikasi dan operator penanganan kasus.\n\n'
            '4. Data pribadi Anda tidak diperjualbelikan atau dibagikan ke pihak ketiga di luar penanganan keselamatan darurat.',
          );
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _showTermsDialog(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;
        final bg = isHighContrast ? const Color(0xFF1E1E1E) : Colors.white;
        final textPrimary =
            isHighContrast ? Colors.white : const Color(0xFF111827);
        final textSecondary =
            isHighContrast ? Colors.grey.shade300 : const Color(0xFF4B5563);

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.doc_text_fill,
                      color: Color(0xFF00695C),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        final currentBg =
            isHighContrast ? Colors.black : const Color(0xFFF5F6F8);
        final textPrimary = AccessibleColors.textPrimary(isHighContrast);
        final textSecondary = AccessibleColors.textSecondary(isHighContrast);
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryDark;
        final accent =
            isHighContrast ? const Color(0xFF80CBC4) : accentTeal;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: currentBg,
          resizeToAvoidBottomInset: false,
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
                              const SizedBox(height: 12),
                              _buildBrandRow(),
                              const SizedBox(height: 6),
                              Text(
                                'Daftar Akun Sahabat SOS',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lengkapi data untuk perlindungan darurat\nterpadu dan respons relawan cepat.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildGoogleCard(
                                  isHighContrast, textPrimary, textSecondary),
                              const SizedBox(height: 32),
                              _buildTermsCheckbox(
                                  isHighContrast, textPrimary, tealColor, accent),
                              const Spacer(),
                              const SizedBox(height: 20),
                              _buildLoginPrompt(textSecondary, tealColor),
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
            Icon(CupertinoIcons.person_add, size: 15, color: accent),
            const SizedBox(width: 6),
            Text(
              'Langkah 1 dari 2: Registrasi Akun',
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
            tween: Tween<double>(begin: 0.0, end: 0.5),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: isHighContrast
                    ? const Color(0xFF1E2430)
                    : const Color(0xFFDCE6DF),
                valueColor: AlwaysStoppedAnimation<Color>(tealColor),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isLoading = false;

  Widget _buildGoogleCard(
      bool isHighContrast, Color textPrimary, Color textSecondary) {
    return Container(
      decoration: BoxDecoration(
        color: isHighContrast ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF4B5563)
              : const Color(0xFFE5E7EB),
          width: 1.5,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading
              ? null
              : () async {
                  if (!_agreedToTerms) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Harap setujui Syarat & Ketentuan terlebih dahulu.',
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _isLoading = true;
                  });
                  try {
                    final authDataSource =
                        get_it.GetIt.instance<AuthRemoteDataSource>();
                    final result = await authDataSource.signInWithGoogle();

                    if (!mounted) return;

                    setState(() {
                      _isLoading = false;
                    });

                    if (result != null) {
                      final bool isProfileComplete =
                          result['is_profile_complete'] ?? false;

                      if (isProfileComplete) {
                        if (!mounted) return;
                        context.go(AppRoutes.dashboard);
                      } else {
                        if (!mounted) return;
                        unawaited(context.push(AppRoutes.registerStep2));
                      }
                    } else {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Registrasi dibatalkan oleh user.'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _isLoading = false;
                    });
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Gagal Registrasi: $e')));
                  }
                },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _isLoading
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CupertinoActivityIndicator(radius: 12),
                      )
                    : const GoogleLogo(size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lanjutkan dengan Akun Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Otomatis terhubung dengan email & nama\nterverifikasi',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: textSecondary,
                          height: 1.3,
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
  }

  Widget _buildTermsCheckbox(bool isHighContrast, Color textPrimary,
      Color tealColor, Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Setujui Ketentuan Layanan dan Perlindungan Data Pribadi',
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _agreedToTerms,
                  onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                  activeColor: tealColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: textPrimary,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Saya menyetujui '),
                  TextSpan(
                    text: 'Ketentuan Layanan',
                    recognizer: _termsRecognizer,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: ' &\n'),
                  TextSpan(
                    text: 'Perlindungan Data Pribadi',
                    recognizer: _privacyRecognizer,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: ' Sahabat SOS untuk\npenyelamatan darurat.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPrompt(Color textSecondary, Color tealColor) {
    return Center(
      child: InkWell(
        onTap: () {
          context.go(AppRoutes.login);
        },
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: textSecondary),
                children: [
                  const TextSpan(text: 'Sudah memiliki akun? '),
                  TextSpan(
                    text: 'Masuk di Sini',
                    style: TextStyle(
                      color: tealColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
