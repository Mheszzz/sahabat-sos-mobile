import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';
import 'package:get_it/get_it.dart' as get_it;
import 'package:sahabat_sos_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart' as event_bus;
import 'package:sahabat_sos_mobile/core/widgets/google_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color primaryDark = Color(0xFF006D77); // Dark green

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
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTopBar(textPrimary),
                              const SizedBox(height: 24),
                              Center(
                                child: Image.asset(
                                  'assets/images/logo_full.png',
                                  height: 80,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Selamat Datang Kembali',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 60),
                              _buildGoogleButton(isHighContrast, textPrimary),
                              const Spacer(),
                              const SizedBox(height: 20),
                              _buildFooter(textSecondary, tealColor),
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

  Widget _buildTopBar(Color textPrimary) {
    return Text(
      'Masuk Akun',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
    );
  }

  bool _isLoading = false;

  Widget _buildGoogleButton(bool isHighContrast, Color textPrimary) {
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
                  setState(() {
                    _isLoading = true;
                  });
                  try {
                    // Panggil remote data source dari GetIt
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
                        try {
                          final prefs =
                              get_it.GetIt.instance<SharedPreferences>();
                          final token = result['token'];
                          Map<String, dynamic>? userData =
                              result['user'] is Map<String, dynamic>
                                  ? result['user'] as Map<String, dynamic>
                                  : (result['user'] != null
                                      ? Map<String, dynamic>.from(result['user'])
                                      : null);

                          if (userData == null) {
                            final dio = get_it.GetIt.instance<Dio>();
                            final profileRes = await dio.get(
                              ApiConstants.me,
                              options: Options(
                                headers: {
                                  'Authorization': 'Bearer $token',
                                  'Accept': 'application/json',
                                },
                              ),
                            );
                            if (profileRes.statusCode == 200) {
                              userData = profileRes.data['user'];
                            }
                          }

                          if (userData != null && userData['role'] != null) {
                            final role = userData['role'].toString().toLowerCase();
                            await prefs.setString('user_role', role);
                            if (role == 'relawan') {
                              if (userData['id'] != null) {
                                await prefs.setInt(
                                  'volunteer_id',
                                  (userData['id'] is int)
                                      ? userData['id']
                                      : int.tryParse(userData['id'].toString()) ?? 0,
                                );
                              }
                              final verificationStatus =
                                  (userData['status_verifikasi'] ?? 'pending')
                                      .toString()
                                      .toLowerCase();
                              await prefs.setString(
                                  'verification_status', verificationStatus);
                              event_bus.GlobalEventBus.volunteerVerificationStatus
                                  .value = (verificationStatus == 'terverifikasi');
                              final isActive = (userData['is_active'] == true ||
                                  userData['is_active'] == 1 ||
                                  userData['is_active'] == '1');
                              await prefs.setBool('user_is_active', isActive);
                              event_bus.GlobalEventBus.volunteerActiveStatus
                                  .value = isActive;
                            }
                          }
                        } catch (e) {
                          debugPrint("Error fetching user on login: $e");
                        }
                        if (!mounted) return;

                        final userRole =
                            get_it.GetIt.instance<SharedPreferences>()
                                .getString('user_role');
                        if (userRole == 'relawan') {
                          context.go(AppRoutes.homeVolunteer);
                        } else {
                          context.go(AppRoutes.dashboard);
                        }
                      } else {
                        if (!mounted) return;
                        unawaited(context.push(AppRoutes.registerStep2));
                      }
                    } else {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Login dibatalkan oleh user.'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _isLoading = false;
                    });
                    final errorMessage = e.toString().replaceFirst('Exception: ', '');
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Gagal Login: $errorMessage')));
                  }
                },
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: _isLoading
                ? const Center(
                    child: CupertinoActivityIndicator(radius: 12),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const GoogleLogo(size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Masuk dengan Akun Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(Color textSecondary, Color tealColor) {
    return Center(
      child: InkWell(
        onTap: () {
          context.go(AppRoutes.register);
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
                  const TextSpan(text: 'Belum punya akun Sahabat SOS? '),
                  TextSpan(
                    text: 'Daftar di Sini',
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
