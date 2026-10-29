import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/accessibility_service.dart';
import '../../../../core/services/location_service.dart';
import '../../data/datasources/profile_remote_data_source.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color primaryTeal = Color(0xFF00695C);

  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  late String selectedCategory;

  XFile? _pickedImage;
  String? _currentAvatarUrl;
  bool _avatarError = false;

  bool _isLoading = false;
  bool _isFetchingGps = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.userData['name'] ?? '');
    emailController = TextEditingController(
      text: widget.userData['email'] ?? '',
    );
    phoneController = TextEditingController(
      text: widget.userData['no_telp'] ?? '',
    );
    addressController = TextEditingController(
      text: widget.userData['alamat'] ?? '',
    );

    selectedCategory =
        widget.userData['kategori_user']?.toString().toLowerCase() ?? 'umum';
    if (![
      'umum',
      'tunanetra',
      'tunarungu',
      'tunawicara',
    ].contains(selectedCategory)) {
      selectedCategory = 'umum';
    }

    final foto = widget.userData['foto_profile_url'] ?? widget.userData['foto_profile'];
    if (foto != null && foto.toString().isNotEmpty) {
      final String fotoStr = foto.toString();
      if (fotoStr.startsWith('http://') ||
          fotoStr.startsWith('https://')) {
        _currentAvatarUrl = fotoStr;
      } else {
        String cleanPath =
            fotoStr.startsWith('/') ? fotoStr.substring(1) : fotoStr;
        if (cleanPath.startsWith('public/')) {
          cleanPath = cleanPath.substring(7);
        }
        _currentAvatarUrl = '${ApiConstants.storageUrl}/$cleanPath';
      }
    } else {
      _currentAvatarUrl = null;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _pickedImage = pickedFile;
        _avatarError = false;
      });
    }
  }

  Future<void> _fillAddressFromGps() async {
    if (_isFetchingGps) return;
    setState(() => _isFetchingGps = true);

    try {
      final locationService = GetIt.instance<LocationService>();
      final hasPermission = await locationService.requestPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Izin akses GPS dibutuhkan untuk mendeteksi lokasi.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 8));

      final placemarks = await geo.Geocoding().placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.street, p.subLocality, p.locality, p.administrativeArea]
            .where((s) => s != null && s.trim().isNotEmpty)
            .toList();
        if (parts.isNotEmpty) {
          addressController.text = parts.join(', ');
          AccessibilityService.instance.hapticLight();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Alamat domisili berhasil diisi dari sensor GPS.'),
                backgroundColor: primaryTeal,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil lokasi GPS: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingGps = false);
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        // Terapkan adaptasi aksesibilitas otomatis jika kategori berubah
        await AccessibilityService.instance.applyCategoryDefaults(
          selectedCategory,
          syncBackend: false,
        );

        final service = AccessibilityService.instance;

        final Map<String, dynamic> dataToUpdate = {
          'name': nameController.text.isNotEmpty ? nameController.text : '-',
          'kategori_user': selectedCategory,
          'alamat': addressController.text.trim().isNotEmpty
              ? addressController.text.trim()
              : '-',
          'no_telp': phoneController.text.isNotEmpty
              ? phoneController.text
              : '-',
          'getaran': service.isHapticEnabled ? 1 : 0,
          'panduan_suara': service.isVoiceGuideEnabled ? 1 : 0,
          'talkback': service.isTalkbackEnabled ? 1 : 0,
          'text_besar': service.isLargeTextEnabled ? 1 : 0,
          'kontras_tinggi': service.isHighContrastEnabled ? 1 : 0,
        };

        final profileDataSource = GetIt.instance<ProfileRemoteDataSource>();

        if (_pickedImage != null) {
          await profileDataSource.updateProfileWithFoto(
            dataToUpdate,
            _pickedImage!,
          );
        } else {
          await profileDataSource.updateProfile(dataToUpdate);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil berhasil diperbarui')),
          );
          context.pop(true);
        }
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengupdate profil: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildCategoryAdaptationInfo(String category, bool isHighContrast) {
    String text;
    IconData icon;
    Color iconColor;

    switch (category.toLowerCase()) {
      case 'tunanetra':
        text =
            'Optimasi Tunanetra: Panduan Suara TalkBack, Teks Besar, Kontras Tinggi, dan Umpan Balik Getaran Taktil akan diaktifkan secara otomatis.';
        icon = CupertinoIcons.eye_slash_fill;
        iconColor = const Color(0xFFEF6C00);
        break;
      case 'tunarungu':
        text =
            'Optimasi Tunarungu: Getaran Taktil Maksimal dan Peringatan Visual Flash diaktifkan. Panduan Suara dinonaktifkan.';
        icon = CupertinoIcons.waveform_path_badge_plus;
        iconColor = const Color(0xFF0284C7);
        break;
      case 'tunawicara':
        text =
            'Optimasi Tunawicara: Umpan Balik Getaran & Laporan Teks Cepat dioptimalkan untuk komunikasi non-verbal.';
        icon = CupertinoIcons.text_bubble_fill;
        iconColor = const Color(0xFF7C3AED);
        break;
      case 'umum':
      default:
        text =
            'Mode Standar: Semua pengaturan aksesibilitas dapat disesuaikan secara manual di halaman profil.';
        icon = CupertinoIcons.person_fill;
        iconColor = primaryTeal;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isHighContrast ? const Color(0xFF262626) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF404040)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isHighContrast ? const Color(0xFFFBBF24) : iconColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isHighContrast
                    ? Colors.grey.shade300
                    : const Color(0xFF4B5563),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    bool readOnly = false,
    bool isHighContrast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly
            ? (isHighContrast
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFF3F4F6))
            : (isHighContrast ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF4B5563)
              : const Color(0xFFE5E7EB),
          width: isHighContrast ? 1.5 : 1.0,
        ),
        boxShadow: isHighContrast
            ? null
            : const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: TextStyle(
          fontSize: 14,
          color: readOnly
              ? (isHighContrast
                  ? Colors.grey.shade400
                  : const Color(0xFF6B7280))
              : (isHighContrast ? Colors.white : const Color(0xFF111827)),
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 13,
            color:
                isHighContrast ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          prefixIcon: Icon(
            icon,
            color: isHighContrast ? const Color(0xFF14B8A6) : primaryTeal,
            size: 20,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled;
        final bgColor = isHighContrast ? Colors.black : const Color(0xFFF8FAFC);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleSpacing: 0,
            iconTheme: IconThemeData(
              color: isHighContrast ? const Color(0xFF14B8A6) : primaryTeal,
            ),
            leading: IconButton(
              icon: Icon(
                CupertinoIcons.back,
                color: isHighContrast ? const Color(0xFF14B8A6) : primaryTeal,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 24, height: 24),
                const SizedBox(width: 8),
                Text(
                  'Edit Profil',
                  style: TextStyle(
                    color:
                        isHighContrast ? const Color(0xFF14B8A6) : primaryTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: _isLoading
                ? const Center(
                    child: CupertinoActivityIndicator(radius: 16),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isHighContrast
                                          ? Colors.white
                                          : primaryTeal.withValues(alpha: 0.3),
                                      width: 3,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 46,
                                    backgroundColor: isHighContrast
                                        ? Colors.grey.shade800
                                        : primaryTeal.withValues(alpha: 0.1),
                                    backgroundImage: _pickedImage != null
                                        ? FileImage(File(_pickedImage!.path))
                                            as ImageProvider
                                        : (_currentAvatarUrl != null &&
                                                _currentAvatarUrl!.isNotEmpty &&
                                                !_avatarError)
                                            ? NetworkImage(_currentAvatarUrl!)
                                            : null,
                                    onBackgroundImageError: (_pickedImage ==
                                                null &&
                                            _currentAvatarUrl != null &&
                                            _currentAvatarUrl!.isNotEmpty)
                                        ? (_, _) {
                                            if (mounted && !_avatarError) {
                                              setState(() => _avatarError = true);
                                            }
                                          }
                                        : null,
                                    child: (_pickedImage == null &&
                                            (_currentAvatarUrl == null ||
                                                _currentAvatarUrl!.isEmpty ||
                                                _avatarError))
                                        ? Icon(
                                            CupertinoIcons.person_fill,
                                            size: 46,
                                            color: isHighContrast
                                                ? const Color(0xFF14B8A6)
                                                : primaryTeal,
                                          )
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: primaryTeal,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isHighContrast
                                            ? Colors.black
                                            : Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.camera_fill,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildModernTextField(
                          nameController,
                          'Nama Lengkap',
                          CupertinoIcons.person,
                          isHighContrast: isHighContrast,
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          emailController,
                          'Email',
                          CupertinoIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                          readOnly: true,
                          isHighContrast: isHighContrast,
                        ),
                        const SizedBox(height: 16),
                        // Dropdown Kategori Disabilitas
                        Container(
                          decoration: BoxDecoration(
                            color: isHighContrast
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isHighContrast
                                  ? const Color(0xFF4B5563)
                                  : const Color(0xFFE5E7EB),
                              width: isHighContrast ? 1.5 : 1.0,
                            ),
                            boxShadow: isHighContrast
                                ? null
                                : const [
                                    BoxShadow(
                                      color: Color(0x06000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCategory,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              icon: Icon(
                                CupertinoIcons.chevron_down,
                                color: isHighContrast
                                    ? const Color(0xFF14B8A6)
                                    : primaryTeal,
                                size: 18,
                              ),
                              dropdownColor: isHighContrast
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white,
                              items: [
                                {
                                  'value': 'umum',
                                  'label': 'Umum',
                                  'icon': CupertinoIcons.person,
                                },
                                {
                                  'value': 'tunanetra',
                                  'label': 'Tunanetra',
                                  'icon': CupertinoIcons.eye_slash,
                                },
                                {
                                  'value': 'tunarungu',
                                  'label': 'Tunarungu',
                                  'icon': CupertinoIcons.ear,
                                },
                                {
                                  'value': 'tunawicara',
                                  'label': 'Tunawicara',
                                  'icon': CupertinoIcons.mic_slash,
                                },
                              ].map((item) {
                                return DropdownMenuItem<String>(
                                  value: item['value'] as String,
                                  child: Row(
                                    children: [
                                      Icon(
                                        item['icon'] as IconData,
                                        color: isHighContrast
                                            ? const Color(0xFF14B8A6)
                                            : primaryTeal,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        item['label'] as String,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isHighContrast
                                              ? Colors.white
                                              : const Color(0xFF111827),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedCategory = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Banner Informasi Adaptasi Aksesibilitas
                        _buildCategoryAdaptationInfo(
                          selectedCategory,
                          isHighContrast,
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          phoneController,
                          'Nomor Telepon Darurat',
                          CupertinoIcons.phone,
                          keyboardType: TextInputType.phone,
                          isHighContrast: isHighContrast,
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          addressController,
                          'Alamat Tempat Tinggal (Domisili Tetap)',
                          CupertinoIcons.house,
                          isHighContrast: isHighContrast,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Catatan: Alamat ini adalah domisili tetap tempat tinggal Anda untuk rujukan penyelamat. Berbeda dengan Lokasi GPS real-time yang dideteksi otomatis saat keadaan darurat.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isHighContrast
                                ? Colors.grey.shade400
                                : const Color(0xFF6B7280),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed:
                                _isFetchingGps ? null : _fillAddressFromGps,
                            icon: _isFetchingGps
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child:
                                        CupertinoActivityIndicator(radius: 7),
                                  )
                                : Icon(
                                    CupertinoIcons.location_fill,
                                    color: isHighContrast
                                        ? const Color(0xFF14B8A6)
                                        : primaryTeal,
                                    size: 16,
                                  ),
                            label: Text(
                              _isFetchingGps
                                  ? 'Mendeteksi koordinat GPS...'
                                  : 'Gunakan Lokasi GPS Saat Ini sebagai Alamat',
                              style: TextStyle(
                                color: isHighContrast
                                    ? const Color(0xFF14B8A6)
                                    : primaryTeal,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: isHighContrast ? 0 : 2,
                          ),
                          child: const Text(
                            'Simpan Perubahan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
