import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';
import 'package:get_it/get_it.dart' as get_it;
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
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
                    : Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                        width: 26,
                        height: 26,
                        errorBuilder: (_, _, _) => const Icon(
                          CupertinoIcons.exclamationmark_circle,
                          size: 26,
                          color: Colors.red,
                        ),
                      ),
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
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
            activeColor: tealColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
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
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const TextSpan(text: ' &\n'),
                TextSpan(
                  text: 'Perlindungan Data Pribadi',
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
      ],
    );
  }

  Widget _buildLoginPrompt(Color textSecondary, Color tealColor) {
    return Center(
      child: GestureDetector(
        onTap: () {
          context.go(AppRoutes.login);
        },
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
    );
  }
}
