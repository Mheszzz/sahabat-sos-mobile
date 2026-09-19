import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart' as get_it;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';
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

  bool _voiceGuidanceEnabled = true;
  bool _hapticVibrationEnabled = true;
  bool _talkbackEnabled = false;
  bool _largeTextEnabled = false;

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
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
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
        child: SafeArea(
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
                        const SizedBox(height: 18),
                        _buildBrandRow(),
                        const SizedBox(height: 10),
                        const Text(
                          'Personalisasi Perlindungan\nDarurat',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Penentuan profil disabilitas, sensor SOS &\nkontak darurat untuk ketepatan bantuan.',
                          style: TextStyle(fontSize: 13.5, color: mutedText, height: 1.4),
                        ),
                        const SizedBox(height: 22),
                        _buildSectionHeader(CupertinoIcons.person_crop_circle_badge_checkmark, 'Pilih Peran'),
                        const SizedBox(height: 12),
                        _buildRoleSelection(),
                        const SizedBox(height: 22),
                        _buildSectionHeader(CupertinoIcons.person, 'Informasi Pribadi'),
                        const SizedBox(height: 12),
                        _buildPersonalInfoCard(),
                        if (_selectedRole == _RoleType.pengguna) ...[
                          const SizedBox(height: 22),
                          _buildSectionHeader(CupertinoIcons.person_2, 'Kebutuhan Utama'),
                          const SizedBox(height: 12),
                          _buildNeedGrid(),
                          const SizedBox(height: 22),
                          _buildSensorCard(),
                        ],
                        const Spacer(),
                        const SizedBox(height: 22),
                        _buildSubmitButton(),
                        const SizedBox(height: 12),
                        _buildLogoutButton(),
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
        Icon(CupertinoIcons.checkmark_seal_fill, size: 16, color: accentTeal),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(CupertinoIcons.checkmark_shield, size: 15, color: accentTeal),
            SizedBox(width: 6),
            Text(
              'Langkah 2 dari 2: Personalisasi Darurat',
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
            tween: Tween<double>(begin: 0.5, end: 1.0),
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

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1A1A2E)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text(
            'Nama Lengkap',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: fieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Contoh: Budi Santoso',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFFB0B4C4)),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                prefixIcon: Icon(CupertinoIcons.person, color: Color(0xFF8A8FA3)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nomor Telepon Pribadi',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: fieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _userPhoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Contoh: 081234567890',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFFB0B4C4)),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                prefixIcon: Icon(CupertinoIcons.phone, color: Color(0xFF8A8FA3)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Alamat Lengkap',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: fieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _addressController,
              maxLines: 3,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Masukkan alamat tempat tinggal...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFFB0B4C4)),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          if (_selectedRole == _RoleType.relawan) ...[
            const SizedBox(height: 16),
            const Text(
              'Pekerjaan',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: fieldFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _jobController,
                keyboardType: TextInputType.text,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Contoh: Mahasiswa, Pegawai Swasta',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFFB0B4C4)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  prefixIcon: Icon(CupertinoIcons.briefcase, color: Color(0xFF8A8FA3)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Alasan Menjadi Relawan',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: fieldFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _reasonController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Berikan alasan singkat Anda...',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFFB0B4C4)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Row(
      children: [
        Expanded(
          child: _buildRoleCard(
            type: _RoleType.pengguna,
            icon: CupertinoIcons.person,
            label: 'Pengguna',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRoleCard(
            type: _RoleType.relawan,
            icon: CupertinoIcons.person_2,
            label: 'Relawan',
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required _RoleType type,
    required IconData icon,
    required String label,
  }) {
    final bool selected = _selectedRole == type;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedRole = type),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? primaryDark : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? primaryDark : Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: selected ? Colors.white : const Color(0xFF1A1A2E),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeedGrid() {
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNeedCard(
                  type: _NeedType.tunarungu,
                  icon: Icons.hearing_disabled_outlined,
                  label: 'Tunarungu',
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNeedCard(
                  type: _NeedType.umum,
                  icon: CupertinoIcons.person,
                  label: 'Umum',
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
  }) {
    final bool selected = _selectedNeed == type;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedNeed = type),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? primaryDark : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? primaryDark : Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 26,
                      color: selected ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    if (selected) ...[
                      const Spacer(),
                      const CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.white,
                        child: Icon(CupertinoIcons.checkmark_alt, size: 12, color: primaryDark),
                      ),
                    ] else ...[
                      const Spacer(),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFCBD0DE)),
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
                      color: selected ? Colors.white : const Color(0xFF1A1A2E),
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

  Widget _buildSensorCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(CupertinoIcons.slider_horizontal_3, 'Sensor & Aksesibilitas'),
        const SizedBox(height: 16),
        _buildSensorToggleRow(
          icon: CupertinoIcons.speaker_2,
          label: 'Panduan Suara Otomatis',
          value: _voiceGuidanceEnabled,
          onChanged: (v) => setState(() => _voiceGuidanceEnabled = v),
        ),
        const SizedBox(height: 16),
        _buildSensorToggleRow(
          icon: CupertinoIcons.waveform_path,
          label: 'Getaran Haptik Penuh',
          value: _hapticVibrationEnabled,
          onChanged: (v) => setState(() => _hapticVibrationEnabled = v),
        ),
        const SizedBox(height: 16),
        _buildSensorToggleRow(
          icon: CupertinoIcons.speaker_2,
          label: 'TalkBack / Pembaca Layar',
          value: _talkbackEnabled,
          onChanged: (v) => setState(() => _talkbackEnabled = v),
        ),
        const SizedBox(height: 16),
        _buildSensorToggleRow(
          icon: CupertinoIcons.textformat,
          label: 'Teks Besar / High Contrast',
          value: _largeTextEnabled,
          onChanged: (v) => setState(() => _largeTextEnabled = v),
        ),
      ],
    );
  }

  Widget _buildSensorToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFDDF3EA),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: accentTeal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: primaryDark,
        ),
      ],
    );
  }

  Future<void> _submitProfile() async {
    final dio = get_it.GetIt.instance<Dio>();
    final prefs = get_it.GetIt.instance<SharedPreferences>();
    final token = prefs.getString('auth_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesi tidak ditemukan, silakan login ulang.')));
      return;
    }

    if (_nameController.text.isEmpty || _addressController.text.trim().isEmpty || _userPhoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama, Nomor Telepon & Alamat wajib diisi!')));
      return;
    }

    if (_selectedRole == _RoleType.relawan) {
      if (_jobController.text.isEmpty || _reasonController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pekerjaan dan Alasan wajib diisi untuk Relawan!')));
        return;
      }
    }

    String kategori = 'umum';
    if (_selectedNeed == _NeedType.tunanetra) kategori = 'tunanetra';
    if (_selectedNeed == _NeedType.tunarungu) kategori = 'tunarungu';
    if (_selectedNeed == _NeedType.tunawicara) kategori = 'tunawicara';

    try {
      // Menampilkan Loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final Map<String, dynamic> payload = {
        'name': _nameController.text,
        'alamat': _addressController.text.trim(),
        'no_telp': _userPhoneController.text,
        'role': _selectedRole == _RoleType.relawan ? 'relawan' : 'pengguna',
        'status_ketersediaan': 'aktif',
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

      final response = await dio.post(
        ApiConstants.completeProfile,
        data: payload,
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
        await prefs.setBool('is_profile_complete', true);
        await prefs.setString('user_role', _selectedRole == _RoleType.relawan ? 'relawan' : 'pengguna');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil disimpan!')));
        if (_selectedRole == _RoleType.relawan) {
          context.go(AppRoutes.homeVolunteer);
        } else {
          context.go(AppRoutes.dashboard);
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan profil: ${response.data}')));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Tutup Loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
    }
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _submitProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
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
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: () async {
          final prefs = get_it.GetIt.instance<SharedPreferences>();
          final token = prefs.getString('auth_token');
          // Revoke token di server
          try {
            final dio = get_it.GetIt.instance<Dio>();
            await dio.post(
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
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A1A2E),
          side: const BorderSide(color: Color(0xFFE1E4EE)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'Batalkan & Kembali',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}







