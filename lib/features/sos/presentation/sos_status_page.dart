import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/location_service.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/services/websocket_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import 'package:sahabat_sos_mobile/features/sos/data/datasources/sos_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/slide_to_cancel_button.dart';

class SosStatusPage extends StatefulWidget {
  final int? initialSosId;

  const SosStatusPage({super.key, this.initialSosId});

  @override
  State<SosStatusPage> createState() => _SosStatusPageState();
}

class _SosStatusPageState extends State<SosStatusPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color sosRed = Color(0xFFDC2626);
  static const Color warningOrange = Color(0xFFD97706);
  static const Color bgSurface = Color(0xFFF5F6F8);

  Timer? _statusTimer;
  Timer? _selesaiTimer;
  bool _isSelesaiTimerStarted = false;
  String _sosStatus = 'belum ditangani';
  int? _sosId;
  double? _relawanDistance;
  Map<String, dynamic>? _assignedRelawan;

  bool get _isDitangani => _sosStatus == 'ditangani';
  bool get _isSelesai => _sosStatus == 'selesai';
  bool get _isBatal => _sosStatus == 'batal';

  final LocationService _locationService = sl<LocationService>();
  final SosRemoteDataSource _sosRemoteDataSource = sl<SosRemoteDataSource>();
  StreamSubscription<ServiceStatus>? _serviceStatusStream;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  int _emptyPollCount = 0;
  bool _isListeningRelawan = false;
  bool _isSubscribedToSos = false;

  @override
  void initState() {
    super.initState();
    _sosId = widget.initialSosId;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchSosStatus();
    _initWebSocket();

    // Polling fallback every 4 seconds in case WebSocket drops
    _statusTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _fetchSosStatus(),
    );

    // Continuous location tracking to broadcast user GPS to volunteer
    _startLocationTracking();
  }

  Future<void> _initWebSocket() async {
    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      await WebsocketService.init(token);
      if (_sosId != null && mounted) {
        _setupWebSocketListeners(_sosId!);
      }
    } catch (e) {
      debugPrint('WebSocket init error in SosStatusPage: $e');
    }
  }

  void _setupWebSocketListeners(int sosId) {
    if (_isSubscribedToSos || WebsocketService.echo == null) return;
    _isSubscribedToSos = true;

    WebsocketService.listenToSosStatusUpdate(sosId, (payload) {
      if (!mounted || payload == null) return;

      final rawStatus = (payload['status_sos'] ?? 'belum ditangani')
          .toString()
          .toLowerCase();

      setState(() {
        _sosStatus = rawStatus;
        if (payload['relawan'] != null && payload['relawan'] is Map) {
          final relawanData =
              Map<String, dynamic>.from(payload['relawan'] as Map);
          if (_assignedRelawan != null) {
            _assignedRelawan = {..._assignedRelawan!, ...relawanData};
          } else {
            _assignedRelawan = relawanData;
          }
        }
      });

      if (_isDitangani) {
        if (!_isListeningRelawan) {
          _listenToRelawanLocation(sosId);
        }
        _fetchSosStatus();
      }

      if (_isSelesai || _isBatal) {
        _startSelesaiTimer();
      }
    });

    if (_isDitangani && !_isListeningRelawan) {
      _listenToRelawanLocation(sosId);
    }
  }

  void _listenToRelawanLocation(int sosId) {
    _isListeningRelawan = true;
    WebsocketService.listenToRelawanLocation(sosId, (payload) {
      if (!mounted || payload == null) return;
      setState(() {
        if (payload['distance'] != null) {
          _relawanDistance = (payload['distance'] as num).toDouble();
        }
        final volunteerName = payload['nama'] ?? payload['name'];
        if (volunteerName != null &&
            volunteerName.toString().trim().isNotEmpty) {
          final nameStr = volunteerName.toString().trim();
          if (_assignedRelawan == null) {
            _assignedRelawan = {'name': nameStr, 'nama': nameStr};
          } else {
            _assignedRelawan = {
              ..._assignedRelawan!,
              'name': _assignedRelawan!['name'] ?? nameStr,
              'nama': _assignedRelawan!['nama'] ?? nameStr,
            };
          }
        }
      });
    });
  }

  Future<void> _startLocationTracking() async {
    final hasPermission = await _locationService.requestPermission();
    if (hasPermission) {
      _locationService.startTracking();

      _serviceStatusStream = Geolocator.getServiceStatusStream().listen((
        status,
      ) {
        if (status == ServiceStatus.enabled) {
          _locationService.startTracking();
        } else {
          _locationService.stopTracking();
        }
      });
    }
  }

  Future<void> _fetchSosStatus() async {
    try {
      final data = await _sosRemoteDataSource.getActiveEmergency();

      if (!mounted) return;

      if (data != null) {
        final rawStatus = (data['status_sos'] ?? 'belum ditangani')
            .toString()
            .toLowerCase();

        setState(() {
          _sosId = data['id'];
          _sosStatus = rawStatus;
          _emptyPollCount = 0;
          if (data['relawan'] != null && data['relawan'] is Map) {
            _assignedRelawan =
                Map<String, dynamic>.from(data['relawan'] as Map);
          }
        });

        if (_sosId != null) {
          _setupWebSocketListeners(_sosId!);
        }

        if (_isDitangani && _sosId != null && !_isListeningRelawan) {
          _listenToRelawanLocation(_sosId!);
        }

        if (_isSelesai || _isBatal) {
          _startSelesaiTimer();
        }
      } else {
        // 15-second grace period (3 polls) for async backend processing
        _emptyPollCount++;
        if (_emptyPollCount > 3) {
          if (_isBatal) {
            _startSelesaiTimer();
          } else if (_sosId != null) {
            try {
              final detail = await _sosRemoteDataSource.getSosDetail(_sosId!);
              if (!mounted) return;
              final actualStatus =
                  (detail?['status_sos'] ?? '').toString().toLowerCase();
              if (actualStatus == 'batal') {
                setState(() {
                  _sosStatus = 'batal';
                });
                _startSelesaiTimer();
                return;
              }
            } catch (_) {}

            setState(() {
              _sosStatus = 'selesai';
            });
            _startSelesaiTimer();
          } else {
            setState(() {
              _sosStatus = 'selesai';
            });
            _startSelesaiTimer();
          }
        }
      }
    } catch (e) {
      debugPrint('Gagal fetch status SOS: $e');
    }
  }

  void _startSelesaiTimer() {
    if (_isSelesaiTimerStarted) return;
    _isSelesaiTimerStarted = true;
    _statusTimer?.cancel();
    _locationService.stopTracking();
    _selesaiTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        context.pop();
      }
    });
  }

  Future<String?> _promptCancellationReason() async {
    final reasons = [
      'Tidak sengaja tertekan (Salah tekan)',
      'Uji coba / Pengetesan sistem',
      'Situasi darurat sudah teratasi mandiri',
      'Bantuan pihak lain sudah tiba di lokasi',
      'Lainnya',
    ];
    String selectedReason = reasons[0];
    final customReasonController = TextEditingController();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isHighContrast =
                AccessibilityService.instance.isHighContrastEnabled ||
                Theme.of(context).brightness == Brightness.dark ||
                MediaQuery.of(context).highContrast;

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                top: 24,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: AccessibleColors.cardBackground(isHighContrast),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: AccessibleColors.cardBorder(isHighContrast),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AccessibleColors.cardBorderColor(isHighContrast),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Alasan Pembatalan SOS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AccessibleColors.textPrimary(isHighContrast),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pilih alasan mengapa sinyal darurat ini dibatalkan untuk catatan riwayat laporan:',
                      style: TextStyle(
                        fontSize: 13,
                        color: AccessibleColors.textSecondary(isHighContrast),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...reasons.map((reason) {
                      final isSelected = selectedReason == reason;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isHighContrast ? const Color(0xFF1E2430) : const Color(0xFFE0F2F1))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? primaryTeal
                                : AccessibleColors.cardBorderColor(isHighContrast),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setModalState(() {
                              selectedReason = reason;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? CupertinoIcons.check_mark_circled_solid
                                      : CupertinoIcons.circle,
                                  size: 20,
                                  color: isSelected
                                      ? primaryTeal
                                      : (isHighContrast ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: AccessibleColors.textPrimary(isHighContrast),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (selectedReason == 'Lainnya') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customReasonController,
                        autofocus: true,
                        maxLength: 100,
                        style: TextStyle(color: AccessibleColors.textPrimary(isHighContrast)),
                        decoration: InputDecoration(
                          hintText: 'Tuliskan alasan pembatalan...',
                          hintStyle: TextStyle(color: AccessibleColors.textSecondary(isHighContrast)),
                          filled: true,
                          fillColor: AccessibleColors.fieldBackground(isHighContrast),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AccessibleColors.cardBorderColor(isHighContrast)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: primaryTeal, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(null),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Tetap Aktifkan'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (selectedReason == 'Lainnya') {
                                final customText = customReasonController.text.trim();
                                Navigator.of(sheetContext).pop(
                                  customText.isNotEmpty ? customText : 'Dibatalkan oleh pengguna',
                                );
                              } else {
                                Navigator.of(sheetContext).pop(selectedReason);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: sosRed,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Ya, Batalkan SOS',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _cancelSos() async {
    if (_sosId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membatalkan: ID SOS tidak ditemukan'),
          ),
        );
        context.pop();
      }
      return;
    }

    final reason = await _promptCancellationReason();
    if (reason == null || reason.trim().isEmpty) {
      // Pembatalan dibatalkan oleh pengguna, lemparkan error agar slider snap-back
      throw Exception('Pembatalan dibatalkan');
    }

    try {
      final success = await _sosRemoteDataSource.cancelEmergency(
        _sosId!,
        reason: reason.trim(),
      );

      if (mounted) {
        if (success) {
          setState(() {
            _sosStatus = 'batal';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sinyal SOS dibatalkan ($reason)')),
          );
          _startSelesaiTimer();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal membatalkan SOS')),
          );
          throw Exception('Gagal membatalkan SOS di server');
        }
      }
    } catch (e) {
      debugPrint('Gagal membatalkan SOS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membatalkan SOS')),
        );
      }
      rethrow;
    }
  }

  Future<void> _callVolunteer(String? phone) async {
    if (phone == null || phone.trim().isEmpty || phone == '-') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nomor kontak relawan/admin tidak tersedia.'),
          action: SnackBarAction(
            label: 'Panggil 112',
            textColor: Colors.amberAccent,
            onPressed: () => _callNumber('112'),
          ),
        ),
      );
      return;
    }
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Format nomor telepon relawan tidak valid.'),
          action: SnackBarAction(
            label: 'Panggil 112',
            textColor: Colors.amberAccent,
            onPressed: () => _callNumber('112'),
          ),
        ),
      );
      return;
    }
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat memanggil nomor $phone'),
            action: SnackBarAction(
              label: 'Panggil 112',
              textColor: Colors.amberAccent,
              onPressed: () => _callNumber('112'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openWhatsAppVolunteer(String? phone, String? name) async {
    if (phone == null || phone.trim().isEmpty || phone == '-') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nomor WhatsApp relawan/admin tidak tersedia.'),
          action: SnackBarAction(
            label: 'Panggil 112',
            textColor: Colors.amberAccent,
            onPressed: () => _callNumber('112'),
          ),
        ),
      );
      return;
    }
    String clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Format nomor WhatsApp relawan tidak valid.'),
          action: SnackBarAction(
            label: 'Panggil 112',
            textColor: Colors.amberAccent,
            onPressed: () => _callNumber('112'),
          ),
        ),
      );
      return;
    }
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    } else if (clean.startsWith('+')) {
      clean = clean.substring(1);
    }

    final volunteerName =
        (name != null && name.trim().isNotEmpty) ? name.trim() : 'Relawan';
    final message = Uri.encodeComponent(
      'Halo $volunteerName, saya membutuhkan bantuan terkait panggilan darurat SOS ini.',
    );
    final uri = Uri.parse('https://wa.me/$clean?text=$message');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal membuka aplikasi WhatsApp.'),
            action: SnackBarAction(
              label: 'Panggil 112',
              textColor: Colors.amberAccent,
              onPressed: () => _callNumber('112'),
            ),
          ),
        );
      }
    }
  }

  String _getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'R';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String? _getRelawanPhotoUrl(dynamic foto) {
    if (foto == null) return null;
    final str = foto.toString().trim();
    if (str.isEmpty || str == 'null') return null;
    if (str.startsWith('http://') || str.startsWith('https://')) {
      return str;
    }
    final cleanPath = str
        .replaceFirst(RegExp(r'^/?public/'), '')
        .replaceFirst(RegExp(r'^/?storage/'), '');
    return '${ApiConstants.storageUrl}/$cleanPath';
  }

  Widget _buildRelawanAvatar({
    required String name,
    required String? photoUrl,
    required bool isHighContrast,
    double size = 40,
  }) {
    final fullUrl = _getRelawanPhotoUrl(photoUrl);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isHighContrast
            ? const Color(0xFF004D40)
            : const Color(0xFFE0F2F1),
        shape: BoxShape.circle,
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF80CBC4)
              : primaryTeal.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: fullUrl != null
            ? Image.network(
                fullUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildInitialsFallback(name, isHighContrast, fontSize: size * 0.35),
              )
            : _buildInitialsFallback(name, isHighContrast, fontSize: size * 0.35),
      ),
    );
  }

  Widget _buildInitialsFallback(String name, bool isHighContrast, {double fontSize = 14}) {
    final initials = _getInitials(name);
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: isHighContrast ? const Color(0xFF80CBC4) : primaryTeal,
        ),
      ),
    );
  }

  Widget _buildAssignedRelawanCard(bool isHighContrast) {
    final relawan = _assignedRelawan;
    final name = (relawan?['name'] ??
            relawan?['nama'] ??
            'Relawan Penanggung Jawab')
        .toString();
    final rawPhone = relawan?['no_telp'] ??
        relawan?['phone'] ??
        relawan?['nomor_telepon'];
    final phone = rawPhone?.toString().trim();
    final photo = relawan?['foto_profile'] ??
        relawan?['foto'] ??
        relawan?['foto_profile_url'];

    final distanceText = _relawanDistance != null
        ? (_relawanDistance! < 1000
            ? '${_relawanDistance!.toStringAsFixed(0)} m dari Anda'
            : '${(_relawanDistance! / 1000).toStringAsFixed(1)} km dari Anda')
        : 'Sedang menuju ke lokasi Anda';

    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final hasPhone = phone != null && phone.trim().isNotEmpty && phone != '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF80CBC4)
              : const Color(0xFFB2DFDB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isHighContrast ? 0.3 : 0.04,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildRelawanAvatar(
                name: name,
                photoUrl: photo?.toString(),
                isHighContrast: isHighContrast,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AccessibleColors.textPrimary(isHighContrast),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.location_solid,
                          size: 12,
                          color: warningOrange,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            distanceText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AccessibleColors.textSecondary(
                                isHighContrast,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? const Color(0xFF004D40)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Menuju Lokasi',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isHighContrast
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      AccessibilityService.instance.hapticLight();
                      _callVolunteer(phone);
                    },
                    icon: Icon(
                      CupertinoIcons.phone_fill,
                      size: 14,
                      color: hasPhone ? tealColor : Colors.grey,
                    ),
                    label: Text(
                      'Hubungi Relawan',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: hasPhone ? tealColor : Colors.grey,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: hasPhone ? tealColor : Colors.grey.shade400,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      AccessibilityService.instance.hapticLight();
                      _openWhatsAppVolunteer(phone, name);
                    },
                    icon: const Icon(
                      CupertinoIcons.chat_bubble_2_fill,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Chat WA',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasPhone
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF9E9E9E),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _callNumber(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat memanggil nomor $phone')),
      );
    }
  }

  void _showEmergencyHotlinesModal(bool isHighContrast) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isHighContrast ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isHighContrast
                          ? const Color(0xFF4B5563)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kontak Darurat Nasional',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AccessibleColors.textPrimary(isHighContrast),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hubungi layanan darurat resmi jika membutuhkan pertolongan cepat.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AccessibleColors.textSecondary(isHighContrast),
                  ),
                ),
                const SizedBox(height: 16),
                _buildHotlineTile(
                  title: '112 - Panggilan Darurat Nasional',
                  subtitle: 'Layanan Terpadu Bebas Pulsa (Semua Keadaan Darurat)',
                  phone: '112',
                  icon: CupertinoIcons.phone_fill,
                  color: sosRed,
                  isHighContrast: isHighContrast,
                ),
                const SizedBox(height: 8),
                _buildHotlineTile(
                  title: '110 - Kepolisian Republik Indonesia',
                  subtitle: 'Keamanan, Kriminalitas, dan Gangguan Ketertiban',
                  phone: '110',
                  icon: CupertinoIcons.shield_fill,
                  color: isHighContrast
                      ? const Color(0xFF60A5FA)
                      : const Color(0xFF1E3A8A),
                  isHighContrast: isHighContrast,
                ),
                const SizedBox(height: 8),
                _buildHotlineTile(
                  title: '119 - Layanan Ambulans / Medis',
                  subtitle: 'Pertolongan Medis Gawat Darurat',
                  phone: '119',
                  icon: CupertinoIcons.heart_fill,
                  color: const Color(0xFFDC2626),
                  isHighContrast: isHighContrast,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHotlineTile({
    required String title,
    required String subtitle,
    required String phone,
    required IconData icon,
    required Color color,
    required bool isHighContrast,
  }) {
    final tileBg = isHighContrast ? const Color(0xFF2D3748) : bgSurface;
    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

    return Material(
      color: tileBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context);
          _callNumber(phone);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isHighContrast ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AccessibleColors.textPrimary(isHighContrast),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AccessibleColors.textSecondary(isHighContrast),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.phone, color: tealColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTimer?.cancel();
    _selesaiTimer?.cancel();
    _serviceStatusStream?.cancel();
    _locationService.stopTracking();
    if (_sosId != null) {
      WebsocketService.stopListeningSosStatusUpdate(_sosId!);
      WebsocketService.stopListeningRelawanLocation(_sosId!);
    }
    super.dispose();
  }

  Color get _statusColor {
    if (_isBatal) return const Color(0xFF6B7280);
    if (_isSelesai) return primaryTeal;
    if (_isDitangani) return warningOrange;
    return sosRed;
  }

  String get _statusHeaderTitle {
    if (_isBatal) return 'PANGGILAN DIBATALKAN';
    if (_isSelesai) return 'BANTUAN SELESAI';
    if (_isDitangani) return 'RELAWAN DALAM PERJALANAN';
    return 'MENUNGGU RELAWAN';
  }

  String get _statusHeaderSubtitle {
    if (_isBatal) return 'Panggilan darurat Anda telah dibatalkan.';
    if (_isSelesai) return 'Panggilan darurat Anda telah selesai ditangani.';
    if (_isDitangani) {
      final name = _assignedRelawan?['name'] ?? _assignedRelawan?['nama'];
      final namePrefix = (name != null && name.toString().trim().isNotEmpty)
          ? '${name.toString().trim()} sedang'
          : 'Relawan sedang';
      if (_relawanDistance != null) {
        return '$namePrefix menuju ke lokasi Anda (jarak ~${_relawanDistance!.toStringAsFixed(0)} m).';
      }
      return '$namePrefix bergerak menuju lokasi Anda.';
    }
    return 'Menunggu relawan terdekat menerima panggilan darurat...';
  }

  IconData get _statusHeaderIcon {
    if (_isBatal) return CupertinoIcons.xmark_circle_fill;
    if (_isSelesai) return CupertinoIcons.checkmark_circle_fill;
    if (_isDitangani) return CupertinoIcons.car_detailed;
    return CupertinoIcons.speaker_3_fill;
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
        final currentBg = AccessibleColors.scaffoldBackground(isHighContrast);
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

        final canExit = _isSelesai || _isBatal;

        return PopScope(
          canPop: canExit,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Sinyal SOS sedang aktif. Geser slider di bawah jika ingin membatalkan keadaan darurat.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          },
          child: Scaffold(
            backgroundColor: currentBg,
            appBar: AppBar(
              backgroundColor: currentBg,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              iconTheme: IconThemeData(color: tealColor),
              leading: canExit
                  ? IconButton(
                      icon: Icon(CupertinoIcons.back, color: tealColor),
                      onPressed: () => context.pop(),
                    )
                  : null,
              centerTitle: false,
              titleSpacing: canExit ? 0 : 16,
              title: Row(
                children: [
                  Image.asset('assets/images/logo.png', width: 22, height: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Status Keadaan Darurat',
                      style: TextStyle(
                        color: tealColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(CupertinoIcons.headphones, size: 20),
                  color: tealColor,
                  tooltip: 'Layanan Darurat Nasional',
                  onPressed: () => _showEmergencyHotlinesModal(isHighContrast),
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            Center(
                              child: AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  final scale = (!_isSelesai && !_isBatal)
                                      ? _pulseAnimation.value
                                      : 1.0;
                                  return Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        color: _statusColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _statusColor.withValues(
                                              alpha: 0.35,
                                            ),
                                            blurRadius: 20,
                                            spreadRadius: 3,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _statusHeaderIcon,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _statusHeaderTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _statusColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                _statusHeaderSubtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AccessibleColors.textSecondary(
                                    isHighContrast,
                                  ),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_isDitangani) ...[
                              _buildAssignedRelawanCard(isHighContrast),
                              const SizedBox(height: 12),
                            ],
                            _buildTimelineCard(isHighContrast),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showEmergencyHotlinesModal(isHighContrast),
                            icon: Icon(
                              CupertinoIcons.headphones,
                              color: tealColor,
                              size: 16,
                            ),
                            label: Text(
                              'Kontak Darurat Nasional (112, 110, 119)',
                              style: TextStyle(
                                color: tealColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: tealColor.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_isSelesai || _isBatal)
                          ElevatedButton(
                            onPressed: () => context.pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isBatal
                                  ? const Color(0xFF6B7280)
                                  : primaryTeal,
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              _isBatal ? 'Kembali' : 'Selesai',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else ...[
                          SlideToCancelButton(
                            onCancelled: _cancelSos,
                            height: 50,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Geser ke kanan untuk membatalkan keadaan darurat.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AccessibleColors.textSecondary(
                                isHighContrast,
                              ),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        SizedBox(
                          height: MediaQuery.paddingOf(context).bottom + 4,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineCard(bool isHighContrast) {
    const step1Done = true;
    final step2Active = _isDitangani && !_isBatal;
    final step2Done = _isSelesai;
    final step3Done = _isSelesai;

    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

    String currentDescription;
    if (_isBatal) {
      currentDescription = 'Panggilan darurat telah dibatalkan.';
    } else if (_isSelesai) {
      currentDescription = 'Proses penanganan darurat telah selesai.';
    } else if (_isDitangani) {
      final name = _assignedRelawan?['name'] ?? _assignedRelawan?['nama'];
      final distanceStr = _relawanDistance != null
          ? ' (~${_relawanDistance! < 1000 ? '${_relawanDistance!.toStringAsFixed(0)} m' : '${(_relawanDistance! / 1000).toStringAsFixed(1)} km'})'
          : '';
      currentDescription = (name != null && name.toString().trim().isNotEmpty)
          ? '${name.toString().trim()} sedang menuju lokasi Anda$distanceStr.'
          : 'Relawan telah menerima panggilan dan sedang menuju lokasi$distanceStr.';
    } else {
      currentDescription =
          'Sistem sedang mencarikan relawan terdekat ke lokasi Anda.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(14),
        border: AccessibleColors.cardBorder(isHighContrast),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isHighContrast ? 0.3 : 0.04,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alur Penanganan Darurat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AccessibleColors.textPrimary(isHighContrast),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isBatal
                      ? 'Dibatalkan'
                      : (_isSelesai
                          ? 'Selesai'
                          : (_isDitangani ? 'Menuju Lokasi' : 'Mencari Relawan')),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildStepNode(
                label: 'Sinyal',
                icon: CupertinoIcons.checkmark_alt,
                isDone: step1Done,
                isActive: false,
                isHighContrast: isHighContrast,
              ),
              Expanded(
                child: Container(
                  height: 2.5,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: (step2Done || step2Active)
                      ? tealColor
                      : (isHighContrast
                          ? const Color(0xFF4B5563)
                          : const Color(0xFFE5E7EB)),
                ),
              ),
              _buildStepNode(
                label: 'Relawan',
                icon: _isBatal
                    ? CupertinoIcons.xmark
                    : (step2Done
                        ? CupertinoIcons.checkmark_alt
                        : (step2Active
                            ? CupertinoIcons.car_detailed
                            : CupertinoIcons.arrow_right)),
                isDone: step2Done,
                isActive: step2Active,
                isHighContrast: isHighContrast,
              ),
              Expanded(
                child: Container(
                  height: 2.5,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: step3Done
                      ? tealColor
                      : (isHighContrast
                          ? const Color(0xFF4B5563)
                          : const Color(0xFFE5E7EB)),
                ),
              ),
              _buildStepNode(
                label: 'Selesai',
                icon: step3Done
                    ? CupertinoIcons.checkmark_alt
                    : CupertinoIcons.flag,
                isDone: step3Done,
                isActive: false,
                isHighContrast: isHighContrast,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isHighContrast
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isHighContrast
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.info_circle_fill,
                  size: 13,
                  color: tealColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    currentDescription,
                    style: TextStyle(
                      fontSize: 11,
                      color: AccessibleColors.textSecondary(isHighContrast),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required String label,
    required IconData icon,
    required bool isDone,
    required bool isActive,
    required bool isHighContrast,
  }) {
    Color nodeColor;
    Color nodeBgColor;

    if (isDone) {
      nodeColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
      nodeBgColor = isHighContrast
          ? const Color(0xFF004D40)
          : const Color(0xFFE0F2F1);
    } else if (isActive) {
      nodeColor = warningOrange;
      nodeBgColor = isHighContrast
          ? const Color(0xFF78350F)
          : const Color(0xFFFEF3C7);
    } else {
      nodeColor = const Color(0xFF9CA3AF);
      nodeBgColor = isHighContrast
          ? const Color(0xFF374151)
          : const Color(0xFFF3F4F6);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: nodeBgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: nodeColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: nodeColor, size: 13),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: (isDone || isActive) ? FontWeight.bold : FontWeight.w500,
            color: (isDone || isActive)
                ? AccessibleColors.textPrimary(isHighContrast)
                : AccessibleColors.textSecondary(isHighContrast),
          ),
        ),
      ],
    );
  }
}
