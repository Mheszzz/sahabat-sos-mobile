import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';

/// Menampilkan bottom sheet panduan SOP tindakan lapangan dan protokol komunikasi relawan.
void showVolunteerSopModal(BuildContext context) {
  AccessibilityService.instance.announce(
    'Membuka Panduan SOP dan Protokol Komunikasi Relawan',
  );
  AccessibilityService.instance.hapticMedium();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _VolunteerSopSheet(),
  );
}

class _VolunteerSopSheet extends StatefulWidget {
  const _VolunteerSopSheet();

  @override
  State<_VolunteerSopSheet> createState() => _VolunteerSopSheetState();
}

class _VolunteerSopSheetState extends State<_VolunteerSopSheet> {
  int _selectedTab = 0; // 0: SOP Tindakan, 1: Protokol Komunikasi, 2: Kontak Darurat

  static const Color _tealPrimary = Color(0xFF006D77);
  static const Color _tealAccent = Color(0xFF00897B);

  @override
  Widget build(BuildContext context) {
    final isHighContrast = context.isHighContrast;
    final isDarkMode = isHighContrast || Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isHighContrast
        ? const Color(0xFF121212)
        : (isDarkMode ? const Color(0xFF1E1E1E) : Colors.white);
    final textPrimary = isHighContrast
        ? Colors.white
        : (isDarkMode ? Colors.white : const Color(0xFF1F2937));
    final textSecondary = isHighContrast
        ? const Color(0xFFD1D5DB)
        : (isDarkMode ? Colors.white70 : const Color(0xFF4B5563));
    final activeTeal = isHighContrast ? const Color(0xFF80CBC4) : _tealPrimary;

    final sheetHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: isHighContrast
            ? const Border(
                top: BorderSide(color: Color(0xFF4B5563), width: 1.5),
                left: BorderSide(color: Color(0xFF4B5563), width: 1.5),
                right: BorderSide(color: Color(0xFF4B5563), width: 1.5),
              )
            : null,
        boxShadow: isHighContrast
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDarkMode ? 0.4 : 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isHighContrast
                        ? const Color(0xFF4B5563)
                        : (isDarkMode ? Colors.white24 : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isHighContrast
                          ? const Color(0xFF1E2430)
                          : activeTeal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: isHighContrast
                          ? Border.all(color: const Color(0xFF80CBC4))
                          : null,
                    ),
                    child: Icon(
                      CupertinoIcons.book_fill,
                      color: activeTeal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panduan SOP & Komunikasi',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Standar Operasional Relawan SahabatSOS',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'Tutup panduan',
                    button: true,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        icon: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: textSecondary,
                          size: 26,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab navigation selector (3 Tabs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? const Color(0xFF1E2430)
                      : (isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(12),
                  border: isHighContrast
                      ? Border.all(color: const Color(0xFF4B5563), width: 1.2)
                      : null,
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildTabButton(
                      index: 0,
                      label: 'SOP Lapangan',
                      icon: CupertinoIcons.shield_fill,
                      isHighContrast: isHighContrast,
                      isDarkMode: isDarkMode,
                      activeTeal: activeTeal,
                    ),
                    _buildTabButton(
                      index: 1,
                      label: 'Komunikasi',
                      icon: CupertinoIcons.chat_bubble_text_fill,
                      isHighContrast: isHighContrast,
                      isDarkMode: isDarkMode,
                      activeTeal: activeTeal,
                    ),
                    _buildTabButton(
                      index: 2,
                      label: 'Hotline Darurat',
                      icon: CupertinoIcons.phone_fill,
                      isHighContrast: isHighContrast,
                      isDarkMode: isDarkMode,
                      activeTeal: activeTeal,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                physics: const BouncingScrollPhysics(),
                child: _buildTabContent(
                  isHighContrast: isHighContrast,
                  isDarkMode: isDarkMode,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  activeTeal: activeTeal,
                ),
              ),
            ),

            // Bottom action button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: sheetBg,
                border: Border(
                  top: BorderSide(
                    color: isHighContrast
                        ? const Color(0xFF4B5563)
                        : (isDarkMode ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isHighContrast
                        ? const Color(0xFF00897B)
                        : _tealAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: isHighContrast
                          ? const BorderSide(color: Color(0xFF80CBC4), width: 1.5)
                          : BorderSide.none,
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    AccessibilityService.instance.hapticLight();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Saya Mengerti Protokol Ini',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    required bool isHighContrast,
    required bool isDarkMode,
    required Color activeTeal,
  }) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        label: 'Tab $label',
        child: InkWell(
          onTap: () {
            if (_selectedTab != index) {
              setState(() => _selectedTab = index);
              AccessibilityService.instance.hapticSelection();
              AccessibilityService.instance.announce('Membuka tab $label');
            }
          },
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isHighContrast
                      ? const Color(0xFF00897B)
                      : (isDarkMode ? const Color(0xFF374151) : Colors.white))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: isSelected && isHighContrast
                  ? Border.all(color: const Color(0xFF80CBC4), width: 1.5)
                  : null,
              boxShadow: isSelected && !isHighContrast
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? (isHighContrast
                          ? Colors.white
                          : (isDarkMode ? Colors.white : activeTeal))
                      : (isHighContrast
                          ? const Color(0xFFD1D5DB)
                          : (isDarkMode ? Colors.white60 : Colors.grey.shade600)),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? (isHighContrast
                              ? Colors.white
                              : (isDarkMode ? Colors.white : activeTeal))
                          : (isHighContrast
                              ? const Color(0xFFD1D5DB)
                              : (isDarkMode ? Colors.white60 : Colors.grey.shade600)),
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

  Widget _buildTabContent({
    required bool isHighContrast,
    required bool isDarkMode,
    required Color textPrimary,
    required Color textSecondary,
    required Color activeTeal,
  }) {
    switch (_selectedTab) {
      case 0:
        return _buildSopTindakanContent(
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        );
      case 1:
        return _buildKomunikasiContent(
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        );
      case 2:
      default:
        return _buildHotlineContent(
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        );
    }
  }

  // -------------------------------------------------------------
  // TAB 1: SOP TINDAKAN LAPANGAN (5 PROTOKOL AKSI)
  // -------------------------------------------------------------
  Widget _buildSopTindakanContent({
    required bool isHighContrast,
    required bool isDarkMode,
    required Color textPrimary,
    required Color textSecondary,
    required Color activeTeal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ringkasan Prinsip 3A
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isHighContrast
                ? const Color(0xFF1E2430)
                : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHighContrast
                  ? const Color(0xFF80CBC4)
                  : const Color(0xFFA7F3D0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons.checkmark_shield_fill,
                color: isHighContrast ? const Color(0xFF80CBC4) : const Color(0xFF059669),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prinsip Utama: 3A Sahabat Relawan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isHighContrast ? Colors.white : const Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '1. Aman Diri: Pastikan keselamatan Anda terjamin terlebih dahulu.\n'
                      '2. Aman Lingkungan: Hindari bahaya sekunder (api, gas, reruntuhan).\n'
                      '3. Aman Korban: Berikan pertolongan tanpa memperparah kondisi korban.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isHighContrast ? const Color(0xFFD1D5DB) : const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildSopStepCard(
          stepNumber: '1',
          title: 'Respon Cepat & Verifikasi Data (Maks. 90 Detik)',
          description:
              'Saat notifikasi darurat SOS masuk, cermati kategori disabilitas korban, lokasi kejadian di peta, dan riwayat medis yang terlampir sebelum menerima tugas.',
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        ),
        _buildSopStepCard(
          stepNumber: '2',
          title: 'Navigasi Cepat Menuju Lokasi & Persiapan Logistik',
          description:
              'Gunakan tab Peta untuk memantau rute tercepat. Bawa tas P3K, senter cadangan, dan pastikan baterai ponsel tetap terisi. Usahakan menelepon korban jika situasi memungkinkan.',
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        ),
        _buildSopStepCard(
          stepNumber: '3',
          title: 'Tiba di Lokasi & Amankan Situasi Sekitar',
          description:
              'Perkenalkan diri dengan tenang. Ciptakan jarak aman dari kerumunan warga, pastikan sirkulasi udara baik, dan tenangkan korban secara empatis.',
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        ),
        _buildSopStepCard(
          stepNumber: '4',
          title: 'Pertolongan Pertama (P3K) Sesuai Kebutuhan Khusus',
          description:
              'Lakukan tindakan pertolongan pertama dasar (balut bidai, hentikan pendarahan, posisi pemulihan). Jangan memindahkan alat bantu fisik tanpa izin korban.',
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        ),
        _buildSopStepCard(
          stepNumber: '5',
          title: 'Koordinasi Rujukan Medis & Selesaikan Tugas',
          description:
              'Jika kondisi korban kritis, segera hubungi 112 atau 119. Dampingi hingga petugas medis/keluarga tiba di tempat. Konfirmasi penyelesaian tugas di aplikasi setelah korban aman.',
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        ),
      ],
    );
  }

  Widget _buildSopStepCard({
    required String stepNumber,
    required String title,
    required String description,
    required bool isHighContrast,
    required bool isDarkMode,
    required Color textPrimary,
    required Color textSecondary,
    required Color activeTeal,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighContrast
            ? const Color(0xFF181818)
            : (isDarkMode ? const Color(0xFF262626) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF4B5563)
              : (isDarkMode ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
          width: isHighContrast ? 1.5 : 1.0,
        ),
        boxShadow: isHighContrast
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isHighContrast
                  ? const Color(0xFF00897B)
                  : activeTeal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: isHighContrast
                  ? Border.all(color: const Color(0xFF80CBC4), width: 1.5)
                  : null,
            ),
            child: Text(
              stepNumber,
              style: TextStyle(
                color: isHighContrast ? Colors.white : activeTeal,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: PROTOKOL KOMUNIKASI DISABILITAS (INKLUSIF)
  // -------------------------------------------------------------
  Widget _buildKomunikasiContent({
    required bool isHighContrast,
    required bool isDarkMode,
    required Color textPrimary,
    required Color textSecondary,
    required Color activeTeal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pedoman Berinteraksi Sesuai Ragam Disabilitas',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pendekatan yang tepat meminimalisasi trauma dan memastikan bantuan diterima dengan nyaman.',
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 14),

        _buildDisabilityCard(
          category: 'Tunanetra (Disabilitas Netra)',
          icon: CupertinoIcons.eye_slash,
          badgeColor: const Color(0xFF2563EB),
          points: [
            'Sapa secara verbal dan sebutkan nama serta peran Anda sebagai relawan SahabatSOS begitu tiba.',
            'Jelaskan tindakan secara deskriptif sebelum menyentuh korban atau memindahkan barang di sekitarnya.',
            'Tawarkan siku atau pundak Anda sebagai tumpuan pemandu jalan; hindari menarik pergelangan tangan korban.',
            'Beri tahu korban secara verbal saat Anda hendak berpindah posisi atau mengambil peralatan.',
          ],
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),

        _buildDisabilityCard(
          category: 'Tunarungu & Wicara (Disabilitas Rungu/Wicara)',
          icon: CupertinoIcons.chat_bubble_text_fill,
          badgeColor: const Color(0xFF059669),
          points: [
            'Lambaikan tangan sopan atau sentuh bahu perlahan untuk menarik perhatian secara ramah.',
            'Jaga kontak mata langsung dan bicaralah menghadap wajah korban dengan artikulasi jelas (jangan berteriak).',
            'Gunakan media ketikan di ponsel atau buku catatan bila korban lebih nyaman dengan komunikasi teks.',
            'Beri jeda dan waktu yang cukup bagi korban untuk merespons tanpa dipotong atau ditebak.',
          ],
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),

        _buildDisabilityCard(
          category: 'Tunadaksa (Disabilitas Fisik)',
          icon: CupertinoIcons.person_fill,
          badgeColor: const Color(0xFFD97706),
          points: [
            'Tanyakan bentuk bantuan yang diinginkan secara langsung sebelum melakukan tindakan fisik.',
            'Jangan pernah memindahkan atau menyandarkan kursi roda/kruk tanpa izin eksplisit dari korban.',
            'Posisikan tubuh Anda sejajar dengan pandangan mata korban saat sedang diajak berbicara.',
            'Pilihlah akses jalan yang landai dan periksa kestabilan tumpuan saat membimbing mobilitas.',
          ],
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),

        _buildDisabilityCard(
          category: 'Sensorik & Mental (Autisme, ADHD, Intelektual)',
          icon: CupertinoIcons.heart_fill,
          badgeColor: const Color(0xFF7C3AED),
          points: [
            'Gunakan nada suara yang tenang, bersahabat, stabil, dan jangan memperlihatkan kepanikan.',
            'Sampaikan instruksi singkat satu per satu secara konkret tanpa kiasan atau kalimat panjang.',
            'Jauhkan korban dari suara bising atau kerumunan warga untuk mencegah sensory overload.',
            'Hindari memaksa kontak fisik jika korban memperlihatkan penolakan atau kecemasan tinggi.',
          ],
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
      ],
    );
  }

  Widget _buildDisabilityCard({
    required String category,
    required IconData icon,
    required Color badgeColor,
    required List<String> points,
    required bool isHighContrast,
    required bool isDarkMode,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighContrast
            ? const Color(0xFF181818)
            : (isDarkMode ? const Color(0xFF262626) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF4B5563)
              : (isDarkMode ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
          width: isHighContrast ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? const Color(0xFF1E2430)
                      : badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: isHighContrast
                      ? Border.all(color: badgeColor, width: 1.2)
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isHighContrast ? Colors.white : badgeColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isHighContrast ? const Color(0xFF80CBC4) : badgeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: KONTAK DARURAT PENTING (HOTLINE RESMI)
  // -------------------------------------------------------------
  Widget _buildHotlineContent({
    required bool isHighContrast,
    required bool isDarkMode,
    required Color textPrimary,
    required Color textSecondary,
    required Color activeTeal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Panggilan Darurat Cepat (Klik untuk Menelepon)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Layanan gawat darurat resmi Indonesia untuk koordinasi cepat saat tugas.',
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 14),

        _buildHotlineCard(
          number: '112',
          title: 'Layanan Darurat Terpadu Nasional (NTE)',
          description: 'Pusat komando darurat 24 jam bebas pulsa untuk segala kondisi kritis.',
          badge: 'Bebas Pulsa',
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        ),

        _buildHotlineCard(
          number: '119',
          title: 'Ambulans & Gawat Darurat Medis (SPGDT)',
          description: 'Sistem evakuasi medis dan ambulans Kementerian Kesehatan RI.',
          badge: 'Layanan Medis',
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        ),

        _buildHotlineCard(
          number: '110',
          title: 'Kepolisian Republik Indonesia',
          description: 'Tindak kejahatan, ancaman keselamatan fisik, dan pengamanan lokasi.',
          badge: 'Keamanan',
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        ),

        _buildHotlineCard(
          number: '113',
          title: 'Pemadam Kebakaran & Evakuasi Rescue',
          description: 'Penanganan insiden kebakaran dan penyelamatan teknis dari reruntuhan.',
          badge: 'Penyelamatan',
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        ),

        _buildHotlineCard(
          number: '115',
          title: 'BASARNAS (Pencarian & Pertolongan)',
          description: 'Operasi pertolongan bencana alam besar dan kecelakaan darurat khusus.',
          badge: 'SAR Nasional',
          isHighContrast: isHighContrast,
          isDarkMode: isDarkMode,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          activeTeal: activeTeal,
        ),
      ],
    );
  }

  Widget _buildHotlineCard({
    required String number,
    required String title,
    required String description,
    required String badge,
    required bool isHighContrast,
    required bool isDarkMode,
    required Color textPrimary,
    required Color textSecondary,
    required Color activeTeal,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighContrast
            ? const Color(0xFF181818)
            : (isDarkMode ? const Color(0xFF262626) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF4B5563)
              : (isDarkMode ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
          width: isHighContrast ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighContrast
                  ? const Color(0xFF00897B)
                  : activeTeal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: isHighContrast
                  ? Border.all(color: const Color(0xFF80CBC4), width: 1.5)
                  : null,
            ),
            child: Icon(
              CupertinoIcons.phone_fill,
              size: 20,
              color: isHighContrast ? Colors.white : activeTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      number,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isHighContrast ? const Color(0xFF80CBC4) : activeTeal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isHighContrast
                            ? const Color(0xFF1E2430)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isHighContrast
                              ? const Color(0xFF4B5563)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Hubungi $number $title',
            button: true,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isHighContrast
                      ? const Color(0xFF00897B)
                      : activeTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isHighContrast
                        ? const BorderSide(color: Color(0xFF80CBC4), width: 1.5)
                        : BorderSide.none,
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  AccessibilityService.instance.hapticMedium();
                  final uri = Uri.parse('tel:$number');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: const Text(
                  'Panggil',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
