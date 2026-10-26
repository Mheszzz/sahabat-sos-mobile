import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';

/// Pop-up darurat otomatis layar penuh yang muncul ketika ada SOS baru masuk via WebSocket.
/// Dilengkapi countdown timer 30 detik untuk "Terima & Mulai Tugas" atau "Alihkan Tugas".
class NewAssignmentDialog extends StatefulWidget {
  final Map<String, dynamic> sosData;
  final VoidCallback onAccept;
  final void Function(String? reason) onReject;

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
  static const int _totalDurationSeconds = 30;
  late Timer _timer;
  int _secondsRemaining = _totalDurationSeconds;
  String? _address;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _resolveAddressAndDistance();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityService.instance.hapticHeavy();
      unawaited(AccessibilityService.instance.announce(
        'Peringatan penugasan darurat baru masuk. Batas waktu respon tiga puluh detik.',
      ));
    });
  }

  Future<void> _resolveAddressAndDistance() async {
    final lat = double.tryParse(widget.sosData['latitude']?.toString() ?? '') ?? 0.0;
    final lng = double.tryParse(widget.sosData['longitude']?.toString() ?? '') ?? 0.0;

    // Hitung jarak dari posisi relawan saat ini jika GPS aktif
    try {
      if (sl.isRegistered<LocationService>()) {
        final locService = sl<LocationService>();
        final volPos = locService.currentPosition.value;
        if (volPos != null && lat != 0.0 && lng != 0.0) {
          final distanceMeters = Geolocator.distanceBetween(
            volPos.latitude,
            volPos.longitude,
            lat,
            lng,
          );
          _distanceKm = distanceMeters / 1000.0;
        }
      }
    } catch (_) {}

    // Reverse geocoding alamat korban
    String? alamat;
    try {
      if (lat != 0.0 && lng != 0.0) {
        final placemarks = await Geocoding().placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addressList = [
            place.street,
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
        _address = alamat ??
            widget.sosData['lokasi_user']?.toString() ??
            widget.sosData['lokasi_laporan']?.toString() ??
            'Koordinat: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });

          // Peringatan getaran taktil saat sisa waktu krusial
          if (_secondsRemaining == 30 || _secondsRemaining == 10) {
            AccessibilityService.instance.hapticMedium();
          }
        }
      } else {
        _timer.cancel();
        if (mounted) {
          setState(() {
            _secondsRemaining = 0;
          });
        }
        widget.onReject('Waktu respon habis');
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

  double get _progress {
    return (_secondsRemaining / _totalDurationSeconds).clamp(0.0, 1.0);
  }

  Color _getTimerColor(bool isHighContrast) {
    if (_secondsRemaining <= 15) {
      return isHighContrast ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
    }
    if (_secondsRemaining <= 45) {
      return isHighContrast ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    }
    return isHighContrast ? const Color(0xFF80CBC4) : const Color(0xFF00897B);
  }

  IconData _getDisabilityIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('netra')) {
      return CupertinoIcons.eye_slash_fill;
    } else if (cat.contains('rungu') || cat.contains('tuli') || cat.contains('wicara')) {
      return CupertinoIcons.ear;
    } else if (cat.contains('daksa') || cat.contains('fisik') || cat.contains('motorik')) {
      return CupertinoIcons.person_badge_minus;
    } else if (cat.contains('sensorik') || cat.contains('intelektual')) {
      return CupertinoIcons.heart_fill;
    }
    return CupertinoIcons.person_fill;
  }

  String _getCommunicationTip(String category, String? metode) {
    if (metode != null && metode.isNotEmpty && metode.toLowerCase() != 'standar') {
      return 'Metode Pilihan Korban: $metode';
    }
    final cat = category.toLowerCase();
    if (cat.contains('netra')) {
      return 'Pendekatan Verbal: Berikan petunjuk arah jam dan sapa dari arah depan.';
    } else if (cat.contains('rungu') || cat.contains('tuli') || cat.contains('wicara')) {
      return 'Komunikasi Visual: Gunakan chat WhatsApp atau tulisan, bicara menghadap korban.';
    } else if (cat.contains('daksa') || cat.contains('fisik')) {
      return 'Bantuan Mobilitas: Tanyakan persetujuan sebelum memindahkan alat bantu/kursi roda.';
    }
    return 'Lakukan pendekatan ramah, perkenalkan diri sebagai Relawan Sahabat SOS.';
  }

  @override
  Widget build(BuildContext context) {
    final isHighContrast = context.isHighContrast;
    final dialogBg = isHighContrast ? const Color(0xFF0A0A0A) : const Color(0xFFF9FAFB);
    final cardBg = AccessibleColors.cardBackground(isHighContrast);
    final textPrimary = AccessibleColors.textPrimary(isHighContrast);
    final textSecondary = AccessibleColors.textSecondary(isHighContrast);
    final timerColor = _getTimerColor(isHighContrast);
    const sosRed = Color(0xFFDC2626);

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
        'Pengguna Korban';

    final noTelp = pengguna['phone'] ??
        pengguna['no_telp'] ??
        user['no_telp'] ??
        widget.sosData['no_telp'] ??
        '-';

    final kategori = (pengguna['kategori_user'] ?? user['kategori_user'] ?? 'Umum').toString();
    final metodeKomunikasi = pengguna['metode_komunikasi'] ?? user['metode_komunikasi'];
    final catatanMedis = pengguna['catatan_medis'] ?? user['catatan_medis'] ?? widget.sosData['catatan'];
    final kebutuhanKhusus = pengguna['kebutuhan_khusus'] ?? user['kebutuhan_khusus'];

    final heartRate = widget.sosData['heart_rate'] ?? widget.sosData['telemetri']?['heart_rate'];
    final battery = widget.sosData['battery'] ?? widget.sosData['telemetri']?['battery'];

    return Dialog.fullscreen(
      backgroundColor: dialogBg,
      child: Scaffold(
        backgroundColor: dialogBg,
        body: SafeArea(
          child: Column(
            children: [
              // ── 1. Top Emergency Banner & Countdown HUD ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isHighContrast ? const Color(0xFF450A0A) : sosRed,
                  border: isHighContrast
                      ? const Border(
                          bottom: BorderSide(color: Color(0xFFEF4444), width: 2.0),
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.radiowaves_right,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TINDAKAN CEPAT DIBUTUHKAN',
                                style: TextStyle(
                                  color: Color(0xFFFDE68A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'PANGGILAN DARURAT BARU',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge Timer Digital
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: timerColor,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.stopwatch_fill,
                                size: 16,
                                color: timerColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formattedTime,
                                style: TextStyle(
                                  color: timerColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress Bar Countdown Timer 90 Detik
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 2. Scrollable Body Information ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kartu Rincian Korban
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: AccessibleColors.cardBorder(isHighContrast),
                          boxShadow: isHighContrast
                              ? const []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isHighContrast
                                      ? const Color(0xFF1E2430)
                                      : const Color(0xFFE0F2F1),
                                  child: Icon(
                                    _getDisabilityIcon(kategori),
                                    color: AccessibleColors.primaryTeal(isHighContrast),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        namaPelapor,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isHighContrast
                                                  ? const Color(0xFF374151)
                                                  : Colors.teal.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: AccessibleColors.primaryTeal(
                                                    isHighContrast),
                                              ),
                                            ),
                                            child: Text(
                                              kategori,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AccessibleColors.primaryTeal(
                                                    isHighContrast),
                                              ),
                                            ),
                                          ),
                                          if (noTelp != '-') ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              noTelp,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Tips Komunikasi Inklusif
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isHighContrast
                                    ? const Color(0xFF1E2430)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isHighContrast
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    CupertinoIcons.info_circle_fill,
                                    size: 18,
                                    color: isHighContrast
                                        ? const Color(0xFF93C5FD)
                                        : const Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _getCommunicationTip(kategori, metodeKomunikasi),
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        color: isHighContrast
                                            ? Colors.white
                                            : const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (catatanMedis != null &&
                                catatanMedis.toString().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Catatan Medis: $catatanMedis',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                            if (kebutuhanKhusus != null &&
                                kebutuhanKhusus.toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Kebutuhan: $kebutuhanKhusus',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Kartu Lokasi & Jarak
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: AccessibleColors.cardBorder(isHighContrast),
                          boxShadow: isHighContrast
                              ? const []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.location_solid,
                                  color: AccessibleColors.primaryTeal(isHighContrast),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Titik Lokasi Darurat',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AccessibleColors.primaryTeal(isHighContrast),
                                  ),
                                ),
                                const Spacer(),
                                if (_distanceKm != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isHighContrast
                                          ? const Color(0xFF451A03)
                                          : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isHighContrast
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFFFCD34D),
                                      ),
                                    ),
                                    child: Text(
                                      '±${_distanceKm!.toStringAsFixed(1)} km dari Anda',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isHighContrast
                                            ? const Color(0xFFFDE68A)
                                            : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _address ?? 'Menghubungkan ke satelit GPS...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Peta navigasi dengan rute tercepat akan otomatis aktif segera setelah tugas diterima.',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Telemetri Perangkat Korban (jika tersedia)
                      if (heartRate != null || battery != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: AccessibleColors.cardBorder(isHighContrast),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              if (heartRate != null)
                                Row(
                                  children: [
                                    const Icon(
                                      CupertinoIcons.heart_fill,
                                      color: Color(0xFFE11D48),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$heartRate BPM',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              if (battery != null)
                                Row(
                                  children: [
                                    const Icon(
                                      CupertinoIcons.battery_75_percent,
                                      color: Color(0xFF059669),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Baterai: $battery%',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── 3. Bottom Persistent Action Buttons ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(
                    top: BorderSide(
                      color: isHighContrast
                          ? const Color(0xFF4B5563)
                          : const Color(0xFFE5E7EB),
                      width: isHighContrast ? 1.5 : 1.0,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _timer.cancel();
                          AccessibilityService.instance.hapticMedium();
                          widget.onAccept();
                        },
                        icon: const Icon(
                          CupertinoIcons.checkmark_alt_circle_fill,
                          color: Colors.white,
                          size: 22,
                        ),
                        label: const Text(
                          'Terima & Mulai Tugas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isHighContrast
                              ? const Color(0xFF00897B)
                              : const Color(0xFF00695C),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _showRejectReasonSheet,
                        icon: Icon(
                          CupertinoIcons.arrow_2_squarepath,
                          color: isHighContrast
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFDC2626),
                          size: 18,
                        ),
                        label: Text(
                          'Alihkan Tugas ke Relawan Lain',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isHighContrast
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isHighContrast
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFFCA5A5),
                            width: isHighContrast ? 1.5 : 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sistem otomatis mengalihkan tugas bila tidak dikonfirmasi dalam 30 detik.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
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

  Future<void> _showRejectReasonSheet() async {
    _timer.cancel();
    AccessibilityService.instance.hapticMedium();

    final List<String> reasons = [
      'Sedang menangani insiden lain',
      'Lokasi terlalu jauh / ada kendala medan',
      'Kendaraan / peralatan tidak memadai',
      'Kendala darurat pribadi',
      'Lainnya',
    ];

    String selectedReason = reasons.first;
    final otherController = TextEditingController();

    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_2_squarepath,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alihkan Tugas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Pilih alasan agar sistem mengalihkan ke relawan lain',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...reasons.map((r) {
                    final isSelected = selectedReason == r;
                    return InkWell(
                      onTap: () {
                        setSheetState(() => selectedReason = r);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFF94A3B8),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (selectedReason == 'Lainnya') ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: otherController,
                      decoration: InputDecoration(
                        hintText: 'Tuliskan alasan penolakan...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            String finalReason = selectedReason;
                            if (selectedReason == 'Lainnya' &&
                                otherController.text.trim().isNotEmpty) {
                              finalReason = otherController.text.trim();
                            }
                            Navigator.pop(ctx, finalReason);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Konfirmasi Alihkan',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (chosen != null) {
      widget.onReject(chosen);
    } else {
      // Jika relawan membatalkan dialog alasan, lanjutkan timer jika masih tersisa waktu
      if (mounted && _secondsRemaining > 0) {
        _startTimer();
      } else {
        widget.onReject('Waktu respon habis');
      }
    }
  }
}
