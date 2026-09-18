import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../routing/routes.dart';
import 'package:get_it/get_it.dart';

import '../../data/datasources/profile_remote_data_source.dart';

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  static const Color primaryTeal = Color(0xFF00695C);

  bool _isLoading = true;
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
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final profileDataSource = GetIt.instance<ProfileRemoteDataSource>();
      final response = await profileDataSource.getMe();

      final userData = response['user'];
      if (userData != null) {
        setState(() {
          _fullUserData = userData;
          _name = userData['name'] ?? 'Relawan';
          _phone = userData['no_telp'] ?? 'Belum diatur';
          _location = userData['lokasi_user'] ?? 'Lokasi belum tersedia';
          _address = userData['alamat'] ?? 'Alamat belum diatur';
          _job = userData['pekerjaan'] ?? 'Belum diatur';
          _reason = userData['alasan_relawan'] ?? 'Belum diatur';
          _verificationStatus = userData['status_verifikasi'] ?? 'pending';
          
          if (userData['foto_profile'] != null && userData['foto_profile'].toString().isNotEmpty) {
            String foto = userData['foto_profile'];
            if (foto.startsWith('http://') || foto.startsWith('https://')) {
              _avatarUrl = foto;
            } else {
              _avatarUrl = '${ApiConstants.baseUrl}/storage-file/$foto';
            }
          }
          
          _isLoading = false;
        });
        
        // Coba panggil profile endpoint jika email nggak dapet dari /user/me
        if (_email == '-') {
           try {
             final profileResp = await profileDataSource.getProfile();
             final pData = profileResp['data'];
             if (pData != null && pData['email'] != null) {
                setState(() {
                  _email = pData['email'];
                });
             }
           } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint("Error fetching volunteer profile: $e");
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0F7FA), // Light blue/teal
              Color(0xFFF5F6F8), // Greyish white
              Color(0xFFE0F2F1), // Light teal
            ],
          ),
        ),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: primaryTeal))
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _fetchProfile,
                color: primaryTeal,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 24),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader(
                            icon: CupertinoIcons.briefcase,
                            title: 'Informasi Relawan',
                          ),
                          const SizedBox(height: 12),
                          _buildVolunteerInfoCard(),
                          const SizedBox(height: 24),

                          _buildSectionHeader(
                            icon: CupertinoIcons.shield_fill,
                            title: 'Privasi & Lokasi',
                          ),
                          const SizedBox(height: 12),
                          _buildPrivacyCard(),
                          const SizedBox(height: 24),

                          _buildSectionHeader(
                            icon: CupertinoIcons.headphones,
                            title: 'Bantuan',
                          ),
                          const SizedBox(height: 12),
                          _buildHelpCard(),
                          const SizedBox(height: 32),

                          _buildLogoutButton(),
                          const SizedBox(height: 24),
                          const Center(
                            child: Text(
                              'versi 1 beta',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
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
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: const Text(
        'Profil Relawan',
        style: TextStyle(
          color: primaryTeal,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () async {
            if (_fullUserData != null) {
              // Bisa diarahkan ke halaman edit profil relawan
              final result = await context.push<bool>(AppRoutes.editProfile, extra: _fullUserData);
              if (result == true) {
                _fetchProfile();
              }
            }
          },
          icon: const Icon(CupertinoIcons.pencil, color: primaryTeal, size: 28),
          tooltip: 'Edit Profil',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildGlassContainer({required Widget child, BorderRadius? borderRadius}) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: radius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    bool isVerified = _verificationStatus == 'terverifikasi';

    return _buildGlassContainer(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 24, bottom: 32, left: 16, right: 16),
        child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isVerified ? primaryTeal : Colors.orange.withValues(alpha: 0.3), width: 3),
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Colors.grey.shade200,
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
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (isVerified)
                const Icon(CupertinoIcons.checkmark_seal_fill, color: primaryTeal, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          if (_email != '-')
            Text(
              _email,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isVerified ? const Color(0xFFE0F2F1) : const Color(0xFFFFE0B2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVerified ? Icons.health_and_safety_rounded : Icons.pending_actions_rounded,
                  color: isVerified ? primaryTeal : const Color(0xFFEF6C00), 
                  size: 16
                ),
                const SizedBox(width: 6),
                Text(
                  isVerified ? 'Relawan Terverifikasi' : 'Menunggu Verifikasi',
                  style: TextStyle(
                    fontSize: 13, 
                    color: isVerified ? primaryTeal : const Color(0xFFEF6C00), 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoBox(
            icon: CupertinoIcons.device_phone_portrait,
            label: 'Nomor Telepon',
            value: _phone,
          ),
          const SizedBox(height: 6),
          _buildInfoBox(
            icon: CupertinoIcons.location_solid,
            label: 'Lokasi Saat Ini',
            value: _location,
          ),
          const SizedBox(height: 6),
          _buildInfoBox(
            icon: CupertinoIcons.house_fill,
            label: 'Alamat Lengkap',
            value: _address,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildVolunteerInfoCard() {
    return _buildGlassContainer(
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.work_rounded,
            title: 'Pekerjaan',
            value: _job,
          ),
          const Divider(height: 1, indent: 56),
          _buildInfoTile(
            icon: Icons.volunteer_activism_rounded,
            title: 'Alasan Menjadi Relawan',
            value: _reason,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: primaryTeal.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: primaryTeal, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: primaryTeal, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: primaryTeal, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildPrivacyCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Icon(CupertinoIcons.location_fill, color: Color(0xFFEF6C00), size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status Ketersediaan & Lokasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                SizedBox(height: 6),
                Text(
                  'Lokasi Anda dibagikan agar pengguna yang membutuhkan dapat menemukan relawan terdekat. Anda bisa mengatur privasi ini di pengaturan.',
                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return _buildGlassContainer(
      child: Column(
        children: [
          _buildHelpTile(
            icon: CupertinoIcons.info,
            iconColor: Colors.blue.shade700,
            iconBg: Colors.blue.shade50,
            title: 'Panduan Relawan',
            subtitle: 'SOP darurat, FAQ, cara menangani SOS',
          ),
          const Divider(height: 1, indent: 56),
          _buildHelpTile(
            icon: CupertinoIcons.headphones,
            iconColor: Colors.orange.shade700,
            iconBg: Colors.orange.shade50,
            title: 'Hubungi Admin',
            subtitle: 'Bantuan koordinasi laporan',
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
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          try {
            await _dio.post(
              ApiConstants.logout,
              options: Options(headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              }),
            );
          } catch (_) {}
          await prefs.remove('auth_token');
          await prefs.remove('is_profile_complete');
          await prefs.remove('user_role');
          if (!mounted) return;
          context.go(AppRoutes.login);
        },
        icon: const Icon(CupertinoIcons.arrow_right_square),
        label: const Text('Keluar Akun', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFEBEE),
          foregroundColor: const Color(0xFFD32F2F),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}


