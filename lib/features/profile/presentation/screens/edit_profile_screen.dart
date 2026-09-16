import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/api_constants.dart';
import '../../data/datasources/profile_remote_data_source.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color primaryTeal = Color(0xFF00695C);

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late String selectedCategory;

  XFile? _pickedImage;
  String _currentAvatarUrl = 'https://placehold.co/100x100.png';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.userData['name'] ?? '');
    emailController = TextEditingController(text: widget.userData['email'] ?? '');
    phoneController = TextEditingController(text: widget.userData['no_telp'] ?? '');
    addressController = TextEditingController(text: widget.userData['alamat'] ?? '');

    selectedCategory = widget.userData['kategori_user']?.toString().toLowerCase() ?? 'umum';
    if (!['umum', 'tunanetra', 'tunarungu', 'tunawicara'].contains(selectedCategory)) {
      selectedCategory = 'umum';
    }

    final foto = widget.userData['foto_profile'];
    if (foto != null && foto.toString().isNotEmpty) {
      if (foto.toString().startsWith('http://') || foto.toString().startsWith('https://')) {
        _currentAvatarUrl = foto;
      } else {
        _currentAvatarUrl = '${ApiConstants.baseUrl}/storage-file/$foto';
      }
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
      });
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
        
        bool haptic = true;
        bool voiceGuide = true;
        bool largeText = true;

        if (widget.userData['aksesibilitas'] != null) {
          voiceGuide = widget.userData['aksesibilitas']['panduan_suara'] == true;
          haptic = widget.userData['aksesibilitas']['getaran'] == true;
          largeText = widget.userData['aksesibilitas']['text_besar'] == true;
        } else {
          voiceGuide = (widget.userData['panduan_suara'] == 1 || widget.userData['panduan_suara'] == true);
          haptic = (widget.userData['getaran'] == 1 || widget.userData['getaran'] == true);
          largeText = (widget.userData['text_besar'] == 1 || widget.userData['text_besar'] == true);
        }

        Map<String, dynamic> dataToUpdate = {
          'name': nameController.text.isNotEmpty ? nameController.text : '-',
          'kategori_user': selectedCategory,
          'alamat': addressController.text.isNotEmpty ? addressController.text : '-',
          'no_telp': phoneController.text.isNotEmpty ? phoneController.text : '-',
          'getaran': haptic ? 1 : 0,
          'panduan_suara': voiceGuide ? 1 : 0,
          'text_besar': largeText ? 1 : 0,
        };

        final profileDataSource = GetIt.instance<ProfileRemoteDataSource>();
        
        if (_pickedImage != null) {
          await profileDataSource.updateProfileWithFoto(dataToUpdate, _pickedImage!);
        } else {
          await profileDataSource.updateProfile(dataToUpdate);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil berhasil diperbarui')),
          );
          context.pop(true); // Return true to indicate success
        }
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengupdate profil: $e')),
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

  Widget _buildGlassContainer({required Widget child, BorderRadius? borderRadius}) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: radius,
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField(TextEditingController controller, String hint, IconData icon, {TextInputType? keyboardType, bool readOnly = false}) {
    return _buildGlassContainer(
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: TextStyle(
          fontSize: 14, 
          color: readOnly ? Colors.black54 : Colors.black87
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.4)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          prefixIcon: Icon(icon, color: primaryTeal.withOpacity(0.7)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryTeal),
        title: const Text(
          'Edit Profil',
          style: TextStyle(
            color: primaryTeal,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Container(
        height: double.infinity,
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: primaryTeal))
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
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: primaryTeal.withOpacity(0.3), width: 3),
                                ),
                                child: CircleAvatar(
                                  radius: 46,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: _pickedImage != null
                                      ? FileImage(File(_pickedImage!.path)) as ImageProvider
                                      : NetworkImage(_currentAvatarUrl),
                                  onBackgroundImageError: (_, __) {},
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
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildModernTextField(nameController, 'Nama Lengkap', Icons.person_outline),
                      const SizedBox(height: 16),
                      _buildModernTextField(emailController, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress, readOnly: true),
                      const SizedBox(height: 16),
                      
                      _buildGlassContainer(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            icon: Icon(Icons.arrow_drop_down, color: primaryTeal.withOpacity(0.7)),
                            dropdownColor: const Color(0xFFF5F6F8),
                            items: [
                              {'value': 'umum', 'label': 'Umum', 'icon': Icons.person_outline_rounded},
                              {'value': 'tunanetra', 'label': 'Tunanetra', 'icon': Icons.visibility_off_outlined},
                              {'value': 'tunarungu', 'label': 'Tunarungu', 'icon': Icons.hearing_disabled_outlined},
                              {'value': 'tunawicara', 'label': 'Tunawicara', 'icon': Icons.speaker_notes_off_outlined},
                            ].map((item) {
                              return DropdownMenuItem<String>(
                                value: item['value'] as String,
                                child: Row(
                                  children: [
                                    Icon(item['icon'] as IconData, color: primaryTeal.withOpacity(0.7), size: 20),
                                    const SizedBox(width: 12),
                                    Text(item['label'] as String, style: const TextStyle(fontSize: 14, color: Colors.black87)),
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
                      
                      const SizedBox(height: 16),
                      _buildModernTextField(phoneController, 'Nomor Telepon', Icons.phone_outlined, keyboardType: TextInputType.phone),
                      const SizedBox(height: 16),
                      _buildModernTextField(addressController, 'Alamat Tempat Tinggal', Icons.home_outlined),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: primaryTeal.withOpacity(0.5),
                        ),
                        child: const Text(
                          'Simpan Perubahan',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
