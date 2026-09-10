import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart' as get_it;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../routing/routes.dart';

enum _NeedType { tunanetra, tunarungu, tunawicara, umum }

class RegisterStep2Page extends StatefulWidget {
  const RegisterStep2Page({super.key});

  @override
  State<RegisterStep2Page> createState() => _RegisterStep2PageState();
}

class _RegisterStep2PageState extends State<RegisterStep2Page> {
  static const Color primaryDark = Color(0xFF006D77);
  static const Color accentTeal = Color(0xFF0E9F6E);
  static const Color bgColor = Color(0xFFEFEFEF);
  static const Color fieldFill = Color(0xFFEFF1F8);
  static const Color mutedText = Color(0xFF6B7080);

  _NeedType _selectedNeed = _NeedType.umum;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _userPhoneController = TextEditingController();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
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
                        _buildSectionHeader(Icons.person_outline, 'Informasi Pribadi'),
                        const SizedBox(height: 12),
                        _buildPersonalInfoCard(),
                        const SizedBox(height: 22),
                        _buildSectionHeader(Icons.accessibility_new_rounded, 'Kebutuhan Utama'),
                        const SizedBox(height: 12),
                        _buildNeedGrid(),
                        const SizedBox(height: 22),
                        _buildSensorCard(),
                        const Spacer(),
                        const SizedBox(height: 22),
                        _buildSubmitButton(),
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
            Icon(Icons.verified_user_outlined, size: 15, color: accentTeal),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE6DF)),
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
                prefixIcon: Icon(Icons.person_outline, color: Color(0xFF8A8FA3)),
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
                prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF8A8FA3)),
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
        ],
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
                  icon: Icons.visibility_off_outlined,
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
                  icon: Icons.speaker_notes_off_outlined,
                  label: 'Tunawicara',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNeedCard(
                  type: _NeedType.umum,
                  icon: Icons.person_outline_rounded,
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _selectedNeed = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primaryDark : const Color(0xFFE1E4EE),
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
                    child: Icon(Icons.check, size: 12, color: primaryDark),
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
    );
  }

  Widget _buildSensorCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.tune_rounded, 'Sensor & Aksesibilitas'),
        const SizedBox(height: 16),
        _buildSensorToggleRow(
          icon: Icons.record_voice_over_outlined,
          label: 'Panduan Suara Otomatis',
          value: _voiceGuidanceEnabled,
          onChanged: (v) => setState(() => _voiceGuidanceEnabled = v),
        ),
        const SizedBox(height: 16),
        _buildSensorToggleRow(
          icon: Icons.vibration_rounded,
          label: 'Getaran Haptik Penuh',
          value: _hapticVibrationEnabled,
          onChanged: (v) => setState(() => _hapticVibrationEnabled = v),
        ),
        const SizedBox(height: 16),
        _buildSensorToggleRow(
          icon: Icons.hearing_rounded,
          label: 'TalkBack / Pembaca Layar',
          value: _talkbackEnabled,
          onChanged: (v) => setState(() => _talkbackEnabled = v),
        ),
        const SizedBox(height: 16),
        _buildSensorToggleRow(
          icon: Icons.text_increase_rounded,
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
          activeColor: Colors.white,
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

    if (_nameController.text.isEmpty || _addressController.text.isEmpty || _userPhoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama, Nomor Telepon & Alamat wajib diisi!')));
      return;
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

      final response = await dio.post(
        ApiConstants.completeProfile,
        data: {
          'name': _nameController.text,
          'alamat': _addressController.text,
          'no_telp': _userPhoneController.text,
          'kategori_user': kategori,
          'getaran': _hapticVibrationEnabled,
          'talkback': _talkbackEnabled,
          'panduan_suara': _voiceGuidanceEnabled,
          'text_besar': _largeTextEnabled,
          'status_ketersediaan': 'aktif',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (context.mounted) Navigator.pop(context); // Tutup Loading

      if (response.statusCode == 200 || response.statusCode == 201) {
        await prefs.setBool('is_profile_complete', true);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil disimpan!')));
        context.go(AppRoutes.dashboard);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan profil: ${response.data}')));
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Tutup Loading
      if (!context.mounted) return;
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
            Icon(Icons.verified_user_outlined, size: 18),
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
}
