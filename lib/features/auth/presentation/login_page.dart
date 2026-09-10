import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';
import 'package:get_it/get_it.dart' as get_it;
import 'package:sahabat_sos_mobile/features/auth/data/datasources/auth_remote_data_source.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color primaryDark = Color(0xFF006D77); // Dark green
  static const Color bgColor = Color(0xFFEFEFEF); // Very light greyish

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 36),
                        const Text(
                          'Selamat Datang Kembali',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1B2F),
                          ),
                        ),
                        const SizedBox(height: 60),
                        _buildGoogleButton(),
                        const Spacer(),
                        const SizedBox(height: 20),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Masuk Akun',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B1B2F),
          ),
        ),
        Row(
          children: [
            _circleIconButton(
              icon: Icons.volume_up_rounded,
              bg: const Color(0xFF7CF0D6),
              iconColor: primaryDark,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required Color bg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  bool _isLoading = false;

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton(
        onPressed: _isLoading ? null : () async {
          setState(() {
            _isLoading = true;
          });
          try {
            // Panggil remote data source dari GetIt
            final authDataSource = get_it.GetIt.instance<AuthRemoteDataSource>();
            final result = await authDataSource.signInWithGoogle();

            if (!context.mounted) return;

            setState(() {
              _isLoading = false;
            });

            if (result != null) {
              final bool isProfileComplete = result['is_profile_complete'] ?? false;
              
              if (isProfileComplete) {
                context.go(AppRoutes.dashboard);
              } else {
                context.push(AppRoutes.registerStep2);
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Login dibatalkan oleh user.')),
              );
            }
          } catch (e) {
            if (!context.mounted) return;
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal Login: $e')),
            );
          }
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE1E4EE)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryDark),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.error_outline,
                      size: 24,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Masuk dengan Akun Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1B2F),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: GestureDetector(
        onTap: () {
          context.go(AppRoutes.register);
        },
        child: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7080)),
            children: [
              TextSpan(text: 'Belum punya akun Sahabat SOS? '),
              TextSpan(
                text: 'Daftar di Sini',
                style: TextStyle(
                  color: primaryDark,
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
