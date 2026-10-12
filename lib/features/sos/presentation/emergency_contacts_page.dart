import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/datasources/emergency_contact_remote_data_source.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  static const Color bgColor = Color(0xFFF5F6F8);
  static const Color primaryTeal = Color(0xFF006D77);
  static const Color sosRed = Color(0xFFC62828);

  final _dataSource = GetIt.instance<EmergencyContactRemoteDataSource>();
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
      setState(() {
        _contacts = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteContact(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Kontak',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin menghapus kontak darurat ini dari daftar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: sosRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dataSource.deleteContact(id);
      _fetchContacts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      _fetchContacts();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengubah notifikasi: $e')));
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
        SnackBar(content: Text('Tidak dapat memanggil nomor $phone')),
      );
    }
  }

  Future<void> _showContactForm({Map<String, dynamic>? contact}) async {
    final isEdit = contact != null;
    final nameController = TextEditingController(text: contact?['nama']);
    final phoneController = TextEditingController(text: contact?['no_telp']);
    String tipe = contact?['tipe'] ?? 'sekunder';
    bool terimaNotif = true;
    if (isEdit && contact['terima_notif'] != null) {
      terimaNotif =
          contact['terima_notif'] == 1 || contact['terima_notif'] == true;
    }

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.of(ctx).viewInsets.bottom +
                        MediaQuery.of(ctx).padding.bottom +
                        24,
                    left: 20,
                    right: 20,
                    top: 24,
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          isEdit
                              ? 'Edit Kontak Darurat'
                              : 'Tambah Kontak Darurat',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryTeal,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Nama Kontak',
                            hintText: 'Contoh: Ibu, Ayah, Pasangan',
                            prefixIcon: const Icon(
                              CupertinoIcons.person,
                              color: primaryTeal,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F6F8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Nama tidak boleh kosong' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            labelText: 'Nomor Telepon / WhatsApp',
                            hintText: 'Contoh: 081234567890',
                            prefixIcon: const Icon(
                              CupertinoIcons.phone,
                              color: primaryTeal,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F6F8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Nomor telepon tidak boleh kosong'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: tipe,
                          decoration: InputDecoration(
                            labelText: 'Prioritas Kontak',
                            prefixIcon: const Icon(
                              CupertinoIcons.tag,
                              color: primaryTeal,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F6F8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'utama',
                              child: Text('Kontak Utama (Prioritas Tinggi)'),
                            ),
                            DropdownMenuItem(
                              value: 'sekunder',
                              child: Text('Kontak Sekunder (Cadangan)'),
                            ),
                          ],
                          onChanged: (v) => setModalState(() => tipe = v!),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6F8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: SwitchListTile(
                            title: const Text(
                              'Terima Notifikasi SOS',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Kirim pesan darurat saat sinyal SOS aktif',
                              style: TextStyle(fontSize: 12),
                            ),
                            secondary: const Icon(
                              CupertinoIcons.bell,
                              color: primaryTeal,
                            ),
                            value: terimaNotif,
                            activeThumbColor: Colors.white,
                            activeTrackColor: primaryTeal,
                            onChanged: (v) =>
                                setModalState(() => terimaNotif = v),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTeal,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              Navigator.pop(ctx);
                              setState(() => _isLoading = true);
                              try {
                                final data = {
                                  'nama': nameController.text.trim(),
                                  'no_telp': phoneController.text.trim(),
                                  'tipe': tipe,
                                  'terima_notif': terimaNotif,
                                };
                                if (isEdit) {
                                  await _dataSource.updateContact(
                                    contact['id'],
                                    data,
                                  );
                                } else {
                                  await _dataSource.addContact(data);
                                }
                                _fetchContacts();
                              } catch (e) {
                                setState(() => _isLoading = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            child: Text(
                              isEdit ? 'Simpan Perubahan' : 'Tambahkan Kontak',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            CupertinoIcons.chevron_back,
            color: primaryTeal,
          ),
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: false,
        title: const Text(
          'Kontak Darurat',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchContacts,
          color: primaryTeal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Deskripsi singkat
                Text(
                  'Orang terdekat yang otomatis dihubungi saat situasi darurat.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),

                // Tombol Tambah Kontak Darurat
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showContactForm(),
                    icon: const Icon(
                      CupertinoIcons.person_add,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Tambah Kontak Darurat',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
                ),
                const SizedBox(height: 20),

                // Daftar Kontak Terdaftar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daftar Kontak Terdaftar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: primaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_contacts.length} kontak',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: CupertinoActivityIndicator(radius: 16),
                    ),
                  )
                else if (_contacts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36.0),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.person_2,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Belum ada kontak darurat terdaftar',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tekan "Tambah Kontak Darurat" di atas untuk menambahkan',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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
                      isPrimary: isPrimary,
                      terimaNotif: terimaNotif,
                      onEdit: () async {
                        setState(() => _isLoading = true);
                        try {
                          final latest = await _dataSource
                              .getContactById(contact['id']);
                          setState(() => _isLoading = false);
                          _showContactForm(contact: latest);
                        } catch (_) {
                          setState(() => _isLoading = false);
                          _showContactForm(contact: contact);
                        }
                      },
                      onDelete: () => _deleteContact(contact['id']),
                      onCall: () => _callNumber(contact['no_telp'] ?? ''),
                      onToggleNotif: (val) =>
                          _toggleNotif(contact['id'], val),
                    );
                  }),

                const SizedBox(height: 12),

                // Footer Info Keamanan
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          CupertinoIcons.lock,
                          color: primaryTeal,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Data kontak darurat disimpan secara terenkripsi dan hanya diakses saat sinyal SOS dipicu.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required int id,
    required String name,
    required String phone,
    required bool isPrimary,
    required bool terimaNotif,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onCall,
    required ValueChanged<bool> onToggleNotif,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Avatar, Name, Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isPrimary
                    ? Colors.orange.shade50
                    : primaryTeal.withValues(alpha: 0.1),
                child: Icon(
                  isPrimary
                      ? CupertinoIcons.person_crop_circle_badge_checkmark
                      : CupertinoIcons.person,
                  color: isPrimary ? const Color(0xFFEF6C00) : primaryTeal,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.phone,
                          size: 13,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Badge Utama / Sekunder (Mirip badge status volunteer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPrimary
                        ? const Color(0xFFFFCC80)
                        : const Color(0xFFA5D6A7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPrimary
                          ? CupertinoIcons.checkmark_seal
                          : CupertinoIcons.checkmark_alt_circle,
                      size: 11,
                      color: isPrimary
                          ? const Color(0xFFEF6C00)
                          : const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPrimary ? 'Utama' : 'Sekunder',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPrimary
                            ? const Color(0xFFEF6C00)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Notifikasi Status Chip & Quick Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: terimaNotif
                  ? const Color(0xFFF0FDF4)
                  : Colors.grey.shade100,
              border: Border.all(
                color: terimaNotif
                    ? const Color(0xFFBBF7D0)
                    : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  terimaNotif
                      ? CupertinoIcons.bell
                      : CupertinoIcons.bell_slash,
                  size: 14,
                  color: terimaNotif
                      ? const Color(0xFF16A34A)
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    terimaNotif
                        ? 'Notifikasi SOS Aktif'
                        : 'Notifikasi SOS Nonaktif',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: terimaNotif
                          ? const Color(0xFF15803D)
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.7,
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
                    CupertinoIcons.phone,
                    size: 14,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Panggil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0F2F1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(
                    CupertinoIcons.delete,
                    color: sosRed,
                    size: 16,
                  ),
                  tooltip: 'Hapus Kontak',
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
