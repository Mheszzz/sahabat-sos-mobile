import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
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
  int? _selectedQuickMessage;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  File? _selectedImage;
  File? _selectedAudio;

  bool _isRecording = false;
  AudioPlayer? _audioPlayer;
  bool _isPlayingAudio = false;
  late final AudioRecorder _audioRecorder;
  late final AnimationController _pulseController;

  static const List<_ReportCategory> _defaultCategories = [
    _ReportCategory(
      'Butuh Pendamping',
      'Relawan & Petugas',
      'butuh_pendamping',
      CupertinoIcons.person_2_fill,
      Color(0xFF1565C0),
    ),
    _ReportCategory(
      'Kondisi Medis',
      'Ambulans & Obat',
      'kondisi_medis',
      CupertinoIcons.add_circled,
      Color(0xFFD32F2F),
    ),
    _ReportCategory(
      'Ancaman / Bahaya',
      'Keamanan Cepat',
      'ancaman_bahaya',
      CupertinoIcons.exclamationmark_triangle_fill,
      Color(0xFFE65100),
    ),
    _ReportCategory(
      'Tersesat',
      'Panduan Arah',
      'tersesat',
      CupertinoIcons.compass_fill,
      Color(0xFF00838F),
    ),
    _ReportCategory(
      'Aksesibilitas Rusak',
      'Bantuan Akses',
      'aksesibilitas_rusak',
      CupertinoIcons.person_crop_circle,
      Color(0xFF6A1B9A),
    ),
    _ReportCategory(
      'Lainnya',
      'Bantuan Khusus',
      'lainnya',
      CupertinoIcons.ellipsis_circle_fill,
      Color(0xFF546E7A),
    ),
  ];

  static const List<Map<String, dynamic>> _defaultQuickMessages = [
    {
      'icon': CupertinoIcons.checkmark_circle_fill,
      'text': 'Saya butuh bantuan di lokasi saya',
    },
    {
      'icon': CupertinoIcons.checkmark_circle_fill,
      'text': 'Saya tidak dapat berbicara / mendengar',
    },
    {
      'icon': CupertinoIcons.checkmark_circle_fill,
      'text': 'Tolong hubungi kontak keluarga saya',
    },
    {
      'icon': CupertinoIcons.checkmark_circle_fill,
      'text': 'Saya butuh bantuan mobilitas / kursi roda',
    },
  ];

  bool _isLoadingOptions = true;
  String? _optionsError;

  final List<_ReportCategory> _categories = List.from(_defaultCategories);
  final List<Map<String, dynamic>> _quickMessages =
      List.from(_defaultQuickMessages);

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
    _audioPlayer?.dispose();
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
            final id = (item['id'] ?? item['nama_kategori'] ?? '').toString();
            final title =
                (item['title'] ?? item['nama_kategori'] ?? id).toString();
            final subtitle =
                (item['subtitle'] ?? item['deskripsi'] ?? '').toString();
            final rawIcon = item['icon']?.toString();
            final rawColor = item['color']?.toString();
            return _ReportCategory(
              title,
              subtitle,
              id,
              _parseCategoryIcon(rawIcon, id),
              _parseCategoryColor(rawColor, id),
            );
          }).toList();

          _categories.clear();
          _categories.addAll(newCategories);
          if (_selectedCategory >= _categories.length) {
            _selectedCategory = 0;
          }
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
          if (_selectedQuickMessage != null &&
              _selectedQuickMessage! >= _quickMessages.length) {
            _selectedQuickMessage = null;
          }
        }

        setState(() {
          _isLoadingOptions = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal fetch laporan options: $e');
      if (mounted) {
        setState(() {
          _optionsError =
              'Gagal memuat opsi terbaru. Menggunakan opsi bawaan.';
          _isLoadingOptions = false;
        });
      }
    }
  }

  IconData _parseCategoryIcon(String? rawIcon, String id) {
    final searchTarget = '${rawIcon ?? ''} $id'.toLowerCase();
    if (searchTarget.contains('medis') ||
        searchTarget.contains('medical') ||
        searchTarget.contains('obat') ||
        searchTarget.contains('hospital') ||
        searchTarget.contains('ambulance')) {
      return CupertinoIcons.add_circled;
    }
    if (searchTarget.contains('access') ||
        searchTarget.contains('kursi') ||
        searchTarget.contains('wheelchair') ||
        searchTarget.contains('disabilitas')) {
      return CupertinoIcons.person_crop_circle;
    }
    if (searchTarget.contains('compass') ||
        searchTarget.contains('sesat') ||
        searchTarget.contains('arah') ||
        searchTarget.contains('peta') ||
        searchTarget.contains('nav')) {
      return CupertinoIcons.compass_fill;
    }
    if (searchTarget.contains('danger') ||
        searchTarget.contains('warning') ||
        searchTarget.contains('bahaya') ||
        searchTarget.contains('ancaman')) {
      return CupertinoIcons.exclamationmark_triangle_fill;
    }
    if (searchTarget.contains('fire') ||
        searchTarget.contains('kebakaran') ||
        searchTarget.contains('api') ||
        searchTarget.contains('flame')) {
      return CupertinoIcons.flame_fill;
    }
    if (searchTarget.contains('banjir') ||
        searchTarget.contains('gempa') ||
        searchTarget.contains('bencana') ||
        searchTarget.contains('tsunami') ||
        searchTarget.contains('storm')) {
      return CupertinoIcons.cloud_bolt_rain_fill;
    }
    if (searchTarget.contains('tabrakan') ||
        searchTarget.contains('kecelakaan') ||
        searchTarget.contains('car') ||
        searchTarget.contains('mobil') ||
        searchTarget.contains('motor')) {
      return CupertinoIcons.car_fill;
    }
    if (searchTarget.contains('police') ||
        searchTarget.contains('polisi') ||
        searchTarget.contains('shield') ||
        searchTarget.contains('keamanan')) {
      return CupertinoIcons.shield_fill;
    }
    if (searchTarget.contains('person') ||
        searchTarget.contains('pendamping') ||
        searchTarget.contains('relawan')) {
      return CupertinoIcons.person_2_fill;
    }
    if (searchTarget.contains('phone') ||
        searchTarget.contains('kontak') ||
        searchTarget.contains('call')) {
      return CupertinoIcons.phone_fill;
    }
    if (searchTarget.contains('bell') ||
        searchTarget.contains('sirene') ||
        searchTarget.contains('alarm')) {
      return CupertinoIcons.bell_fill;
    }
    return _getCategoryIcon(id);
  }

  Color _parseCategoryColor(String? rawColor, String id) {
    if (rawColor != null && rawColor.isNotEmpty) {
      try {
        final clean = rawColor.replaceFirst('#', '').trim();
        if (clean.length == 6) {
          return Color(int.parse('FF$clean', radix: 16));
        } else if (clean.length == 8) {
          return Color(int.parse(clean, radix: 16));
        }
      } catch (_) {}
    }
    return _getCategoryColor(id);
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
    final isHighContrast =
        AccessibilityService.instance.isHighContrastEnabled ||
        Theme.of(context).brightness == Brightness.dark ||
        MediaQuery.of(context).highContrast;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: isHighContrast ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pilih Sumber Foto Bukti Kejadian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isHighContrast ? Colors.white : const Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Maksimal ukuran file foto adalah 5 MB.',
                style: TextStyle(
                  fontSize: 12,
                  color: isHighContrast
                      ? const Color(0xFFD1D5DB)
                      : const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isHighContrast
                        ? const Color(0xFF1E3A34)
                        : primaryLightTeal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.camera_fill,
                      color: primaryTeal),
                ),
                title: Text(
                  'Kamera',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        isHighContrast ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                subtitle: Text(
                  'Ambil foto langsung di lokasi kejadian',
                  style: TextStyle(
                    fontSize: 12,
                    color: isHighContrast
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                  ),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isHighContrast
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.photo_fill,
                      color: Color(0xFF2563EB)),
                ),
                title: Text(
                  'Galeri',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        isHighContrast ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                subtitle: Text(
                  'Pilih foto dari penyimpanan perangkat',
                  style: TextStyle(
                    fontSize: 12,
                    color: isHighContrast
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                  ),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        const maxSizeBytes = 5 * 1024 * 1024; // 5 MB

        if (fileSize > maxSizeBytes) {
          if (mounted) {
            final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Ukuran foto terlalu besar ($sizeMb MB). Batas maksimal 5 MB.',
                ),
                backgroundColor: const Color(0xFFDC2626),
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedImage = file;
        });
        AccessibilityService.instance.hapticMedium();
        unawaited(
          AccessibilityService.instance.speak("Foto bukti berhasil dilampirkan"),
        );
      }
    } catch (e) {
      debugPrint("Gagal mengambil foto: $e");
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
    AccessibilityService.instance.hapticMedium();
    unawaited(AccessibilityService.instance.speak("Lampiran foto dihapus"));
  }

  Future<void> _pickAudio() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        _pulseController.stop();

        if (path != null) {
          final file = File(path);
          final fileSize = await file.length();
          const maxAudioBytes = 10 * 1024 * 1024; // 10 MB

          if (fileSize > maxAudioBytes) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ukuran rekaman suara melebihi batas 10 MB.'),
                  backgroundColor: Color(0xFFDC2626),
                ),
              );
            }
            setState(() {
              _isRecording = false;
              _selectedAudio = null;
            });
            return;
          }

          AccessibilityService.instance.hapticMedium();
          unawaited(
            AccessibilityService.instance.speak("Rekaman suara selesai disimpan"),
          );
          setState(() {
            _isRecording = false;
            _selectedAudio = file;
          });
        } else {
          setState(() {
            _isRecording = false;
          });
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          AccessibilityService.instance.hapticMedium();
          unawaited(
            AccessibilityService.instance.speak("Merekam suara"),
          );
          if (_audioPlayer != null && _isPlayingAudio) {
            await _audioPlayer!.stop();
            _isPlayingAudio = false;
          }
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
              sampleRate: 16000,
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

  Future<void> _toggleAudioPreview() async {
    if (_selectedAudio == null) return;

    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
          });
        }
      });
    }

    if (_isPlayingAudio) {
      await _audioPlayer!.pause();
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    } else {
      await _audioPlayer!.play(DeviceFileSource(_selectedAudio!.path));
      if (mounted) {
        setState(() {
          _isPlayingAudio = true;
        });
      }
    }
  }

  void _removeAudio() {
    if (_audioPlayer != null && _isPlayingAudio) {
      _audioPlayer!.stop();
    }
    setState(() {
      _selectedAudio = null;
      _isPlayingAudio = false;
    });
    AccessibilityService.instance.hapticMedium();
    unawaited(AccessibilityService.instance.speak("Rekaman suara dihapus"));
  }

  Future<void> _submitReport() async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data formulir laporan belum siap.')),
      );
      return;
    }

    final selectedCategory = _categories[_selectedCategory];
    final selectedQuickMessage = _selectedQuickMessage != null &&
            _selectedQuickMessage! < _quickMessages.length
        ? _quickMessages[_selectedQuickMessage!]['text'] as String
        : null;
    final notes = _notesController.text.trim();

    // Validasi kelengkapan minimal: harus ada pesan cepat, catatan, foto, atau rekaman suara
    if (selectedQuickMessage == null &&
        notes.isEmpty &&
        _selectedImage == null &&
        _selectedAudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mohon sertakan pesan cepat, keterangan tambahan, foto, atau rekaman suara.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
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

      final reportDataSource = sl<ReportRemoteDataSource>();
      await reportDataSource.submitReport(
        categoryId: selectedCategory.id,
        address: address,
        latitude: position.latitude,
        longitude: position.longitude,
        quickMessage: selectedQuickMessage,
        additionalNotes: notes.isNotEmpty ? notes : null,
        photoFile: _selectedImage,
        audioFile: _selectedAudio,
      );

      if (mounted) {
        AccessibilityService.instance.hapticHeavy();
        unawaited(AccessibilityService.instance.speak("Laporan terkirim"));

        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;

        setState(() {
          _selectedCategory = 0;
          _selectedQuickMessage = null;
          _notesController.clear();
          _selectedImage = null;
          _selectedAudio = null;
          _isRecording = false;
          _isPlayingAudio = false;
        });

        // Clean Solid Surface Dialog (Anti-Slop & Accessible)
        unawaited(
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor:
                  isHighContrast ? const Color(0xFF1E1E1E) : Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isHighContrast
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              title: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isHighContrast
                          ? const Color(0xFF1E3A34)
                          : primaryLightTeal,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: isHighContrast
                          ? const Color(0xFF80CBC4)
                          : primaryTeal,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Laporan Terkirim!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isHighContrast
                          ? Colors.white
                          : const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              content: Text(
                'Laporan darurat Anda telah berhasil dikirim ke sistem. Relawan terdekat sedang menuju lokasi Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isHighContrast
                      ? const Color(0xFFD1D5DB)
                      : const Color(0xFF4B5563),
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
    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled ||
            Theme.of(context).brightness == Brightness.dark ||
            MediaQuery.of(context).highContrast;
        final currentBg = isHighContrast ? Colors.black : const Color(0xFFF8FAFC);

        return Scaffold(
          backgroundColor: currentBg,
          appBar: _buildAppBar(isHighContrast),
          body: SafeArea(
            child: _categories.isEmpty && _isLoadingOptions
                ? const Center(
                    child: CupertinoActivityIndicator(radius: 16),
                  )
                : _categories.isEmpty && _optionsError != null
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
                                style: TextStyle(
                                  color: isHighContrast
                                      ? const Color(0xFFD1D5DB)
                                      : const Color(0xFF374151),
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
                            if (_isLoadingOptions)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: const LinearProgressIndicator(
                                    minHeight: 2,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryTeal,
                                    ),
                                  ),
                                ),
                              )
                            else if (_optionsError != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isHighContrast
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isHighContrast
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFFCD34D),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.info_circle_fill,
                                      size: 16,
                                      color: isHighContrast
                                          ? const Color(0xFFFBBF24)
                                          : const Color(0xFFD97706),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Mode offline: Form menggunakan opsi darurat bawaan.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isHighContrast
                                              ? const Color(0xFFFDE68A)
                                              : const Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              'Kirim Laporan Cepat',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: isHighContrast
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pilih kategori dan kirim pesan bantuan tanpa harus mengetik panjang.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isHighContrast
                                    ? const Color(0xFFD1D5DB)
                                    : const Color(0xFF4B5563),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionHeader(
                              'Kategori Laporan',
                              isHighContrast,
                              trailing: 'Pilih salah satu',
                            ),
                            const SizedBox(height: 10),
                            _buildCategoryGrid(isHighContrast),
                            const SizedBox(height: 20),
                            _buildSectionHeader(
                              'Pesan Cepat (Ketuk untuk menyisipkan)',
                              isHighContrast,
                            ),
                            const SizedBox(height: 10),
                            _buildQuickMessages(isHighContrast),
                            const SizedBox(height: 20),
                            _buildSectionHeader(
                              'Keterangan Tambahan (Opsional)',
                              isHighContrast,
                            ),
                            const SizedBox(height: 10),
                            _buildNotesField(isHighContrast),
                            const SizedBox(height: 20),
                            _buildSectionHeader(
                              'Lampiran & Koordinat Otomatis',
                              isHighContrast,
                            ),
                            const SizedBox(height: 10),
                            _buildVoiceRecordTile(isHighContrast),
                            const SizedBox(height: 10),
                            _buildPhotoTile(isHighContrast),
                            const SizedBox(height: 10),
                            _buildLocationTile(isHighContrast),
                            const SizedBox(height: 24),
                            _buildSendButton(),
                            const SizedBox(height: 12),
                            _buildFooterNote(isHighContrast),
                            const SizedBox(height: 85),
                          ],
                        ),
                      ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    return AppBar(
      backgroundColor: isHighContrast ? Colors.black : const Color(0xFFF8FAFC),
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: tealColor),
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 24, height: 24),
          const SizedBox(width: 8),
          Text(
            'Sahabat SOS',
            style: TextStyle(
              color: tealColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    bool isHighContrast, {
    String? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isHighContrast ? Colors.white : const Color(0xFF111827),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: TextStyle(
              fontSize: 12,
              color: isHighContrast
                  ? const Color(0xFFD1D5DB)
                  : const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryGrid(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final defaultBg = AccessibleColors.cardBackground(isHighContrast);
    final selectedBg =
        isHighContrast ? const Color(0xFF1E3A34) : primaryLightTeal;

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
            onTap: () {
              AccessibilityService.instance.handleTalkbackTap(
                id: 'report_category_${category.id}',
                speakText: "Kategori ${category.title}. ${category.subtitle}",
                hintText: "Tekan sekali lagi untuk memilih kategori ini.",
                onAction: () => setState(() => _selectedCategory = index),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? selectedBg : defaultBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? tealColor
                      : AccessibleColors.cardBorderColor(isHighContrast),
                  width: isSelected || isHighContrast ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isHighContrast ? 0.25 : 0.04,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
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
                                ? tealColor
                                : AccessibleColors.textPrimary(isHighContrast),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          category.subtitle,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AccessibleColors.textSecondary(isHighContrast),
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

  Widget _buildQuickMessages(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final defaultBg = AccessibleColors.cardBackground(isHighContrast);
    final selectedBg =
        isHighContrast ? const Color(0xFF1E3A34) : primaryLightTeal;

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
              onTap: () {
                final isCancelling = _selectedQuickMessage == index;
                final speakText = isCancelling
                    ? "Pesan cepat dibatalkan"
                    : "Pesan cepat: ${item['text']}";
                final hintText = isCancelling
                    ? "Tekan sekali lagi untuk membatalkan pilihan pesan."
                    : "Tekan sekali lagi untuk memilih pesan ini.";
                AccessibilityService.instance.handleTalkbackTap(
                  id: 'quick_msg_$index',
                  speakText: speakText,
                  hintText: hintText,
                  onAction: () {
                    setState(() {
                      if (_selectedQuickMessage == index) {
                        _selectedQuickMessage = null;
                      } else {
                        _selectedQuickMessage = index;
                      }
                    });
                  },
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? selectedBg : defaultBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? tealColor
                        : AccessibleColors.cardBorderColor(isHighContrast),
                    width: isSelected || isHighContrast ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isHighContrast ? 0.25 : 0.04,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
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
                          ? tealColor
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
                              ? tealColor
                              : AccessibleColors.textPrimary(isHighContrast),
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

  Widget _buildNotesField(bool isHighContrast) {
    return Container(
      decoration: BoxDecoration(
        color: AccessibleColors.fieldBackground(isHighContrast),
        borderRadius: BorderRadius.circular(12),
        border: AccessibleColors.cardBorder(isHighContrast),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isHighContrast ? 0.25 : 0.04,
            ),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        style: TextStyle(
          color: AccessibleColors.textPrimary(isHighContrast),
          fontSize: 13,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
          hintText:
              'Jelaskan patokan lokasi atau kebutuhan spesifik Anda di sini...',
          hintStyle: TextStyle(
            color: isHighContrast
                ? const Color(0xFF9CA3AF)
                : const Color(0xFF9CA3AF),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceRecordTile(bool isHighContrast) {
    final hasAudio = _selectedAudio != null;
    final defaultBg = AccessibleColors.cardBackground(isHighContrast);
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

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
                ? (isHighContrast ? const Color(0xFF3B1515) : const Color(0xFFFEF2F2))
                : (hasAudio
                    ? (isHighContrast ? const Color(0xFF143026) : const Color(0xFFF0FDF4))
                    : defaultBg),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isRecording
                  ? const Color(0xFFEF4444)
                  : (hasAudio
                      ? tealColor
                      : AccessibleColors.cardBorderColor(isHighContrast)),
              width: (_isRecording || hasAudio || isHighContrast) ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isHighContrast ? 0.25 : 0.04,
                ),
                blurRadius: 4,
                offset: const Offset(0, 1),
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
                              ? (isHighContrast
                                  ? const Color(0xFF1E3A34)
                                  : primaryLightTeal)
                              : (isHighContrast
                                  ? const Color(0xFF332015)
                                  : const Color(0xFFFFF7ED))),
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
                          : (hasAudio
                              ? tealColor
                              : (isHighContrast
                                  ? const Color(0xFFFB923C)
                                  : const Color(0xFFEA580C))),
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
                          : (hasAudio
                              ? 'Rekaman Suara Siap'
                              : 'Rekam Pesan Suara'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _isRecording
                            ? const Color(0xFFEF4444)
                            : AccessibleColors.textPrimary(isHighContrast),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: AccessibleColors.textSecondary(isHighContrast),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (!_isRecording && hasAudio) ...[
                IconButton(
                  tooltip: _isPlayingAudio ? 'Jeda Suara' : 'Putar Suara',
                  icon: Icon(
                    _isPlayingAudio
                        ? CupertinoIcons.pause_circle_fill
                        : CupertinoIcons.play_circle_fill,
                    color: tealColor,
                    size: 28,
                  ),
                  onPressed: _toggleAudioPreview,
                ),
                IconButton(
                  tooltip: 'Hapus Rekaman',
                  icon: const Icon(
                    CupertinoIcons.trash,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  onPressed: _removeAudio,
                ),
              ] else if (!_isRecording) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isHighContrast
                        ? const Color(0xFF332015)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.mic,
                        size: 15,
                        color: isHighContrast
                            ? const Color(0xFFFB923C)
                            : const Color(0xFFEA580C),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Rekam',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isHighContrast
                              ? const Color(0xFFFB923C)
                              : const Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
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

  Widget _buildPhotoTile(bool isHighContrast) {
    final hasPhoto = _selectedImage != null;
    final defaultBg = AccessibleColors.cardBackground(isHighContrast);
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickImage,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasPhoto
                ? (isHighContrast ? const Color(0xFF143026) : const Color(0xFFF0FDF4))
                : defaultBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasPhoto
                  ? tealColor
                  : AccessibleColors.cardBorderColor(isHighContrast),
              width: (hasPhoto || isHighContrast) ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isHighContrast ? 0.25 : 0.04,
                ),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: hasPhoto
                      ? (isHighContrast ? const Color(0xFF1E3A34) : primaryLightTeal)
                      : (isHighContrast ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF)),
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
                    : Icon(
                        CupertinoIcons.camera_fill,
                        color: isHighContrast ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AccessibleColors.textPrimary(isHighContrast),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasPhoto
                          ? _selectedImage!.path.split('/').last
                          : 'Dokumentasikan situasi sekitar Anda',
                      style: TextStyle(
                        fontSize: 12,
                        color: AccessibleColors.textSecondary(isHighContrast),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasPhoto)
                IconButton(
                  tooltip: 'Hapus Foto',
                  icon: const Icon(
                    CupertinoIcons.trash,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  onPressed: _removeImage,
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: hasPhoto
                      ? (isHighContrast ? const Color(0xFF1E3A34) : primaryLightTeal)
                      : (isHighContrast ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF)),
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
                          ? tealColor
                          : (isHighContrast ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasPhoto ? 'Ganti' : 'Ambil',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hasPhoto
                            ? tealColor
                            : (isHighContrast ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
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

  Widget _buildLocationTile(bool isHighContrast) {
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(16),
        border: AccessibleColors.cardBorder(isHighContrast),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isHighContrast ? 0.25 : 0.04,
            ),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isHighContrast ? const Color(0xFF1E3A34) : primaryLightTeal,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              CupertinoIcons.location_fill,
              color: tealColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bagikan Lokasi Akurat',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AccessibleColors.textPrimary(isHighContrast),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'GPS otomatis disematkan saat mengirim',
                  style: TextStyle(
                    fontSize: 12,
                    color: AccessibleColors.textSecondary(isHighContrast),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isHighContrast ? const Color(0xFF1E3A34) : primaryLightTeal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 15,
                  color: tealColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Aktif',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tealColor,
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
        onPressed: _isLoading
            ? null
            : () {
                AccessibilityService.instance.handleTalkbackTap(
                  id: 'quick_report_submit_btn',
                  speakText: "Kirim Laporan Bantuan",
                  hintText: "Tekan sekali lagi untuk mengirim laporan bantuan ke posko.",
                  onAction: _submitReport,
                );
              },
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

  Widget _buildFooterNote(bool isHighContrast) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          CupertinoIcons.shield,
          size: 14,
          color: AccessibleColors.textSecondary(isHighContrast),
        ),
        const SizedBox(width: 6),
        Text(
          'Laporan langsung diteruskan ke tim relawan aktif.',
          style: TextStyle(
            fontSize: 11.5,
            color: AccessibleColors.textSecondary(isHighContrast),
          ),
        ),
      ],
    );
  }
}
