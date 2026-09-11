import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';

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
  _ReportCategory(this.title, this.subtitle, this.id, this.icon, this.iconColor);
}

class _QuickReportScreenState extends State<QuickReportScreen>
    with SingleTickerProviderStateMixin {
  static const Color primaryTeal = Color(0xFF00695C);

  int _selectedCategory = 0;
  int _selectedQuickMessage = 0;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  File? _selectedImage;
  File? _selectedAudio;
  
  bool _isRecording = false;
  late final AudioRecorder _audioRecorder;
  late final AnimationController _pulseController;

  final List<_ReportCategory> _categories = <_ReportCategory>[
    _ReportCategory('Butuh Pendamping', 'Relawan & Petugas', 'butuh_pendamping', Icons.people_alt_rounded, Color(0xFF1565C0)),
    _ReportCategory('Kondisi Medis', 'Ambulans & Obat', 'kondisi_medis', Icons.local_hospital_rounded, Color(0xFFD32F2F)),
    _ReportCategory('Ancaman / Bahaya', 'Keamanan Cepat', 'ancaman_bahaya', Icons.shield_rounded, Color(0xFFE65100)),
    _ReportCategory('Tersesat', 'Panduan Arah', 'tersesat', Icons.explore_rounded, Color(0xFF00838F)),
    _ReportCategory('Aksesibilitas Rusak', 'Bantuan Akses', 'aksesibilitas_rusak', Icons.accessible_rounded, Color(0xFF6A1B9A)),
    _ReportCategory('Lainnya', 'Bantuan Khusus', 'lainnya', Icons.more_horiz_rounded, Color(0xFF546E7A)),
  ];

  final List<Map<String, dynamic>> _quickMessages = <Map<String, dynamic>>[
    {'icon': Icons.check_circle, 'text': 'Saya butuh bantuan di lokasi saya'},
    {'icon': Icons.hearing_disabled, 'text': 'Saya tidak dapat berbicara / mendengar'},
    {'icon': Icons.phone_in_talk_outlined, 'text': 'Tolong hubungi kontak keluarga saya'},
    {'icon': Icons.accessible, 'text': 'Saya butuh bantuan mobilitas / kursi roda'},
  ];

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

  /// Fetch kategori laporan & pesan cepat dari API, fallback ke data hardcoded jika gagal
  Future<void> _fetchOptionsFromApi() async {
    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await sl<Dio>().get(
        ApiConstants.laporanOptions,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        }),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data;

        // Parse kategori
        final List? apiKategori = data['kategori_laporan'];
        if (apiKategori != null && apiKategori.isNotEmpty) {
          final newCategories = apiKategori.map<_ReportCategory>((item) {
            return _ReportCategory(
              item['title'] ?? '',
              item['subtitle'] ?? '',
              item['id'] ?? '',
              _getCategoryIcon(item['id'] ?? ''),
              _getCategoryColor(item['id'] ?? ''),
            );
          }).toList();

          setState(() {
            _categories
              ..clear()
              ..addAll(newCategories);
            _selectedCategory = 0;
          });
        }

        // Parse pesan cepat
        final List? apiPesan = data['pesan_cepat'];
        if (apiPesan != null && apiPesan.isNotEmpty) {
          final newMessages = apiPesan.map<Map<String, dynamic>>((text) {
            return {'icon': Icons.check_circle, 'text': text};
          }).toList();

          setState(() {
            _quickMessages
              ..clear()
              ..addAll(newMessages);
            _selectedQuickMessage = 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Gagal fetch laporan options, menggunakan data default: $e');
    }
  }

  IconData _getCategoryIcon(String id) {
    switch (id) {
      case 'butuh_pendamping': return Icons.people_alt_rounded;
      case 'kondisi_medis': return Icons.local_hospital_rounded;
      case 'ancaman_bahaya': return Icons.shield_rounded;
      case 'tersesat': return Icons.explore_rounded;
      case 'aksesibilitas_rusak': return Icons.accessible_rounded;
      case 'lainnya': return Icons.more_horiz_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  Color _getCategoryColor(String id) {
    switch (id) {
      case 'butuh_pendamping': return const Color(0xFF1565C0);
      case 'kondisi_medis': return const Color(0xFFD32F2F);
      case 'ancaman_bahaya': return const Color(0xFFE65100);
      case 'tersesat': return const Color(0xFF00838F);
      case 'aksesibilitas_rusak': return const Color(0xFF6A1B9A);
      case 'lainnya': return const Color(0xFF546E7A);
      default: return const Color(0xFF546E7A);
    }
  }

  Future<void> _fetchLocationInBackground() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _cachedPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final placemarks = await geo.Geocoding().placemarkFromCoordinates(
          _cachedPosition!.latitude, _cachedPosition!.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _cachedAddress = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}";
      }
    } catch (e) {
      debugPrint("Gagal pre-fetch lokasi: $e");
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioRecorder.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Mengkompresi gambar agar ukurannya kecil (mempercepat proses upload dan muat di riwayat)
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
          // Segera ubah UI agar terasa instan dan tidak lagging
          setState(() {
            _isRecording = true;
            _selectedAudio = null;
          });
          _pulseController.repeat(reverse: true);

          try {
            final tempDir = await getTemporaryDirectory();
            // Trik cerdas: Gunakan format WAV agar 100% lolos validasi finfo backend,
            // TETAPI kita turunkan kualitasnya ke standar telepon (8kHz, Mono).
            // Hasilnya: Ukuran file akan sama kecilnya dengan kompresi M4A/3GP (sekitar 16 KB/detik)
            // tanpa memicu error salah tebak format dari server.
            final filePath = '${tempDir.path}/rekaman_sos_${DateTime.now().millisecondsSinceEpoch}.wav';
            final config = const RecordConfig(
              encoder: AudioEncoder.wav, 
              sampleRate: 8000, 
              numChannels: 1,
            );
            
            await _audioRecorder.start(config, path: filePath);
          } catch (e) {
            // Revert state jika hardware gagal memulai
            setState(() { _isRecording = false; });
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error merekam: $e')),
        );
      }
    }
  }

  Future<void> _submitReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Get Location (Tunggu hasil pre-fetch jika belum selesai)
      if (_locationFuture != null) {
        await _locationFuture;
      }
      
      Position? position = _cachedPosition;
      String address = _cachedAddress ?? "Lokasi Tidak Diketahui";

      // Jika background fetch gagal, lakukan fallback sinkron sekali lagi
      if (position == null) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('GPS tidak aktif. Mohon nyalakan GPS.');
        }

        LocationPermission permission = await Geolocator.checkPermission();
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
            timeLimit: const Duration(seconds: 10),
            desiredAccuracy: LocationAccuracy.high,
          );
        } catch (e) {
          // Fallback to last known position if current position times out
          position = await Geolocator.getLastKnownPosition();
          if (position == null) {
            throw Exception('Gagal mendapatkan lokasi. Pastikan GPS aktif.');
          }
        }
        
        try {
          final placemarks = await geo.Geocoding().placemarkFromCoordinates(position.latitude, position.longitude)
              .timeout(const Duration(seconds: 5));
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            address = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}";
          }
        } catch (_) {}
      }

      // 2. Prepare Data
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token') ?? ''; // fallback for testing if no token
      final dio = sl<Dio>();

      final selectedCategory = _categories[_selectedCategory];
      final selectedQuickMessage = _quickMessages[_selectedQuickMessage]['text'];

      final formData = FormData.fromMap({
        'kategori_laporan': selectedCategory.id,
        'lokasi_laporan': address,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'pesan_cepat': selectedQuickMessage,
        'keterangan_tambahan': _notesController.text,
      });

      if (_selectedImage != null) {
        formData.files.add(MapEntry(
          'foto_laporan',
          await MultipartFile.fromFile(_selectedImage!.path),
        ));
      }

      if (_selectedAudio != null) {
        formData.files.add(MapEntry(
          'rekam_suara',
          await MultipartFile.fromFile(
            _selectedAudio!.path,
            contentType: MediaType('audio', 'wav'),
          ),
        ));
      }

      // 3. Send to Backend
      final response = await dio.post(
        ApiConstants.laporan,
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 3),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          // Reset form fields
          setState(() {
            _selectedCategory = 0;
            _selectedQuickMessage = 0;
            _notesController.clear();
            _selectedImage = null;
            _selectedAudio = null;
            _isRecording = false;
          });

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
              content: const Text(
                'Laporan berhasil dikirim!\nRelawan terdekat sedang menuju lokasi Anda.',
                textAlign: TextAlign.center,
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/dashboard?tab=3');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Lihat Riwayat', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Gagal mengirim laporan');
      }

    } on DioException catch (e) {
      if (mounted) {
        String errorMsg = e.message ?? 'Unknown error';
        if (e.response != null) {
          errorMsg = e.response?.data.toString() ?? 'Error ${e.response?.statusCode}';
        } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          errorMsg = 'Koneksi ke server timeout. Pastikan backend aktif.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMsg = 'Tidak bisa connect ke server (Cek IP baseUrl ${ApiConstants.baseUrl})';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal (Backend): $errorMsg'), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
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
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Kirim Laporan Cepat',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih kategori dan kirim pesan bantuan tanpa\nharus mengetik panjang.',
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('Kategori Laporan', trailing: 'Pilih salah satu'),
              const SizedBox(height: 10),
              _buildCategoryGrid(),
              const SizedBox(height: 20),
              _buildSectionHeader('Pesan Cepat (Ketuk untuk menyisipkan)'),
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
              const SizedBox(height: 20),
              _buildSendButton(),
              const SizedBox(height: 10),
              _buildFooterNote(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black12,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: const [
          Icon(Icons.accessibility_new, color: primaryTeal, size: 22),
          SizedBox(width: 8),
          Text(
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
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        if (trailing != null)
          Text(trailing, style: const TextStyle(fontSize: 12, color: Colors.black45)),
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
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _selectedCategory = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? primaryTeal : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? primaryTeal : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? primaryTeal.withOpacity(0.25)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: isSelected ? 10 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : category.iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    category.icon,
                    size: 22,
                    color: isSelected ? Colors.white : category.iconColor,
                  ),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        category.subtitle,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isSelected ? Colors.white70 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() => _selectedQuickMessage = index),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? primaryTeal : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 18,
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item['text'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(14),
          hintText: 'Jelaskan patokan lokasi atau kebutuhan\nspesifik Anda di sini...',
          hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildVoiceRecordTile() {
    return InkWell(
      onTap: _pickAudio,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: _isRecording
              ? const LinearGradient(
                  colors: [Color(0xFFD32F2F), Color(0xFFFF5252)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: _isRecording ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: _selectedAudio != null && !_isRecording
              ? Border.all(color: Colors.green.shade400, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: _isRecording
                  ? Colors.red.withOpacity(0.3)
                  : Colors.black.withOpacity(0.06),
              blurRadius: _isRecording ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Animated mic icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? Colors.white.withOpacity(0.2 + _pulseController.value * 0.15)
                        : (_selectedAudio != null
                            ? Colors.green.shade50
                            : const Color(0xFFFFF3E0)),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _isRecording
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2 + _pulseController.value * 0.2),
                              blurRadius: 8 + _pulseController.value * 6,
                              spreadRadius: _pulseController.value * 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    _isRecording
                        ? Icons.stop_rounded
                        : (_selectedAudio != null
                            ? Icons.check_rounded
                            : Icons.mic_rounded),
                    color: _isRecording
                        ? Colors.white
                        : (_selectedAudio != null
                            ? Colors.green.shade600
                            : const Color(0xFFF57C00)),
                    size: 24,
                  ),
                );
              },
            ),
            const SizedBox(width: 14),
            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRecording
                        ? 'Sedang Merekam...'
                        : (_selectedAudio != null
                            ? 'Rekaman Tersimpan'
                            : 'Rekam Pesan Suara'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _isRecording ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_isRecording)
                    // Animated waveform bars
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Row(
                          children: List.generate(12, (i) {
                            final barHeight = 4.0 +
                                (10.0 *
                                    (((_pulseController.value + i * 0.15) % 1.0) *
                                        (i.isEven ? 1.0 : 0.6)));
                            return Container(
                              width: 3,
                              height: barHeight,
                              margin: const EdgeInsets.only(right: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        );
                      },
                    )
                  else
                    Text(
                      _selectedAudio != null
                          ? _selectedAudio!.path.split('/').last
                          : 'Ketuk untuk mulai merekam suara',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isRecording ? Colors.white70 : Colors.black45,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Action indicator
            if (!_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedAudio != null
                      ? Colors.green.shade50
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _selectedAudio != null
                          ? Icons.check_circle_rounded
                          : Icons.mic_none_rounded,
                      size: 16,
                      color: _selectedAudio != null
                          ? Colors.green.shade600
                          : const Color(0xFFF57C00),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedAudio != null ? 'Selesai' : 'Rekam',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _selectedAudio != null
                            ? Colors.green.shade600
                            : const Color(0xFFF57C00),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'Ketuk untuk stop',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTile() {
    final hasPhoto = _selectedImage != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _pickImage,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: hasPhoto
              ? Border.all(color: Colors.blue.shade400, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Photo icon or preview
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hasPhoto ? Colors.blue.shade50 : const Color(0xFFE3F2FD),
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
                      Icons.camera_alt_rounded,
                      color: Color(0xFF1565C0),
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
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasPhoto
                        ? _selectedImage!.path.split('/').last
                        : 'Dokumentasikan situasi sekitar',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasPhoto ? Colors.blue.shade50 : const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasPhoto ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                    size: 16,
                    color: hasPhoto ? Colors.blue.shade700 : const Color(0xFF1565C0),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasPhoto ? 'Selesai' : 'Ambil',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasPhoto ? Colors.blue.shade700 : const Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // Sangat soft green/teal
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)), // Soft border
      ),
      child: Row(
        children: [
          // GPS icon with satellite ring
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Color(0xFF166534), // Dark green
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bagikan Lokasi Akurat',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF166534),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'GPS otomatis aktif saat mengirim',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF166534).withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFBBF7D0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gps_fixed_rounded, size: 14, color: const Color(0xFF15803D)),
                const SizedBox(width: 4),
                const Text(
                  'Aktif',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
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
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _isLoading 
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send, size: 18),
        label: Text(
          _isLoading ? 'Mengirim...' : 'Kirim Laporan Sekarang', 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.shield_outlined, size: 14, color: Colors.black45),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Tim relawan siaga 24 jam • Respon rata-rata 90 detik',
            style: TextStyle(fontSize: 11, color: Colors.black45),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
