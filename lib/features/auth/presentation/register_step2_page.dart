import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';

enum _NeedType { disabilitasNetra, tunarunguWicara, fisikMotorik, umumLansia }

class RegisterStep2Page extends StatefulWidget {
  const RegisterStep2Page({super.key});

  @override
  State<RegisterStep2Page> createState() => _RegisterStep2PageState();
}

class _RegisterStep2PageState extends State<RegisterStep2Page> {
  static const Color primaryDark = Color(0xFF0D3B2E);
  static const Color accentTeal = Color(0xFF0E9F6E);
  static const Color bgColor = Color(0xFFF3F5FB);
  static const Color fieldFill = Color(0xFFEFF1F8);
  static const Color mutedText = Color(0xFF6B7080);

  _NeedType _selectedNeed = _NeedType.disabilitasNetra;

  final Set<String> _selectedMobilityAids = {};

  final TextEditingController _medicalNotesController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();

  bool _voiceGuidanceEnabled = true;
  bool _hapticVibrationEnabled = true;
  bool _sirenStroboEnabled = true;

  @override
  void dispose() {
    _medicalNotesController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
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
                        _buildSectionHeader(Icons.accessibility_new_rounded, 'Kebutuhan Utama'),
                        const SizedBox(height: 12),
                        _buildNeedGrid(),
                        const SizedBox(height: 22),
                        _buildMedicalNeedsCard(),
                        const SizedBox(height: 22),
                        _buildEmergencyContactCard(),
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

  Widget _buildNeedGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildNeedCard(
                type: _NeedType.disabilitasNetra,
                icon: Icons.visibility_off_outlined,
                label: 'Disabilitas Netra',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNeedCard(
                type: _NeedType.tunarunguWicara,
                icon: Icons.hearing_disabled_outlined,
                label: 'Tunarungu /\nWicara',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildNeedCard(
                type: _NeedType.fisikMotorik,
                icon: Icons.accessible_rounded,
                label: 'Fisik / Motorik',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNeedCard(
                type: _NeedType.umumLansia,
                icon: Icons.groups_outlined,
                label: 'Umum / Lansia',
              ),
            ),
          ],
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

  Widget _buildMedicalNeedsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.medical_services_outlined, 'Kebutuhan Khusus & Medis'),
        const SizedBox(height: 14),
        const Text(
          'Alat Bantu Mobilitas / Penginderaan:',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildChip('Tongkat Pemandu', checkStyle: true),
            _buildChip('Kursi Roda'),
            _buildChip('Alat Dengar'),
            _buildChip('Pemandu Hewan'),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Catatan Medis Penting',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            Text(
              '(Disampaikan ke\nParamedis)',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: mutedText, height: 1.2),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: fieldFill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _medicalNotesController,
            maxLines: 3,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A1A2E), height: 1.4),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'cth. Alergi penisilin, riwayat asma...',
              hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFFB0B4C4)),
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, {bool checkStyle = false}) {
    final bool selected = _selectedMobilityAids.contains(label);
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () {
        setState(() {
          if (selected) {
            _selectedMobilityAids.remove(label);
          } else {
            _selectedMobilityAids.add(label);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primaryDark : fieldFill,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check : Icons.add,
              size: 15,
              color: selected ? Colors.white : const Color(0xFF6B7080),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.badge_outlined, 'Kontak Darurat Utama'),
        const SizedBox(height: 16),
        _buildLabelRequired('Nama Kontak / Hubungan Keluarga'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: fieldFill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _contactNameController,
            style: const TextStyle(fontSize: 14.5, color: Color(0xFF1A1A2E)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Masukkan nama kontak',
              hintStyle: TextStyle(fontSize: 14, color: Color(0xFFB0B4C4)),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              suffixIcon: Icon(Icons.badge_outlined, color: Color(0xFF8A8FA3)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabelRequired('Nomor WhatsApp / Panggilan Aktif'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: fieldFill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 14.5, color: Color(0xFF1A1A2E)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Masukkan nomor WhatsApp',
              hintStyle: TextStyle(fontSize: 14, color: Color(0xFFB0B4C4)),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              prefixIcon: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(
                    '+62',
                    style: TextStyle(fontSize: 14.5, color: Color(0xFF1A1A2E)),
                  ),
                ),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: Icon(Icons.smartphone_outlined, color: Color(0xFF8A8FA3)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelRequired(String label) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E),
        ),
        children: [
          TextSpan(text: label),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Color(0xFFE0483F)),
          ),
        ],
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
          icon: Icons.flashlight_on_outlined,
          label: 'Sirene & Strobo Flash',
          value: _sirenStroboEnabled,
          onChanged: (v) => setState(() => _sirenStroboEnabled = v),
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: () {},
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
