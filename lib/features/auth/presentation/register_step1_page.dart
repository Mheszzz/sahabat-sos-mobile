import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';
import 'package:get_it/get_it.dart' as get_it;
import 'package:sahabat_sos_mobile/features/auth/data/datasources/auth_remote_data_source.dart';

class RegisterStep1Page extends StatefulWidget {
  const RegisterStep1Page({super.key});

  @override
  State<RegisterStep1Page> createState() => _RegisterStep1PageState();
}

class _RegisterStep1PageState extends State<RegisterStep1Page> {
  static const Color primaryDark = Color(0xFF006D77);
  static const Color accentTeal = Color(0xFF0E9F6E);
  static const Color bgColor = Color(0xFFEFEFEF);
  static const Color fieldFill = Color(0xFFEFF1F8);
  static const Color mutedText = Color(0xFF6B7080);

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _agreedToTerms = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProgressSection(),
                        const SizedBox(height: 12),
                        _buildBrandRow(),
                        const SizedBox(height: 6),
                        const Text(
                          'Daftar Akun Sahabat SOS',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Lengkapi data untuk perlindungan darurat\nterpadu dan respons relawan cepat.',
                          style: TextStyle(fontSize: 13.5, color: mutedText, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        _buildGoogleCard(context),
                        const SizedBox(height: 32),
                        _buildTermsCheckbox(),
                        const Spacer(),
                        const SizedBox(height: 20),
                        _buildLoginPrompt(),
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

  Widget _buildBrandRow() {
    return Row(
      children: const [
        Text(
          'Sahabat SOS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: primaryDark,
          ),
        ),
        SizedBox(width: 6),
        Icon(Icons.verified_rounded, size: 16, color: accentTeal),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.person_add_alt_1_outlined, size: 15, color: accentTeal),
            SizedBox(width: 6),
            Text(
              'Langkah 1 dari 2: Registrasi Akun',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
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
                backgroundColor: const Color(0xFFDCE6DF),
                valueColor: const AlwaysStoppedAnimation<Color>(primaryDark),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleCard(BuildContext context) {
    return InkWell(
      onTap: () async {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Memulai Registrasi Google...')),
          );

          final authDataSource = get_it.GetIt.instance<AuthRemoteDataSource>();
          final result = await authDataSource.signInWithGoogle();

          if (!context.mounted) return;

          if (result != null) {
            final bool isProfileComplete = result['is_profile_complete'] ?? false;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Berhasil Registrasi dengan Google!')),
            );

            if (isProfileComplete) {
              context.go(AppRoutes.dashboard);
            } else {
              context.push(AppRoutes.registerStep2);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registrasi dibatalkan oleh user.')),
            );
          }
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal Registrasi: $e')),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFE6D8)),
      ),
      child: Row(
        children: [
          Image.network(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
            width: 26,
            height: 26,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.error_outline,
              size: 26,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Lanjutkan dengan Akun Google',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Otomatis terhubung dengan email & nama\nterverifikasi',
                  style: TextStyle(fontSize: 12.5, color: mutedText, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
            activeColor: primaryDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 13, color: Color(0xFF1A1A2E), height: 1.4),
              children: [
                TextSpan(text: 'Saya menyetujui '),
                TextSpan(
                  text: 'Ketentuan Layanan',
                  style: TextStyle(
                    color: accentTeal,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: ' &\n'),
                TextSpan(
                  text: 'Perlindungan Data Pribadi',
                  style: TextStyle(
                    color: accentTeal,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: ' Sahabat SOS untuk\npenyelamatan darurat.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: GestureDetector(
        onTap: () {
          context.go(AppRoutes.login);
        },
        child: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 14, color: mutedText),
            children: [
              TextSpan(text: 'Sudah memiliki akun? '),
              TextSpan(
                text: 'Masuk di Sini',
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
