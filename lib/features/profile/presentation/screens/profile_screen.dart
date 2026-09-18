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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryTeal = Color(0xFF00695C);

  bool _isLoading = true;
  Map<String, dynamic>? _fullUserData;
  
  String _name = 'Memuat...';
  String _email = '-';
  String _category = 'Umum';
  String _phone = '-';
  String _location = '-';
  String _address = '-';
  String _avatarUrl = 'https://placehold.co/100x100.png';

  bool _voiceGuide = true;
  bool _haptic = true;
  bool _highContrast = false; // Local state only based on requirements
  bool _largeText = true;

  Dio get _dio => GetIt.instance<Dio>();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }



  Future<void> _fetchProfile() async {
    try {
      final profileDataSource = GetIt.instance<ProfileRemoteDataSource>();
      final response = await profileDataSource.getProfile();

      final userData = response['data'] ?? response['user'];
      if (userData != null) {
        setState(() {
          _fullUserData = userData;
          _name = userData['name'] ?? 'Pengguna';
          _email = userData['email'] ?? '-';
          _phone = userData['no_telp'] ?? 'Belum diatur';
          _location = userData['lokasi_user'] ?? 'Lokasi belum tersedia';
          _address = userData['alamat'] ?? 'Alamat belum diatur';
          
          String cat = userData['kategori_user'] ?? 'umum';
          _category = cat.substring(0, 1).toUpperCase() + cat.substring(1);
          
          // The API returns aksesibilitas as an object if hit via /pengguna/profile
          if (userData['aksesibilitas'] != null) {
            _voiceGuide = userData['aksesibilitas']['panduan_suara'] == true;
            _haptic = userData['aksesibilitas']['getaran'] == true;
            _largeText = userData['aksesibilitas']['text_besar'] == true;
          } else {
            _voiceGuide = (userData['panduan_suara'] == 1 || userData['panduan_suara'] == true);
            _haptic = (userData['getaran'] == 1 || userData['getaran'] == true);
            _largeText = (userData['text_besar'] == 1 || userData['text_besar'] == true);
          }
          
          if (userData['foto_profile'] != null && userData['foto_profile'].toString().isNotEmpty) {
            String foto = userData['foto_profile'];
            if (foto.startsWith('http://') || foto.startsWith('https://')) {
              _avatarUrl = foto;
            } else {
              // Gunakan API route khusus agar tidak terblokir CORS saat dev Web
              _avatarUrl = '${ApiConstants.baseUrl}/storage-file/$foto';
            }
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    if (_fullUserData == null) return;
    
    // Update local map
    _fullUserData![key] = value ? 1 : 0;
    
    try {
      Map<String, dynamic> dataToUpdate = {
        key: value ? 1 : 0,
      };

      final profileDataSource = GetIt.instance<ProfileRemoteDataSource>();
      await profileDataSource.updateProfile(dataToUpdate);
    } catch (e) {
      debugPrint("Error updating setting $key: $e");
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'tunanetra':
        return Icons.visibility_off_outlined;
      case 'tunarungu':
        return Icons.hearing_disabled_outlined;
      case 'tunawicara':
        return Icons.speaker_notes_off_outlined;
      case 'umum':
      default:
        return Icons.person_outline_rounded;
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
                            icon: CupertinoIcons.person_circle_fill,
                            title: 'Aksesibilitas',
                          ),
                          const SizedBox(height: 12),
                          _buildSettingsCard(),
                          const SizedBox(height: 24),

                          _buildSectionHeader(
                            icon: CupertinoIcons.shield_fill,
                            title: 'Privasi & Lokasi',
                          ),
                          const SizedBox(height: 12),
                          _buildPrivacyCard(),
                          const SizedBox(height: 24),

                          _buildSectionHeader(
                            icon: CupertinoIcons.bluetooth,
                            title: 'Perangkat Pintar',
                          ),
                          const SizedBox(height: 12),
                          _buildGlassContainer(
                            child: _buildHelpTile(
                              icon: CupertinoIcons.antenna_radiowaves_left_right,
                              iconColor: primaryTeal,
                              iconBg: primaryTeal.withValues(alpha: 0.1),
                              title: 'Kelola Tombol SOS (Tuya)',
                              subtitle: 'Hubungkan dan atur tombol fisik bluetooth',
                              onTap: () => context.push(AppRoutes.tuyaDevices),
                            ),
                          ),
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
        'Profil Saya',
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
              final result = await context.push<bool>(AppRoutes.editProfile, extra: _fullUserData);
              if (result == true) {
                _fetchProfile(); // Refresh profile when returning from edit page
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
              border: Border.all(color: primaryTeal.withValues(alpha: 0.3), width: 3),
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: NetworkImage(_avatarUrl),
              onBackgroundImageError: (_, _) {
                // Fallback when image fails to load (e.g. 429 Too Many Requests)
                // No-op here, flutter handles it by showing background color
              },
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
              const Icon(CupertinoIcons.checkmark_seal_fill, color: primaryTeal, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _email,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0B2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getCategoryIcon(_category), color: const Color(0xFFEF6C00), size: 16),
                const SizedBox(width: 6),
                Text(
                  _category,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFEF6C00), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoBox(
            icon: CupertinoIcons.device_phone_portrait,
            label: 'Telepon Darurat',
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

  Widget _buildSettingsCard() {
    return _buildGlassContainer(
      child: Column(
        children: [
          _buildToggleItem(
            icon: CupertinoIcons.waveform,
            title: 'Panduan Suara (TalkBack)',
            subtitle: 'Narasi suara otomatis aktif.',
            value: _voiceGuide,
            onChanged: (v) {
              setState(() => _voiceGuide = v);
              _updateSetting('panduan_suara', v);
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildToggleItem(
            icon: CupertinoIcons.waveform_path,
            title: 'Umpan Balik Getaran',
            subtitle: 'Getaran taktil tombol.',
            value: _haptic,
            onChanged: (v) {
              setState(() => _haptic = v);
              _updateSetting('getaran', v);
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildToggleItem(
            icon: CupertinoIcons.circle_lefthalf_fill,
            title: 'Kontras Tinggi',
            subtitle: 'Warna gelap & terang pekat.',
            value: _highContrast,
            onChanged: (v) {
              setState(() => _highContrast = v);
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildToggleItem(
            icon: CupertinoIcons.textformat,
            title: 'Teks Besar',
            subtitle: 'Ukuran font lebih besar.',
            value: _largeText,
            onChanged: (v) {
              setState(() => _largeText = v);
              _updateSetting('text_besar', v);
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: primaryTeal,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
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
                Text('Perlindungan Pelacakan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                SizedBox(height: 6),
                Text(
                  'Lokasi hanya dibagikan saat tombol SOS ditekan. Data dienkripsi secara penuh untuk keamanan Anda.',
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
            title: 'Pusat Bantuan & Panduan',
            subtitle: 'FAQ, panduan gestur, tutorial',
          ),
          const Divider(height: 1, indent: 56),
          _buildHelpTile(
            icon: CupertinoIcons.headphones,
            iconColor: Colors.orange.shade700,
            iconBg: Colors.orange.shade50,
            title: 'Hubungi Sahabat SOS',
            subtitle: 'Bantuan operator darurat 24/7',
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
          // Revoke token di server
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



