import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/routing/routes.dart';
import '../data/datasources/emergency_contact_remote_data_source.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color primaryLightTeal = Color(0xFFE0F2F1);
  static const Color alertRed = Color(0xFFDC2626);

  final _dataSource = sl<EmergencyContactRemoteDataSource>();
  List<dynamic> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    try {
      final data = await _dataSource.getContacts();
      if (mounted) {
        setState(() {
          _contacts = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: alertRed,
          ),
        );
      }
    }
  }

  Future<void> _navigateToAddOrEdit({Map<String, dynamic>? contact}) async {
    final result = await context.push<bool>(
      AppRoutes.addEmergencyContact,
      extra: contact,
    );

    if (result == true) {
      await _fetchContacts();
    }
  }

  Future<void> _deleteContact(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(CupertinoIcons.trash, color: alertRed, size: 22),
            SizedBox(width: 8),
            Text(
              'Hapus Kontak',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "$name" dari daftar kontak darurat?',
          style: const TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: alertRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dataSource.deleteContact(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kontak darurat berhasil dihapus'),
            backgroundColor: primaryTeal,
          ),
        );
        await _fetchContacts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: alertRed,
          ),
        );
      }
    }
  }

  Future<void> _toggleNotif(int id, bool terimaNotif) async {
    try {
      setState(() {
        final idx = _contacts.indexWhere((c) => c['id'] == id);
        if (idx != -1) {
          _contacts[idx]['terima_notif'] = terimaNotif ? 1 : 0;
        }
      });
      await _dataSource.toggleNotif(id, terimaNotif);
    } catch (e) {
      await _fetchContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui pengaturan notifikasi: $e'),
            backgroundColor: alertRed,
          ),
        );
      }
    }
  }

  Future<void> _callNumber(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat memanggil nomor $phone'),
          backgroundColor: alertRed,
        ),
      );
    }
  }

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
    Border? border,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: border ?? Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildContactCard({
    required int id,
    required String name,
    required String phone,
    required String? notes,
    required bool isPrimary,
    required bool terimaNotif,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onCall,
    required ValueChanged<bool> onToggleNotif,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Avatar, Info, Priority Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isPrimary
                      ? const Color(0xFFFEF3C7)
                      : primaryLightTeal,
                  child: Icon(
                    isPrimary
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.person_fill,
                    color: isPrimary
                        ? const Color(0xFFD97706)
                        : primaryTeal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.phone,
                            size: 13,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          notes,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6B7280),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Priority Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPrimary
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPrimary
                            ? CupertinoIcons.star_fill
                            : CupertinoIcons.person_2_fill,
                        size: 11,
                        color: isPrimary
                            ? const Color(0xFFB45309)
                            : const Color(0xFF4B5563),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPrimary ? 'Utama' : 'Sekunder',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isPrimary
                              ? const Color(0xFFB45309)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF3F4F6)),
            ),

            // Notification Status & Toggle Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: terimaNotif
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFF9FAFB),
                border: Border.all(
                  color: terimaNotif
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFE5E7EB),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    terimaNotif
                        ? CupertinoIcons.bell_fill
                        : CupertinoIcons.bell_slash,
                    size: 15,
                    color: terimaNotif
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      terimaNotif
                          ? 'Notifikasi SOS Aktif'
                          : 'Notifikasi SOS Nonaktif',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: terimaNotif
                            ? const Color(0xFF15803D)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.75,
                    child: CupertinoSwitch(
                      value: terimaNotif,
                      activeTrackColor: primaryTeal,
                      onChanged: onToggleNotif,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action Buttons: Panggil, Edit, Hapus
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(
                      CupertinoIcons.phone_fill,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Panggil',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(
                      CupertinoIcons.pencil,
                      size: 14,
                      color: primaryTeal,
                    ),
                    label: const Text(
                      'Edit',
                      style: TextStyle(
                        color: primaryTeal,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryLightTeal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Icon(
                      CupertinoIcons.trash,
                      color: alertRed,
                      size: 17,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: primaryTeal),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: primaryTeal),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 24, height: 24),
            const SizedBox(width: 8),
            const Text(
              'Kontak Darurat',
              style: TextStyle(
                color: primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchContacts,
          color: primaryTeal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tombol Tambah Kontak Darurat Prominen
                ElevatedButton.icon(
                  onPressed: () => _navigateToAddOrEdit(),
                  icon: const Icon(
                    CupertinoIcons.person_add_solid,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Tambah Kontak Darurat',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header List & Counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daftar Kontak Terdaftar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: primaryLightTeal,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFB2DFDB)),
                      ),
                      child: Text(
                        '${_contacts.length} kontak',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: primaryTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Content Area
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48.0),
                      child: CupertinoActivityIndicator(radius: 16),
                    ),
                  )
                else if (_contacts.isEmpty)
                  _buildCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: 36,
                      horizontal: 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.person_2_alt,
                            size: 44,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Belum Ada Kontak Darurat',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tambahkan keluarga atau orang terdekat agar sistem otomatis menghubungi mereka saat situasi darurat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _navigateToAddOrEdit(),
                          icon: const Icon(
                            CupertinoIcons.add,
                            size: 16,
                            color: primaryTeal,
                          ),
                          label: const Text(
                            'Tambah Sekarang',
                            style: TextStyle(
                              color: primaryTeal,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: primaryTeal),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._contacts.map((contact) {
                    final isPrimary = contact['tipe'] == 'utama';
                    final bool terimaNotif =
                        contact['terima_notif'] == 1 ||
                        contact['terima_notif'] == true;

                    return _buildContactCard(
                      id: contact['id'],
                      name: contact['nama'] ?? '-',
                      phone: contact['no_telp'] ?? '-',
                      notes: contact['pesan']?.toString(),
                      isPrimary: isPrimary,
                      terimaNotif: terimaNotif,
                      onEdit: () =>
                          _navigateToAddOrEdit(contact: contact),
                      onDelete: () => _deleteContact(
                        contact['id'],
                        contact['nama'] ?? 'Kontak',
                      ),
                      onCall: () =>
                          _callNumber(contact['no_telp'] ?? ''),
                      onToggleNotif: (val) =>
                          _toggleNotif(contact['id'], val),
                    );
                  }),

                const SizedBox(height: 8),

                // Footer Keamanan & Enkripsi
                _buildCard(
                  padding: const EdgeInsets.all(14),
                  child: const Row(
                    children: [
                      Icon(
                        CupertinoIcons.lock_shield_fill,
                        color: primaryTeal,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Data kontak darurat disimpan secara terenkripsi dan hanya dihubungi ketika pemicu SOS diaktifkan.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6B7280),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
