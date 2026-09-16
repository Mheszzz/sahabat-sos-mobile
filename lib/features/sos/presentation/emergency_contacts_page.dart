import 'package:flutter/material.dart';

class EmergencyContactsPage extends StatelessWidget {
  const EmergencyContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF005650);
    const bgColor = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Kontak Darurat',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Protokol Siaga Cepat
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: primaryColor,
                    child: Icon(Icons.radar, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Protokol Siaga Cepat',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kontak berikut akan menerima notifikasi instan dan tautan lokasi langsung saat tombol SOS diaktifkan.',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tambah Kontak Darurat Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
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

            // Kirim Lokasi Real-Time
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kirim Lokasi Real-Time',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Kirim otomatis tautan GPS saat...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: true,
                    onChanged: (val) {},
                    activeColor: primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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
                  child: const Text(
                    '4',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Siap Terhubung',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cards
            _buildContactCard(
              name: 'Siti Rahmawati',
              avatarWidget: const CircleAvatar(
                backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/150?img=5',
                ), // placeholder
              ),
              badgeText: 'Responden Utama / Keluarga',
              badgeColor: const Color(0xFFFFF4D2),
              badgeTextColor: const Color(0xFFB58500),
              badgeDotColor: const Color(0xFFF4B400),
              relationIcon: Icons.favorite_border,
              relationText: 'Istri',
              phone: '0812-9876-5432',
              accessIcon: Icons.bolt,
              accessText: 'Akses: Menerima SMS & Telepon SOS otomatis',
              isPrimary: true,
              primaryColor: primaryColor,
            ),

            _buildContactCard(
              name: 'dr. Bambang Irawan',
              avatarWidget: const CircleAvatar(
                backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/150?img=11',
                ), // placeholder
              ),
              badgeText: 'Dokter Pribadi / Medis',
              badgeColor: const Color(0xFFE8F1F0),
              badgeTextColor: primaryColor,
              badgeDotColor: primaryColor,
              relationIcon: Icons.medical_services_outlined,
              relationText: 'Dokter Pendamping',
              phone: '0811-2233-4455',
              accessIcon: Icons.health_and_safety_outlined,
              accessText: 'Akses: Menerima Notifikasi Medis Langsung',
              isPrimary: false,
              primaryColor: primaryColor,
            ),

            _buildContactCard(
              name: 'Posko Relawan Sahabat SOS',
              avatarWidget: const CircleAvatar(
                backgroundColor: Color(0xFFF0EBE1),
                child: Icon(Icons.emergency_outlined, color: Color(0xFF8B7043)),
              ),
              badgeText: 'Petugas Siaga 24 Jam',
              badgeColor: Colors.grey[200]!,
              badgeTextColor: Colors.grey[700]!,
              badgeDotColor: Colors.grey[600]!,
              relationIcon: Icons.support_agent,
              relationText: 'Layanan Publik',
              phone: '(022)7654321',
              accessIcon: Icons.verified_user_outlined,
              accessText: 'Akses: Terkoneksi otomatis & Dispatch Cepat',
              isPrimary: false,
              primaryColor: primaryColor,
              isPosko: true,
            ),

            _buildContactCard(
              name: 'Rian Hidayat',
              avatarWidget: const CircleAvatar(
                backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/150?img=12',
                ), // placeholder
              ),
              badgeText: 'Saudara Kandung',
              badgeColor: const Color(0xFFF5EFE9),
              badgeTextColor: const Color(0xFF8B5E34),
              badgeDotColor: const Color(0xFF8B5E34),
              relationIcon: Icons.people_outline,
              relationText: 'Adik',
              phone: '0857-1234-5678',
              isPrimary: false,
              primaryColor: primaryColor,
            ),

            const SizedBox(height: 8),
            // Footer Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.privacy_tip_outlined,
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
    );
  }

  Widget _buildContactCard({
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                padding: const EdgeInsets.all(16.0),
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
                              const SizedBox(height: 8),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Icon(
                                    relationIcon,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    relationText,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[400],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.phone,
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
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
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
                                Icons.phone,
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
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.phone,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Panggil',
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: Icon(
                                Icons.edit,
                                color: primaryColor,
                                size: 18,
                              ),
                              label: Text(
                                'Edit',
                                style: TextStyle(color: primaryColor),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.grey[100],
                                side: BorderSide(color: Colors.grey[200]!),
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
    );
  }
}
