import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/features/reports/data/datasources/report_remote_data_source.dart';

class QuickReportScreen extends StatefulWidget {
  const QuickReportScreen({super.key});

  @override
  State<QuickReportScreen> createState() => _QuickReportScreenState();
}

class _ReportCategory {
  final String title;
  final String subtitle;
  final String id;
  final IconData icon;
  final Color iconColor;

  const _ReportCategory(
    this.title,
    this.subtitle,
    this.id,
    this.icon,
    this.iconColor,
  );
}

class _QuickReportScreenState extends State<QuickReportScreen>
    with SingleTickerProviderStateMixin {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color primaryLightTeal = Color(0xFFE0F2F1);

  int _selectedCategory = 0;
  int _selectedQuickMessage = 0;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  File? _selectedImage;
  File? _selectedAudio;

  bool _isRecording = false;
  late final AudioRecorder _audioRecorder;
  late final AnimationController _pulseController;

  bool _isLoadingOptions = true;
  String? _optionsError;

  final List<_ReportCategory> _categories = [];
  final List<Map<String, dynamic>> _quickMessages = [];

  Position? _cachedPosition;
  String? _cachedAddress;
  Future<void>? _locationFuture;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _locationFuture = _fetchLocationInBackground();
    _fetchOptionsFromApi();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioRecorder.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Fetch kategori laporan & pesan cepat dari API
  Future<void> _fetchOptionsFromApi() async {
    setState(() {
      _isLoadingOptions = true;
      _optionsError = null;
    });

    try {
      final reportDataSource = sl<ReportRemoteDataSource>();
      final data = await reportDataSource.getReportOptions();

      if (mounted) {
        // Parse kategori
        final List? apiKategori = data['kategori_laporan'] as List?;
        if (apiKategori != null && apiKategori.isNotEmpty) {
          final newCategories = apiKategori.map<_ReportCategory>((item) {
            return _ReportCategory(
              item['nama_kategori'] ?? item['title'] ?? '',
              item['deskripsi'] ?? item['subtitle'] ?? '',
              item['nama_kategori'] ?? item['id'] ?? '',
              _getCategoryIcon(item['id'] ?? ''),
              _getCategoryColor(item['id'] ?? ''),
            );
          }).toList();

          _categories.clear();
          _categories.addAll(newCategories);
        }

        // Parse pesan cepat
        final List? apiPesan = data['pesan_cepat'] as List?;
        if (apiPesan != null && apiPesan.isNotEmpty) {
          final newMessages = apiPesan.map<Map<String, dynamic>>((text) {
            return {
              'icon': CupertinoIcons.checkmark_circle_fill,
              'text': text.toString(),
            };
          }).toList();

          _quickMessages.clear();
          _quickMessages.addAll(newMessages);
        }

        setState(() {
          _selectedCategory = 0;
          _selectedQuickMessage = 0;
          _isLoadingOptions = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal fetch laporan options: $e');
      if (mounted) {
        setState(() {
          _optionsError =
              'Gagal memuat data opsi laporan. Periksa koneksi internet Anda.';
          _isLoadingOptions = false;
        });
      }
    }
  }

  IconData _getCategoryIcon(String id) {
    switch (id) {
      case 'butuh_pendamping':
        return CupertinoIcons.person_2_fill;
      case 'kondisi_medis':
        return CupertinoIcons.add_circled;
      case 'ancaman_bahaya':
        return CupertinoIcons.exclamationmark_triangle_fill;
      case 'tersesat':
        return CupertinoIcons.compass_fill;
      case 'aksesibilitas_rusak':
        return CupertinoIcons.person_crop_circle;
      case 'lainnya':
        return CupertinoIcons.ellipsis_circle_fill;
      default:
        return CupertinoIcons.info;
    }
  }

  Color _getCategoryColor(String id) {
    switch (id) {
      case 'butuh_pendamping':
        return const Color(0xFF1565C0);
      case 'kondisi_medis':
        return const Color(0xFFD32F2F);
      case 'ancaman_bahaya':
        return const Color(0xFFE65100);
      case 'tersesat':
        return const Color(0xFF00838F);
      case 'aksesibilitas_rusak':
        return const Color(0xFF6A1B9A);
      case 'lainnya':
        return const Color(0xFF546E7A);
      default:
        return const Color(0xFF546E7A);
    }
  }

  Future<void> _fetchLocationInBackground() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _cachedPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final placemarks = await geo.Geocoding().placemarkFromCoordinates(
        _cachedPosition!.latitude,
        _cachedPosition!.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _cachedAddress =
            "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}";
      }
    } catch (e) {
      debugPrint("Gagal pre-fetch lokasi: $e");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 1080,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickAudio() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        _pulseController.stop();
        setState(() {
          _isRecording = false;
          if (path != null) {
            _selectedAudio = File(path);
          }
        });
      } else {
        if (await _audioRecorder.hasPermission()) {
          setState(() {
            _isRecording = true;
            _selectedAudio = null;
          });
          _pulseController.repeat(reverse: true);

          try {
            final tempDir = await getTemporaryDirectory();
            final filePath =
                '${tempDir.path}/rekaman_sos_${DateTime.now().millisecondsSinceEpoch}.wav';
            const config = RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 8000,
              numChannels: 1,
            );

            await _audioRecorder.start(config, path: filePath);
          } catch (e) {
            setState(() {
              _isRecording = false;
            });
            _pulseController.stop();
            rethrow;
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Izin mikrofon ditolak.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error merekam: $e')));
      }
    }
  }

  Future<void> _submitReport() async {
    if (_categories.isEmpty || _quickMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data formulir laporan belum siap.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_locationFuture != null) {
        await _locationFuture;
      }

      Position? position = _cachedPosition;
      String address = _cachedAddress ?? "Lokasi Tidak Diketahui";

      if (position == null) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('GPS tidak aktif. Mohon nyalakan GPS.');
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Izin lokasi ditolak.');
          }
        }

        if (permission == LocationPermission.deniedForever) {
          throw Exception('Izin lokasi diblokir permanen.');
        }

        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              timeLimit: Duration(seconds: 10),
              accuracy: LocationAccuracy.high,
            ),
          );
        } catch (e) {
          position = await Geolocator.getLastKnownPosition();
          if (position == null) {
            throw Exception('Gagal mendapatkan lokasi. Pastikan GPS aktif.');
          }
        }

        try {
          final placemarks = await geo.Geocoding()
              .placemarkFromCoordinates(position.latitude, position.longitude)
              .timeout(const Duration(seconds: 5));
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            address =
                "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}";
          }
        } catch (_) {}
      }

      final selectedCategory = _categories[_selectedCategory];
      final selectedQuickMessage =
          _quickMessages[_selectedQuickMessage]['text'] as String;

      final reportDataSource = sl<ReportRemoteDataSource>();
      await reportDataSource.submitReport(
        categoryId: selectedCategory.id,
        address: address,
        latitude: position.latitude,
        longitude: position.longitude,
        quickMessage: selectedQuickMessage,
        additionalNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        photoFile: _selectedImage,
        audioFile: _selectedAudio,
      );

      if (mounted) {
        setState(() {
          _selectedCategory = 0;
          _selectedQuickMessage = 0;
          _notesController.clear();
          _selectedImage = null;
          _selectedAudio = null;
          _isRecording = false;
        });

        // Clean Solid Surface Dialog (Anti-Slop)
        unawaited(
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              title: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: primaryLightTeal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: primaryTeal,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Laporan Terkirim!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Laporan darurat Anda telah berhasil dikirim ke sistem. Relawan terdekat sedang menuju lokasi Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563),
                  height: 1.5,
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/dashboard?tab=3');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Lihat Riwayat Laporan',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim laporan: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _isLoadingOptions
            ? const Center(
                child: CupertinoActivityIndicator(radius: 16),
              )
            : _optionsError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_triangle,
                        color: Color(0xFFDC2626),
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _optionsError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchOptionsFromApi,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Kirim Laporan Cepat',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pilih kategori dan kirim pesan bantuan tanpa harus mengetik panjang.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader(
                      'Kategori Laporan',
                      trailing: 'Pilih salah satu',
                    ),
                    const SizedBox(height: 10),
                    _buildCategoryGrid(),
                    const SizedBox(height: 20),
                    _buildSectionHeader(
                      'Pesan Cepat (Ketuk untuk menyisipkan)',
                    ),
                    const SizedBox(height: 10),
                    _buildQuickMessages(),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Keterangan Tambahan (Opsional)'),
                    const SizedBox(height: 10),
                    _buildNotesField(),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Lampiran & Koordinat Otomatis'),
                    const SizedBox(height: 10),
                    _buildVoiceRecordTile(),
                    const SizedBox(height: 10),
                    _buildPhotoTile(),
                    const SizedBox(height: 10),
                    _buildLocationTile(),
                    const SizedBox(height: 24),
                    _buildSendButton(),
                    const SizedBox(height: 12),
                    _buildFooterNote(),
                    const SizedBox(height: 85),
                  ],
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: primaryTeal),
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 24, height: 24),
          const SizedBox(width: 8),
          const Text(
            'Sahabat SOS',
            style: TextStyle(
              color: primaryTeal,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF111827),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.85,
      ),
      itemBuilder: (context, index) {
        final category = _categories[index];
        final isSelected = _selectedCategory == index;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _selectedCategory = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? primaryLightTeal : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? primaryTeal : const Color(0xFFE5E7EB),
                  width: isSelected ? 1.5 : 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: category.iconColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(category.icon, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          category.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: isSelected
                                ? primaryTeal
                                : const Color(0xFF111827),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          category.subtitle,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickMessages() {
    return Column(
      children: List.generate(_quickMessages.length, (index) {
        final item = _quickMessages[index];
        final isSelected = _selectedQuickMessage == index;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedQuickMessage = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryLightTeal : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? primaryTeal : const Color(0xFFE5E7EB),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.circle,
                      size: 18,
                      color: isSelected
                          ? primaryTeal
                          : const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item['text'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? primaryTeal
                              : const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNotesField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 13,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(14),
          hintText:
              'Jelaskan patokan lokasi atau kebutuhan spesifik Anda di sini...',
          hintStyle: TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceRecordTile() {
    final hasAudio = _selectedAudio != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickAudio,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isRecording
                ? const Color(0xFFFEF2F2)
                : (hasAudio ? const Color(0xFFF0FDF4) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isRecording
                  ? const Color(0xFFEF4444)
                  : (hasAudio ? primaryTeal : const Color(0xFFE5E7EB)),
              width: (_isRecording || hasAudio) ? 1.5 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? const Color(0xFFEF4444)
                          : (hasAudio
                              ? primaryLightTeal
                              : const Color(0xFFFFF7ED)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isRecording
                          ? CupertinoIcons.stop_fill
                          : (hasAudio
                              ? CupertinoIcons.checkmark_alt
                              : CupertinoIcons.mic_fill),
                      color: _isRecording
                          ? Colors.white
                          : (hasAudio ? primaryTeal : const Color(0xFFEA580C)),
                      size: 24,
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isRecording
                          ? 'Sedang Merekam Suara...'
                          : (hasAudio ? 'Rekaman Suara Siap' : 'Rekam Pesan Suara'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _isRecording
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_isRecording)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Row(
                            children: List.generate(12, (i) {
                              final barHeight = 4.0 +
                                  (12.0 *
                                      (((_pulseController.value + i * 0.15) %
                                              1.0) *
                                          (i.isEven ? 1.0 : 0.6)));
                              return Container(
                                width: 3,
                                height: barHeight,
                                margin: const EdgeInsets.only(right: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          );
                        },
                      )
                    else
                      Text(
                        hasAudio
                            ? _selectedAudio!.path.split('/').last
                            : 'Ketuk untuk mulai merekam suara',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (!_isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: hasAudio ? primaryLightTeal : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasAudio
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.mic,
                        size: 15,
                        color: hasAudio
                            ? primaryTeal
                            : const Color(0xFFEA580C),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasAudio ? 'Selesai' : 'Rekam',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: hasAudio
                              ? primaryTeal
                              : const Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Stop',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoTile() {
    final hasPhoto = _selectedImage != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickImage,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasPhoto ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasPhoto ? primaryTeal : const Color(0xFFE5E7EB),
              width: hasPhoto ? 1.5 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: hasPhoto ? primaryLightTeal : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  image: hasPhoto
                      ? DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasPhoto
                    ? null
                    : const Icon(
                        CupertinoIcons.camera_fill,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPhoto ? 'Foto Terlampir' : 'Ambil Foto Keadaan',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasPhoto
                          ? _selectedImage!.path.split('/').last
                          : 'Dokumentasikan situasi sekitar Anda',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: hasPhoto ? primaryLightTeal : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasPhoto
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.camera,
                      size: 15,
                      color: hasPhoto
                          ? primaryTeal
                          : const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasPhoto ? 'Ganti' : 'Ambil',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hasPhoto
                            ? primaryTeal
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationTile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryLightTeal,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              CupertinoIcons.location_fill,
              color: primaryTeal,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bagikan Lokasi Akurat',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'GPS otomatis disematkan saat mengirim',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: primaryLightTeal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 15,
                  color: primaryTeal,
                ),
                SizedBox(width: 4),
                Text(
                  'Aktif',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryTeal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryTeal.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CupertinoActivityIndicator(
                  color: Colors.white,
                ),
              )
            : const Icon(CupertinoIcons.paperplane_fill, size: 18),
        label: Text(
          _isLoading ? 'Mengirim Laporan...' : 'Kirim Laporan Sekarang',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(CupertinoIcons.shield, size: 14, color: Color(0xFF6B7280)),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Tim relawan siaga 24 jam • Respon cepat terkoordinasi',
            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
