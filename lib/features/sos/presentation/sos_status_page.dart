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
        const SnackBar(content: Text('Nomor telepon relawan tidak tersedia.')),
      );
      return;
    }
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format nomor telepon relawan tidak valid.'),
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
          SnackBar(content: Text('Tidak dapat memanggil nomor $phone')),
        );
      }
    }
  }

  Future<void> _openWhatsAppVolunteer(String? phone, String? name) async {
    if (phone == null || phone.trim().isEmpty || phone == '-') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp relawan tidak tersedia.')),
      );
      return;
    }
    String clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format nomor WhatsApp relawan tidak valid.'),
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
          const SnackBar(content: Text('Gagal membuka aplikasi WhatsApp.')),
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
  }) {
    final fullUrl = _getRelawanPhotoUrl(photoUrl);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: isHighContrast
            ? const Color(0xFF004D40)
            : const Color(0xFFE0F2F1),
        shape: BoxShape.circle,
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF80CBC4)
              : primaryTeal.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: fullUrl != null
            ? Image.network(
                fullUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildInitialsFallback(name, isHighContrast),
              )
            : _buildInitialsFallback(name, isHighContrast),
      ),
    );
  }

  Widget _buildInitialsFallback(String name, bool isHighContrast) {
    final initials = _getInitials(name);
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 18,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighContrast
              ? const Color(0xFF80CBC4)
              : const Color(0xFFB2DFDB),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isHighContrast ? 0.3 : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? const Color(0xFF004D40)
                      : const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.shield_fill,
                      size: 13,
                      color: tealColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'RELAWAN PENANGGUNG JAWAB',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: tealColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Dalam Perjalanan',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isHighContrast
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildRelawanAvatar(
                name: name,
                photoUrl: photo?.toString(),
                isHighContrast: isHighContrast,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AccessibleColors.textPrimary(isHighContrast),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.location_solid,
                          size: 14,
                          color: warningOrange,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            distanceText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            thickness: 0.5,
            color: isHighContrast
                ? const Color(0xFF4B5563)
                : const Color(0xFFE5E7EB),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      AccessibilityService.instance.hapticLight();
                      _callVolunteer(phone);
                    },
                    icon: Icon(
                      CupertinoIcons.phone_fill,
                      size: 16,
                      color: tealColor,
                    ),
                    label: Text(
                      'Hubungi Relawan',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: tealColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: tealColor,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      AccessibilityService.instance.hapticLight();
                      _openWhatsAppVolunteer(phone, name);
                    },
                    icon: const Icon(
                      CupertinoIcons.chat_bubble_2_fill,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Chat WA',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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

        return Scaffold(
          backgroundColor: currentBg,
          appBar: AppBar(
            backgroundColor: currentBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: tealColor),
            leading: IconButton(
              icon: Icon(CupertinoIcons.back, color: tealColor),
              onPressed: () => context.pop(),
            ),
            centerTitle: false,
            titleSpacing: 0,
            title: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 24, height: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Status Keadaan Darurat',
                    style: TextStyle(
                      color: tealColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final scale =
                            (!_isSelesai && !_isBatal) ? _pulseAnimation.value : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: _statusColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _statusColor.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              _statusHeaderIcon,
                              color: Colors.white,
                              size: 52,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _statusHeaderTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusHeaderSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AccessibleColors.textSecondary(isHighContrast),
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_isDitangani) ...[
                    _buildAssignedRelawanCard(isHighContrast),
                    const SizedBox(height: 20),
                  ],
                  _buildTimelineCard(isHighContrast),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showEmergencyHotlinesModal(isHighContrast),
                    icon: const Icon(CupertinoIcons.headphones,
                        color: Colors.white, size: 18),
                    label: const Text(
                      'Hubungi Layanan Darurat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isSelesai || _isBatal)
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isBatal ? const Color(0xFF6B7280) : primaryTeal,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else ...[
                    SlideToCancelButton(
                      onCancelled: _cancelSos,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Geser ke kanan untuk membatalkan keadaan darurat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AccessibleColors.textSecondary(isHighContrast),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineCard(bool isHighContrast) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(16),
        border: AccessibleColors.cardBorder(isHighContrast),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isHighContrast ? 0.3 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alur Penanganan Darurat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AccessibleColors.textPrimary(isHighContrast),
            ),
          ),
          const SizedBox(height: 20),
          _buildTimelineStep(
            icon: CupertinoIcons.checkmark_alt,
            isCompleted: true,
            isActive: false,
            title: 'Sinyal & Lokasi Terkirim',
            description: 'Koordinat GPS Anda telah diterima oleh sistem server.',
            showConnector: true,
            isHighContrast: isHighContrast,
          ),
          _buildTimelineStep(
            icon: _isBatal
                ? CupertinoIcons.xmark
                : ((_isDitangani || _isSelesai)
                    ? CupertinoIcons.checkmark_alt
                    : CupertinoIcons.refresh),
            isCompleted: _isSelesai,
            isActive: _isDitangani && !_isBatal,
            title: _isBatal
                ? 'Pencarian Relawan Dibatalkan'
                : ((_isDitangani || _isSelesai)
                    ? 'Relawan Menuju Lokasi'
                    : 'Mencari Relawan Terdekat'),
            description: _isBatal
                ? 'Panggilan darurat telah dibatalkan.'
                : (_isDitangani
                    ? (_assignedRelawan?['name'] != null ||
                            _assignedRelawan?['nama'] != null
                        ? '${_assignedRelawan?['name'] ?? _assignedRelawan?['nama']} telah menerima panggilan dan sedang menuju lokasi${_relawanDistance != null ? ' (~${_relawanDistance!.toStringAsFixed(0)} m)' : ''}.'
                        : (_relawanDistance != null
                            ? 'Relawan telah menerima panggilan dan berjarak ${_relawanDistance!.toStringAsFixed(0)} m.'
                            : 'Relawan telah menerima panggilan dan sedang dalam perjalanan.'))
                    : (_isSelesai
                        ? 'Relawan telah tiba di lokasi kejadian.'
                        : 'Sistem sedang mencarikan relawan terdekat.')),
            showConnector: true,
            isHighContrast: isHighContrast,
          ),
          _buildTimelineStep(
            icon: _isBatal
                ? CupertinoIcons.xmark_circle
                : (_isSelesai
                    ? CupertinoIcons.checkmark_alt
                    : CupertinoIcons.flag),
            isCompleted: _isSelesai,
            isActive: false,
            title: _isBatal ? 'Panggilan Dibatalkan' : 'Bantuan Selesai',
            description: _isBatal
                ? 'Permintaan bantuan darurat telah dibatalkan.'
                : (_isSelesai
                    ? 'Proses penanganan darurat telah tuntas.'
                    : 'Menunggu penanganan selesai oleh relawan/tim medis.'),
            showConnector: false,
            isHighContrast: isHighContrast,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required bool isCompleted,
    required bool isActive,
    required String title,
    required String description,
    required bool showConnector,
    required bool isHighContrast,
  }) {
    Color stepColor;
    Color stepBgColor;

    if (isCompleted) {
      stepColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
      stepBgColor = isHighContrast
          ? const Color(0xFF004D40)
          : const Color(0xFFE0F2F1);
    } else if (isActive) {
      stepColor = warningOrange;
      stepBgColor = isHighContrast
          ? const Color(0xFF78350F)
          : const Color(0xFFFEF3C7);
    } else {
      stepColor = const Color(0xFF9CA3AF);
      stepBgColor = isHighContrast
          ? const Color(0xFF374151)
          : const Color(0xFFF3F4F6);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: stepBgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: stepColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: stepColor, size: 16),
              ),
              if (showConnector)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isCompleted
                        ? (isHighContrast
                            ? const Color(0xFF80CBC4)
                            : primaryTeal.withValues(alpha: 0.4))
                        : (isHighContrast
                            ? const Color(0xFF4B5563)
                            : const Color(0xFFE5E7EB)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showConnector ? 20.0 : 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: (isCompleted || isActive)
                          ? AccessibleColors.textPrimary(isHighContrast)
                          : AccessibleColors.textSecondary(isHighContrast),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AccessibleColors.textSecondary(isHighContrast),
                      height: 1.35,
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
}
