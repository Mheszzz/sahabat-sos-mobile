import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';

class NewAssignmentDialog extends StatefulWidget {
  final Map<String, dynamic> sosData;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const NewAssignmentDialog({
    super.key,
    required this.sosData,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<NewAssignmentDialog> createState() => _NewAssignmentDialogState();
}

class _NewAssignmentDialogState extends State<NewAssignmentDialog> {
  late Timer _timer;
  int _secondsRemaining = 90;
  String? _address;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _resolveAddress();
  }

  Future<void> _resolveAddress() async {
    final lat = double.tryParse(widget.sosData['latitude']?.toString() ?? '') ?? 0.0;
    final lng = double.tryParse(widget.sosData['longitude']?.toString() ?? '') ?? 0.0;
    String? alamat;
    try {
      if (lat != 0.0 && lng != 0.0) {
        final placemarks = await Geocoding().placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addressList = [
            place.subLocality,
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ].where((e) => e != null && e.isNotEmpty).toList();
          if (addressList.isNotEmpty) {
             alamat = addressList.join(', ');
          }
        }
      }
    } catch (_) {}
    
    if (mounted) {
      setState(() {
        _address = alamat ?? 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        _timer.cancel();
        widget.onReject();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final int minutes = _secondsRemaining ~/ 60;
    final int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
        final dialogBg =
            isHighContrast ? const Color(0xFF121212) : Colors.white;
        final textPrimary = AccessibleColors.textPrimary(isHighContrast);
        final textSecondary = AccessibleColors.textSecondary(isHighContrast);
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : Colors.teal.shade700;

        final pengguna = widget.sosData['pengguna'] is Map
            ? widget.sosData['pengguna'] as Map<String, dynamic>
            : <String, dynamic>{};
        final user = widget.sosData['user'] is Map
            ? widget.sosData['user'] as Map<String, dynamic>
            : <String, dynamic>{};

        final namaPelapor = pengguna['name'] ??
            user['nama'] ??
            user['name'] ??
            widget.sosData['nama'] ??
            widget.sosData['nama_pelapor'] ??
            'Tanpa Nama';

        final kategori =
            pengguna['kategori_user'] ?? user['kategori_user'] ?? 'Umum';
        final metodeKomunikasi = pengguna['metode_komunikasi'] ??
            user['metode_komunikasi'] ??
            'Standar';
        final bool hasDisability = (kategori != 'Umum' && kategori != '');

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(28),
              border: isHighContrast
                  ? Border.all(color: const Color(0xFF4B5563), width: 1.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: isHighContrast ? 0.35 : 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Background
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isHighContrast
                          ? const Color(0xFF450A0A)
                          : const Color(0xFFC62828),
                      border: isHighContrast
                          ? const Border(
                              bottom: BorderSide(
                                color: Color(0xFFEF4444),
                                width: 1.5,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isHighContrast
                                ? const Color(0xFF1E2430)
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: isHighContrast
                                ? Border.all(color: const Color(0xFFEF4444))
                                : null,
                          ),
                          child: Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            color: isHighContrast
                                ? const Color(0xFFFDE68A)
                                : Colors.amber,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isHighContrast
                                          ? const Color(0xFFFDE68A)
                                          : Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'TINDAKAN CEPAT DIBUTUHKAN',
                                    style: TextStyle(
                                      color: isHighContrast
                                          ? const Color(0xFFFDE68A)
                                          : Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'PENUGASAN DARURAT BARU',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Waktu respon tersisa: $_formattedTime',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.time,
                                size: 14,
                                color: tealColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Baru saja',
                                style: TextStyle(
                                  color: tealColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Panggilan Darurat SOS',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pelapor: $namaPelapor',
                            style: TextStyle(
                              fontSize: 15,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Location Info Card (Solid)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isHighContrast
                                  ? const Color(0xFF1E2430)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isHighContrast
                                    ? const Color(0xFF4B5563)
                                    : Colors.grey.shade300,
                                width: isHighContrast ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.location_solid,
                                      color: tealColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Lokasi SOS',
                                      style: TextStyle(
                                        color: tealColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _address ?? 'Memuat...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Silakan gunakan peta untuk rute menuju lokasi',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Special Needs Card (Solid Yellow)
                          if (hasDisability)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isHighContrast
                                    ? const Color(0xFF451A03)
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isHighContrast
                                      ? const Color(0xFFF59E0B)
                                      : Colors.orange.shade200,
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
                                              ? const Color(0xFFF59E0B)
                                              : Colors.amber.shade600,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.person_solid,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Kebutuhan Khusus',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isHighContrast
                                              ? const Color(0xFF1E2430)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: isHighContrast
                                              ? Border.all(
                                                  color: const Color(
                                                      0xFFF59E0B))
                                              : null,
                                        ),
                                        child: Text(
                                          kategori,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isHighContrast
                                                ? const Color(0xFFFDE68A)
                                                : Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Metode Komunikasi:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          metodeKomunikasi,
                                          style: TextStyle(
                                            color: tealColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Footer Actions
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      decoration: BoxDecoration(
                        color: dialogBg,
                        border: Border(
                          top: BorderSide(
                            color: isHighContrast
                                ? const Color(0xFF4B5563)
                                : Colors.grey.shade200,
                            width: isHighContrast ? 1.5 : 1.0,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _timer.cancel();
                                widget.onAccept();
                              },
                              icon: const Icon(
                                CupertinoIcons.checkmark_alt_circle_fill,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: const Text(
                                'Terima & Mulai Tugas',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isHighContrast
                                    ? const Color(0xFF00897B)
                                    : Colors.teal.shade700,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: isHighContrast
                                      ? const BorderSide(
                                          color: Color(0xFF80CBC4),
                                          width: 1.5,
                                        )
                                      : BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _timer.cancel();
                                widget.onReject();
                              },
                              icon: Icon(
                                CupertinoIcons.xmark_circle_fill,
                                color: isHighContrast
                                    ? const Color(0xFF9CA3AF)
                                    : Colors.grey.shade600,
                                size: 20,
                              ),
                              label: Text(
                                'Alihkan Tugas',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: textSecondary,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isHighContrast
                                      ? const Color(0xFF4B5563)
                                      : Colors.grey.shade300,
                                  width: isHighContrast ? 1.5 : 1.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sistem otomatis mengalihkan tugas bila tidak dikonfirmasi dalam 90 detik.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isHighContrast
                                  ? const Color(0xFF9CA3AF)
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
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
}
