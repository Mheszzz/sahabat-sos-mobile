import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import '../data/datasources/emergency_contact_remote_data_source.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteContact(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kontak'),
        content: const Text('Apakah Anda yakin ingin menghapus kontak ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showContactForm({Map<String, dynamic>? contact}) async {
    final isEdit = contact != null;
    final nameController = TextEditingController(text: contact?['nama']);
    final phoneController = TextEditingController(text: contact?['no_telp']);
    String tipe = contact?['tipe'] ?? 'sekunder';
    bool terimaNotif = true;
    if (isEdit && contact['terima_notif'] != null) {
      terimaNotif = contact['terima_notif'] == 1 || contact['terima_notif'] == true;
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.5)),
            ),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24,
                    left: 20, right: 20, top: 24,
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
                        Text(isEdit ? 'Edit Kontak Darurat' : 'Tambah Kontak Darurat', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF005650))),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Nama Kontak',
                            prefixIcon: const Icon(CupertinoIcons.person_fill, color: Color(0xFF005650)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          validator: (v) => v!.isEmpty ? 'Nama tidak boleh kosong' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            hintText: 'Nomor Telepon',
                            prefixIcon: const Icon(CupertinoIcons.phone_fill, color: Color(0xFF005650)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v!.isEmpty ? 'Nomor telepon tidak boleh kosong' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: tipe,
                          decoration: InputDecoration(
                            hintText: 'Tipe Kontak',
                            prefixIcon: const Icon(CupertinoIcons.tag_fill, color: Color(0xFF005650)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'utama', child: Text('Utama')),
                            DropdownMenuItem(value: 'sekunder', child: Text('Sekunder')),
                          ],
                          onChanged: (v) => setModalState(() => tipe = v!),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SwitchListTile(
                            title: const Text('Terima Notifikasi SOS', style: TextStyle(fontWeight: FontWeight.w500)),
                            secondary: const Icon(CupertinoIcons.bell_fill, color: Color(0xFF005650)),
                            value: terimaNotif,
                            activeThumbColor: const Color(0xFF005650),
                            activeTrackColor: const Color(0xFF005650).withValues(alpha: 0.3),
                            onChanged: (v) => setModalState(() => terimaNotif = v),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF005650),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              Navigator.pop(ctx);
                              setState(() => _isLoading = true);
                              try {
                                final data = {
                                  'nama': nameController.text,
                                  'no_telp': phoneController.text,
                                  'tipe': tipe,
                                  'terima_notif': terimaNotif,
                                };
                                if (isEdit) {
                                  await _dataSource.updateContact(contact['id'], data);
                                } else {
                                  await _dataSource.addContact(data);
                                }
                                _fetchContacts();
                              } catch (e) {
                                setState(() => _isLoading = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            },
                            child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 32),
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
    const primaryColor = Color(0xFF005650);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Kontak Darurat',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

            // Tambah Kontak Darurat Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showContactForm,
                icon: const Icon(CupertinoIcons.person_add, color: Colors.white),
                label: const Text(
                  'Tambah Kontak Darurat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),


            // Daftar Kontak Terdaftar Header
            Row(
              children: [
                const Text(
                  'Daftar Kontak Terdaftar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isLoading ? '...' : '${_contacts.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cards
            if (_isLoading)
               const Center(child: Padding(
                 padding: EdgeInsets.all(20.0),
                 child: CircularProgressIndicator(),
               ))
            else if (_contacts.isEmpty)
               const Center(child: Padding(
                 padding: EdgeInsets.all(30.0),
                 child: Text('Belum ada kontak darurat yang terdaftar.', style: TextStyle(color: Colors.grey)),
               ))
            else
               ..._contacts.map((contact) {
                 final isPrimary = contact['tipe'] == 'utama';
                 final bool terimaNotif = contact['terima_notif'] == 1 || contact['terima_notif'] == true;
                 
                 return _buildContactCard(
                   id: contact['id'],
                   name: contact['nama'] ?? '-',
                   avatarWidget: Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(
                       color: isPrimary ? primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                       shape: BoxShape.circle,
                     ),
                     child: Icon(
                       CupertinoIcons.person_fill,
                       color: isPrimary ? primaryColor : Colors.grey[600],
                       size: 24,
                     ),
                   ),
                   badgeText: isPrimary ? 'Kontak Utama' : 'Kontak Sekunder',
                   badgeColor: isPrimary ? const Color(0xFFFFF4D2) : const Color(0xFFE8F1F0),
                   badgeTextColor: isPrimary ? const Color(0xFFB58500) : primaryColor,
                   badgeDotColor: isPrimary ? const Color(0xFFF4B400) : primaryColor,
                   relationIcon: CupertinoIcons.person_2,
                   relationText: 'Kerabat',
                   phone: contact['no_telp'] ?? '-',
                   accessIcon: terimaNotif ? Icons.notifications_active : Icons.notifications_off,
                   accessText: terimaNotif ? 'Akses: Menerima Notifikasi' : 'Notifikasi Dinonaktifkan',
                   isPrimary: isPrimary,
                   primaryColor: primaryColor,
                   terimaNotif: terimaNotif,
                   onEdit: () async {
                     setState(() => _isLoading = true);
                     try {
                       final latestContact = await _dataSource.getContactById(contact['id']);
                       setState(() => _isLoading = false);
                       _showContactForm(contact: latestContact);
                     } catch (e) {
                       setState(() => _isLoading = false);
                       if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mengambil dari cache. (Error: $e)')));
                          _showContactForm(contact: contact);
                       }
                     }
                   },
                 );
               }),
               
            const SizedBox(height: 8),
            // Footer Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.lock_shield,
                    color: Color(0xFF8B5E34),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Data kontak darurat disimpan secara terenkripsi lokal dan hanya diakses oleh protokol keselamatan saat sinyal SOS dipicu.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
    required Widget avatarWidget,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required Color badgeDotColor,
    required IconData relationIcon,
    required String relationText,
    required String phone,
    String? accessText,
    IconData? accessIcon,
    required bool isPrimary,
    required Color primaryColor,
    bool isPosko = false,
    bool terimaNotif = true,
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            if (isPrimary)
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4B400),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        avatarWidget,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: badgeDotColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      badgeText,
                                      style: TextStyle(
                                        color: badgeTextColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [

                                  Icon(
                                    CupertinoIcons.phone_fill,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (accessText != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(accessIcon, size: 16, color: primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                accessText,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    // Action Buttons
                    Row(
                      children: [
                        if (isPosko)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(
                                CupertinoIcons.phone_fill,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Panggil Posko',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _deleteContact(id);
                              },
                              icon: const Icon(
                                CupertinoIcons.trash,
                                color: Colors.red,
                                size: 18,
                              ),
                              label: const Text(
                                'Hapus',
                                style: TextStyle(color: Colors.red),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.red[50],
                                side: BorderSide(color: Colors.red[100]!),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onEdit,
                              icon: const Icon(
                                CupertinoIcons.pencil,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Edit',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
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
}
