import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import '../data/datasources/emergency_contact_remote_data_source.dart';

class AddEmergencyContactPage extends StatefulWidget {
  final Map<String, dynamic>? contact;

  const AddEmergencyContactPage({super.key, this.contact});

  @override
  State<AddEmergencyContactPage> createState() =>
      _AddEmergencyContactPageState();
}

class _AddEmergencyContactPageState extends State<AddEmergencyContactPage> {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color primaryLightTeal = Color(0xFFE0F2F1);

  final _dataSource = sl<EmergencyContactRemoteDataSource>();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _notesController;

  String _tipe = 'sekunder';
  bool _terimaNotif = true;
  bool _isLoading = false;

  bool get isEdit => widget.contact != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _nameController = TextEditingController(text: c?['nama'] ?? '');
    _phoneController = TextEditingController(text: c?['no_telp'] ?? '');
    _notesController = TextEditingController(text: c?['pesan'] ?? '');

    _tipe = (c?['tipe'] == 'utama') ? 'utama' : 'sekunder';
    if (c != null && c['terima_notif'] != null) {
      _terimaNotif = c['terima_notif'] == 1 || c['terima_notif'] == true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final payload = {
        'nama': _nameController.text.trim(),
        'no_telp': _phoneController.text.trim(),
        'pesan': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        'tipe': _tipe,
        'terima_notif': _terimaNotif,
      };

      if (isEdit) {
        await _dataSource.updateContact(widget.contact!['id'], payload);
      } else {
        await _dataSource.addContact(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Kontak darurat berhasil diperbarui'
                  : 'Kontak darurat berhasil ditambahkan',
            ),
            backgroundColor: primaryTeal,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
    Border? border,
    bool isHighContrast = false,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(16),
        border: border ?? AccessibleColors.cardBorder(isHighContrast),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isHighContrast ? 0.3 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

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
            isHighContrast ? Colors.black : const Color(0xFFF8FAFC);
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
        final fieldFill =
            isHighContrast ? const Color(0xFF1E2430) : const Color(0xFFF9FAFB);
        final fieldBorder =
            isHighContrast ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);

        final titleText =
            isEdit ? 'Edit Kontak Darurat' : 'Tambah Kontak Darurat';

        return Scaffold(
          backgroundColor: currentBg,
          appBar: AppBar(
            backgroundColor: currentBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleSpacing: 0,
            iconTheme: IconThemeData(color: tealColor),
            leading: IconButton(
              icon: Icon(CupertinoIcons.back, color: tealColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 24, height: 24),
                const SizedBox(width: 8),
                Text(
                  titleText,
                  style: TextStyle(
                    color: tealColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info Card Pengingat
                    _buildCard(
                      isHighContrast: isHighContrast,
                      color: isHighContrast
                          ? const Color(0xFF1E3A34)
                          : primaryLightTeal.withValues(alpha: 0.5),
                      border: Border.all(
                        color: isHighContrast
                            ? const Color(0xFF80CBC4)
                            : const Color(0xFFB2DFDB),
                        width: isHighContrast ? 1.5 : 1.0,
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            CupertinoIcons.info_circle_fill,
                            color: tealColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Kontak ini akan segera dihubungi dan menerima pesan darurat saat Anda memicu sinyal SOS.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isHighContrast
                                    ? const Color(0xFFE0F2F1)
                                    : const Color(0xFF004D40),
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Identitas Kontak
                    _buildCard(
                      isHighContrast: isHighContrast,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informasi Kontak',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color:
                                  AccessibleColors.textPrimary(isHighContrast),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Input Nama
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color:
                                  AccessibleColors.textPrimary(isHighContrast),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Nama Lengkap / Panggilan',
                              labelStyle: TextStyle(
                                color: AccessibleColors.textSecondary(
                                    isHighContrast),
                                fontSize: 13,
                              ),
                              hintText: 'Contoh: Ayah, Ibu, Pasangan',
                              hintStyle: TextStyle(
                                color: AccessibleColors.textSecondary(
                                    isHighContrast),
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                CupertinoIcons.person_fill,
                                color: tealColor,
                                size: 19,
                              ),
                              filled: true,
                              fillColor: fieldFill,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: fieldBorder,
                                  width: isHighContrast ? 1.5 : 1.0,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: tealColor,
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFDC2626)),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDC2626),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama kontak wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Input Nomor Telepon
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color:
                                  AccessibleColors.textPrimary(isHighContrast),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Nomor Telepon / WhatsApp',
                              labelStyle: TextStyle(
                                color: AccessibleColors.textSecondary(
                                    isHighContrast),
                                fontSize: 13,
                              ),
                              hintText: 'Contoh: 081234567890',
                              hintStyle: TextStyle(
                                color: AccessibleColors.textSecondary(
                                    isHighContrast),
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                CupertinoIcons.phone_fill,
                                color: tealColor,
                                size: 19,
                              ),
                              filled: true,
                              fillColor: fieldFill,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: fieldBorder,
                                  width: isHighContrast ? 1.5 : 1.0,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: tealColor,
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFDC2626)),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDC2626),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nomor telepon wajib diisi';
                              }
                              final digitsOnly =
                                  value.replaceAll(RegExp(r'[^0-9]'), '');
                              if (digitsOnly.length < 9) {
                                return 'Nomor telepon minimal 9 digit angka';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Input Hubungan / Catatan Pesan
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  AccessibleColors.textPrimary(isHighContrast),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Hubungan / Catatan (Opsional)',
                              labelStyle: TextStyle(
                                color: AccessibleColors.textSecondary(
                                    isHighContrast),
                                fontSize: 13,
                              ),
                              hintText:
                                  'Contoh: Saudara Kandung / Punya kunci cadangan rumah',
                              hintStyle: TextStyle(
                                color: AccessibleColors.textSecondary(
                                    isHighContrast),
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                CupertinoIcons.bubble_left_fill,
                                color: tealColor,
                                size: 19,
                              ),
                              filled: true,
                              fillColor: fieldFill,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: fieldBorder,
                                  width: isHighContrast ? 1.5 : 1.0,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: tealColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Prioritas Kontak
                    _buildCard(
                      isHighContrast: isHighContrast,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prioritas Kontak Darurat',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color:
                                  AccessibleColors.textPrimary(isHighContrast),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Kontak utama akan menjadi prioritas panggilan pertama saat situasi genting.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AccessibleColors.textSecondary(
                                  isHighContrast),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPriorityOption(
                                  label: 'Kontak Utama',
                                  subtitle: 'Prioritas tertinggi',
                                  value: 'utama',
                                  icon: CupertinoIcons.star_fill,
                                  activeColor: isHighContrast
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFD97706),
                                  isHighContrast: isHighContrast,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildPriorityOption(
                                  label: 'Kontak Sekunder',
                                  subtitle: 'Cadangan',
                                  value: 'sekunder',
                                  icon: CupertinoIcons.person_2_fill,
                                  activeColor: tealColor,
                                  isHighContrast: isHighContrast,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notifikasi Toggle Card
                    _buildCard(
                      isHighContrast: isHighContrast,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _terimaNotif
                                  ? (isHighContrast
                                      ? const Color(0xFF1E3A34)
                                      : primaryLightTeal)
                                  : (isHighContrast
                                      ? const Color(0xFF263238)
                                      : const Color(0xFFF3F4F6)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _terimaNotif
                                  ? CupertinoIcons.bell_fill
                                  : CupertinoIcons.bell_slash,
                              color: _terimaNotif
                                  ? tealColor
                                  : const Color(0xFF9CA3AF),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kirim Notifikasi SOS Otomatis',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AccessibleColors.textPrimary(
                                        isHighContrast),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Kirim SMS / pesan darurat saat tombol SOS ditekan',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AccessibleColors.textSecondary(
                                        isHighContrast),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: _terimaNotif,
                            activeTrackColor: tealColor,
                            inactiveTrackColor: isHighContrast
                                ? const Color(0xFF374151)
                                : null,
                            onChanged: (val) {
                              setState(() => _terimaNotif = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveContact,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isHighContrast
                            ? const Color(0xFF00897B)
                            : primaryTeal,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isHighContrast
                            ? const Color(0xFF004D40)
                            : primaryTeal.withValues(alpha: 0.6),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: isHighContrast
                              ? const BorderSide(
                                  color: Color(0xFF80CBC4),
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CupertinoActivityIndicator(
                                color: Colors.white,
                                radius: 10,
                              ),
                            )
                          : Text(
                              isEdit
                                  ? 'Simpan Perubahan'
                                  : 'Simpan Kontak Darurat',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriorityOption({
    required String label,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color activeColor,
    bool isHighContrast = false,
  }) {
    final isSelected = _tipe == value;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() => _tipe = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isHighContrast ? 0.25 : 0.08)
              : (isHighContrast
                  ? const Color(0xFF1E2430)
                  : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isHighContrast
                    ? const Color(0xFF4B5563)
                    : const Color(0xFFE5E7EB)),
            width: isSelected || isHighContrast ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? activeColor
                      : AccessibleColors.textSecondary(isHighContrast),
                ),
                if (isSelected)
                  Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: 18,
                    color: activeColor,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? activeColor
                    : AccessibleColors.textPrimary(isHighContrast),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: AccessibleColors.textSecondary(isHighContrast),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
