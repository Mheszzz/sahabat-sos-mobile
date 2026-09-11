import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../routing/routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color bgColor = Color(0xFFF5F6F8);

  bool _isLoading = true;
  Map<String, dynamic>? _fullUserData;
  
  String _name = 'Memuat...';
  String _category = 'Umum';
  String _phone = '-';
  String _location = '-';
  String _address = '-';
  String _avatarUrl = 'https://placehold.co/100x100.png';

  bool _voiceGuide = true;
  bool _haptic = true;
  bool _highContrast = false; // Local state only based on requirements
  bool _largeText = true;

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        setState(() { _isLoading = false; });
        return;
      }

      final response = await _dio.get(
        ApiConstants.me,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        }),
      );

      if (response.statusCode == 200) {
        final userData = response.data['user'];
        setState(() {
          _fullUserData = userData;
          _name = userData['name'] ?? 'Pengguna';
          _phone = userData['no_telp'] ?? 'Belum diatur';
          _location = userData['lokasi_user'] ?? 'Mendeteksi lokasi...';
          _address = userData['alamat'] ?? 'Alamat belum diatur';
          
          String cat = userData['kategori_user'] ?? 'umum';
          _category = cat.substring(0, 1).toUpperCase() + cat.substring(1);
          
          _voiceGuide = (userData['panduan_suara'] == 1 || userData['panduan_suara'] == true);
          _haptic = (userData['getaran'] == 1 || userData['getaran'] == true);
          _largeText = (userData['text_besar'] == 1 || userData['text_besar'] == true);
          
          if (userData['foto_profile'] != null) {
            _avatarUrl = userData['foto_profile'];
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      // completeProfile requires alamat and no_telp
      Map<String, dynamic> dataToUpdate = {
        'alamat': _fullUserData!['alamat'] ?? '-',
        'no_telp': _fullUserData!['no_telp'] ?? '-',
        key: value ? 1 : 0,
      };

      await _dio.post(
        ApiConstants.completeProfile,
        data: dataToUpdate,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        }),
      );
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

  Future<void> _showEditProfileDialog() async {
    if (_fullUserData == null) return;

    final nameController = TextEditingController(text: _fullUserData!['name'] ?? '');
    final emailController = TextEditingController(text: _fullUserData!['email'] ?? '');
    final phoneController = TextEditingController(text: _fullUserData!['no_telp'] ?? '');
    final addressController = TextEditingController(text: _fullUserData!['alamat'] ?? '');

    String selectedCategory = _fullUserData!['kategori_user']?.toString().toLowerCase() ?? 'umum';
    if (!['umum', 'tunanetra', 'tunarungu', 'tunawicara'].contains(selectedCategory)) {
      selectedCategory = 'umum';
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Edit Profil',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildModernTextField(nameController, 'Nama Lengkap', Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildModernTextField(emailController, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8A8FA3)),
                          items: [
                            {'value': 'umum', 'label': 'Umum', 'icon': Icons.person_outline_rounded},
                            {'value': 'tunanetra', 'label': 'Tunanetra', 'icon': Icons.visibility_off_outlined},
                            {'value': 'tunarungu', 'label': 'Tunarungu', 'icon': Icons.hearing_disabled_outlined},
                            {'value': 'tunawicara', 'label': 'Tunawicara', 'icon': Icons.speaker_notes_off_outlined},
                          ].map((item) {
                            return DropdownMenuItem<String>(
                              value: item['value'] as String,
                              child: Row(
                                children: [
                                  Icon(item['icon'] as IconData, color: const Color(0xFF8A8FA3), size: 20),
                                  const SizedBox(width: 12),
                                  Text(item['label'] as String, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E))),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setModalState(() {
                                selectedCategory = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    _buildModernTextField(phoneController, 'Nomor Telepon', Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildModernTextField(addressController, 'Alamat Tempat Tinggal (Cth: Jl. Merdeka...)', Icons.home_outlined),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Simpan Perubahan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() { _isLoading = true; });
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null) {
          Map<String, dynamic> dataToUpdate = {
            'name': nameController.text.isNotEmpty ? nameController.text : '-',
            'email': emailController.text,
            'kategori_user': selectedCategory,
            'alamat': addressController.text.isNotEmpty ? addressController.text : '-',
            'no_telp': phoneController.text.isNotEmpty ? phoneController.text : '-',
            'getaran': _haptic ? 1 : 0,
            'panduan_suara': _voiceGuide ? 1 : 0,
            'text_besar': _largeText ? 1 : 0,
          };

          await _dio.post(
            ApiConstants.completeProfile,
            data: dataToUpdate,
            options: Options(headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            }),
          );
          
          await _fetchProfile(); // Refresh data after update
        }
      } catch (e) {
        debugPrint("Error updating profile: $e");
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: primaryTeal))
        : SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
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
                          icon: Icons.accessibility_new_rounded,
                          title: 'Aksesibilitas',
                        ),
                        const SizedBox(height: 12),
                        _buildSettingsCard(),
                        const SizedBox(height: 24),

                        _buildSectionHeader(
                          icon: Icons.shield_rounded,
                          title: 'Privasi & Lokasi',
                        ),
                        const SizedBox(height: 12),
                        _buildPrivacyCard(),
                        const SizedBox(height: 24),

                        _buildSectionHeader(
                          icon: Icons.headset_mic_rounded,
                          title: 'Bantuan',
                        ),
                        const SizedBox(height: 12),
                        _buildHelpCard(),
                        const SizedBox(height: 32),

                        _buildLogoutButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: const Text(
        'Profil Saya',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          onPressed: _showEditProfileDialog,
          icon: const Icon(Icons.edit_note_rounded, color: primaryTeal, size: 28),
          tooltip: 'Edit Profil',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 24, bottom: 32, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primaryTeal.withOpacity(0.3), width: 3),
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: NetworkImage(_avatarUrl),
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
              const Icon(Icons.verified, color: primaryTeal, size: 20),
            ],
          ),
          const SizedBox(height: 8),
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
            icon: Icons.phone_android_rounded,
            label: 'Telepon Darurat',
            value: _phone,
          ),
          const SizedBox(height: 12),
          _buildInfoBox(
            icon: Icons.location_on_rounded,
            label: 'Lokasi Saat Ini',
            value: _location,
          ),
          const SizedBox(height: 12),
          _buildInfoBox(
            icon: Icons.home_work_rounded,
            label: 'Alamat Lengkap',
            value: _address,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryTeal, size: 20),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          _buildToggleItem(
            icon: Icons.record_voice_over_rounded,
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
            icon: Icons.vibration_rounded,
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
            icon: Icons.contrast_rounded,
            title: 'Kontras Tinggi',
            subtitle: 'Warna gelap & terang pekat.',
            value: _highContrast,
            onChanged: (v) {
              setState(() => _highContrast = v);
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildToggleItem(
            icon: Icons.text_fields_rounded,
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
            decoration: BoxDecoration(color: primaryTeal.withOpacity(0.1), shape: BoxShape.circle),
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
            activeColor: Colors.white,
            activeTrackColor: primaryTeal,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.gps_fixed_rounded, color: Color(0xFFEF6C00), size: 24),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          _buildHelpTile(
            icon: Icons.help_outline_rounded,
            iconColor: Colors.blue.shade700,
            iconBg: Colors.blue.shade50,
            title: 'Pusat Bantuan & Panduan',
            subtitle: 'FAQ, panduan gestur, tutorial',
          ),
          const Divider(height: 1, indent: 56),
          _buildHelpTile(
            icon: Icons.headset_mic_rounded,
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
  }) {
    return InkWell(
      onTap: () {},
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
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
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
          await prefs.remove('auth_token');
          await prefs.remove('is_profile_complete');
          if (context.mounted) {
            context.go(AppRoutes.login);
          }
        },
        icon: const Icon(Icons.logout_rounded),
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

  Widget _buildModernTextField(TextEditingController controller, String hint, IconData icon, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB0B4C4)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          prefixIcon: Icon(icon, color: const Color(0xFF8A8FA3)),
        ),
      ),
    );
  }
}
