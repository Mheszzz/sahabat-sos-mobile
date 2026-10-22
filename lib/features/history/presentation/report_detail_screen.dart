import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geocoding/geocoding.dart';

import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/core/theme/accessible_colors.dart';
import '../data/datasources/history_remote_data_source.dart';
import 'history_screen.dart';

class ReportDetailScreen extends StatefulWidget {
  final HistoryItem item;

  const ReportDetailScreen({super.key, required this.item});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color primaryLightTeal = Color(0xFFE0F2F1);

  final _historyDataSource = sl<HistoryRemoteDataSource>();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlayerInitialized = false;
  bool _isCompleted = false;
  String? _localAudioPath;

  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _completeSub;

  // Fresh data from API
  String? _freshStatus;
  String? _freshNomorKasus;
  String? _userRole;
  String? _readableAddress;
  String? _freshImageUrl;
  String? _freshAudioUrl;
  String? _freshDescription;
  String? _freshOfficerInfo;
  String? _freshLocation;
  double? _freshLatitude;
  double? _freshLongitude;
  Map<String, dynamic>? _freshDeviceInfo;

  String get _effectiveNomorKasus =>
      _freshNomorKasus ??
      widget.item.nomorKasus ??
      (widget.item.type == HistoryType.sos
          ? 'SOS-${widget.item.id}'
          : 'LP-${widget.item.id}');
  String? get _effectiveImageUrl => _freshImageUrl ?? widget.item.imageUrl;
  String? get _effectiveAudioUrl => _freshAudioUrl ?? widget.item.audioUrl;
  String? get _effectiveDescription =>
      _freshDescription ?? widget.item.description;
  String? get _effectiveOfficerInfo =>
      _freshOfficerInfo ?? widget.item.officerInfo;
  double? get _effectiveLatitude => _freshLatitude ?? widget.item.latitude;
  double? get _effectiveLongitude => _freshLongitude ?? widget.item.longitude;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _fetchDetailFromApi();
    _fetchUserRole();
    _resolveAddress();
  }

  Future<void> _resolveAddress() async {
    final lat = _effectiveLatitude;
    final lng = _effectiveLongitude;
    if (lat != null && lng != null) {
      try {
        final placemarks =
            await Geocoding().placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addressList = [
            place.subLocality,
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ].where((e) => e != null && e.isNotEmpty).toList();
          final address = addressList.join(', ');
          if (address.isNotEmpty && mounted) {
            setState(() {
              _readableAddress = address;
            });
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _fetchUserRole() async {
    try {
      final role = await _historyDataSource.getUserRole();
      if (mounted && role != null) {
        setState(() {
          _userRole = role;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDetailFromApi() async {
    try {
      final isSos = widget.item.type == HistoryType.sos;
      final data = await _historyDataSource.getDetail(
        id: widget.item.id,
        isSos: isSos,
      );

      if (!mounted) return;

      final statusVal =
          (data['status'] ?? data['status_sos'])?.toString().toLowerCase();

      // Foto URL
      String? photo =
          (data['foto_laporan_url'] ?? data['foto_sos_url'] ?? data['foto_url'])
              ?.toString();
      if (photo == null &&
          (data['foto_laporan'] ?? data['foto_sos']) != null) {
        final raw = (data['foto_laporan'] ?? data['foto_sos']).toString();
        photo = raw.startsWith('http')
            ? raw
            : '${ApiConstants.storageUrl}/${raw.replaceFirst('public/', '')}';
      }

      // Audio URL
      String? audio =
          (data['rekam_suara_url'] ?? data['audio_sos_url'] ?? data['audio_url'])
              ?.toString();
      if (audio == null &&
          (data['rekam_suara'] ?? data['rekam_suara_sos']) != null) {
        final raw =
            (data['rekam_suara'] ?? data['rekam_suara_sos']).toString();
        audio = raw.startsWith('http')
            ? raw
            : '${ApiConstants.storageUrl}/${raw.replaceFirst('public/', '')}';
      }

      // Officer / Relawan
      String? officer;
      if (data['relawan'] != null && data['relawan'] is Map) {
        officer = 'Relawan ${data['relawan']['name']}';
      }

      // Description
      final desc = data['deskripsi']?.toString() ??
          data['deskripsi_sos']?.toString() ??
          (data['alasan_batal'] != null
              ? 'Alasan Batal: ${data['alasan_batal']}'
              : null);

      // Location
      String? loc;
      if (data['lokasi'] is Map) {
        loc = data['lokasi']['alamat']?.toString();
      } else {
        loc = (data['lokasi_laporan'] ??
                data['lokasi_sos'] ??
                data['lokasi'] ??
                data['lokasi_user'])
            ?.toString();
      }

      // Coordinates
      double? lat;
      if (data['latitude'] != null) {
        lat = (data['latitude'] is num)
            ? (data['latitude'] as num).toDouble()
            : double.tryParse(data['latitude'].toString());
      } else if (data['lokasi'] is Map && data['lokasi']['latitude'] != null) {
        lat = (data['lokasi']['latitude'] is num)
            ? (data['lokasi']['latitude'] as num).toDouble()
            : double.tryParse(data['lokasi']['latitude'].toString());
      }

      double? lng;
      if (data['longitude'] != null) {
        lng = (data['longitude'] is num)
            ? (data['longitude'] as num).toDouble()
            : double.tryParse(data['longitude'].toString());
      } else if (data['lokasi'] is Map && data['lokasi']['longitude'] != null) {
        lng = (data['lokasi']['longitude'] is num)
            ? (data['lokasi']['longitude'] as num).toDouble()
            : double.tryParse(data['lokasi']['longitude'].toString());
      }

      Map<String, dynamic>? devInfo;
      if (data['device_info'] != null && data['device_info'] is Map) {
        devInfo = Map<String, dynamic>.from(data['device_info'] as Map);
      } else if (data['battery_level'] != null ||
          data['signal_strength'] != null) {
        devInfo = {
          'battery_level': data['battery_level'],
          'signal_strength': data['signal_strength'],
        };
      }

      final nomorKasus = data['nomor_kasus']?.toString();

      setState(() {
        _freshStatus = statusVal;
        if (nomorKasus != null && nomorKasus.isNotEmpty) {
          _freshNomorKasus = nomorKasus;
        }
        if (photo != null) _freshImageUrl = photo;
        if (audio != null) {
          _freshAudioUrl = audio;
          if (_playerStateSub == null) {
            _initAudioPlayer();
          }
        }
        if (desc != null && desc.isNotEmpty) _freshDescription = desc;
        if (officer != null) _freshOfficerInfo = officer;
        if (loc != null) _freshLocation = loc;
        if (lat != null) _freshLatitude = lat;
        if (lng != null) _freshLongitude = lng;
        if (devInfo != null) _freshDeviceInfo = devInfo;
      });

      if (lat != null && lng != null && _readableAddress == null) {
        unawaited(_resolveAddress());
      }
    } catch (e) {
      debugPrint('Gagal fetch detail laporan: $e');
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CupertinoActivityIndicator(radius: 16)),
      ),
    );

    try {
      final isSos = widget.item.type == HistoryType.sos;
      await _historyDataSource.updateStatus(
        id: widget.item.id,
        isSos: isSos,
        status: newStatus,
      );

      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status kasus berhasil diperbarui.'),
            backgroundColor: primaryTeal,
          ),
        );
        unawaited(_fetchDetailFromApi());
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _initAudioPlayer() {
    final audio = _effectiveAudioUrl;
    if (audio != null && _playerStateSub == null) {
      _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
            if (state == PlayerState.playing ||
                state == PlayerState.paused ||
                state == PlayerState.completed) {
              _isLoadingAudio = false;
            }
          });
        }
      });

      _durationSub = _audioPlayer.onDurationChanged.listen((newDuration) {
        if (mounted) {
          setState(() {
            _duration = newDuration;
            if (newDuration.inMilliseconds > 0) _isLoadingAudio = false;
          });
        }
      });

      _positionSub = _audioPlayer.onPositionChanged.listen((newPosition) {
        if (mounted) {
          setState(() {
            _position = newPosition;
          });
        }
      });

      _completeSub = _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _isLoadingAudio = false;
            _position = Duration.zero;
            _isCompleted = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    final audioUrl = _effectiveAudioUrl;
    if (audioUrl == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        setState(() {
          _isLoadingAudio = true;
        });

        if (!_isPlayerInitialized) {
          if (_localAudioPath == null) {
            final tempDir = await getTemporaryDirectory();
            String ext = 'wav';
            try {
              final uriPath = Uri.parse(audioUrl).path;
              if (uriPath.contains('.')) {
                ext = uriPath.split('.').last;
              }
            } catch (_) {}
            final filePath =
                '${tempDir.path}/temp_audio_${widget.item.id}.$ext';

            await _historyDataSource.downloadAudio(
              url: audioUrl,
              savePath: filePath,
            );
            _localAudioPath = filePath;
          }

          _isCompleted = false;
          await _audioPlayer.play(DeviceFileSource(_localAudioPath!));
          _isPlayerInitialized = true;
        } else {
          if (_isCompleted) {
            await _audioPlayer.play(DeviceFileSource(_localAudioPath!));
            _isCompleted = false;
          } else {
            await _audioPlayer.resume();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memutar pesan suara.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  ({Color bg, Color text}) _getStatusColors(String status, [bool isHighContrast = false]) {
    status = status.toLowerCase();
    if (status == 'selesai') {
      return (
        bg: isHighContrast ? const Color(0xFF1E3A34) : primaryLightTeal,
        text: isHighContrast ? const Color(0xFF80CBC4) : primaryTeal,
      );
    }
    if (status == 'ditangani' || status == 'proses') {
      return (
        bg: isHighContrast ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
        text: isHighContrast ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
      );
    }
    if (status == 'dibatalkan' || status == 'batal') {
      return (
        bg: isHighContrast ? const Color(0xFF262626) : const Color(0xFFF3F4F6),
        text: isHighContrast ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280),
      );
    }
    return (
      bg: isHighContrast ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
      text: isHighContrast ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
    );
  }

  String _getDisplayStatus(String status) {
    status = status.toLowerCase();
    if (status == 'batal' || status == 'dibatalkan') return 'DIBATALKAN';
    if (status == 'selesai') return 'SELESAI';
    if (status == 'ditangani' || status == 'proses') return 'SEDANG DITANGANI';
    if (status == 'aktif' || status == 'menunggu' || status == 'belum ditangani') {
      return 'MENUNGGU RELAWAN';
    }
    return status.toUpperCase();
  }

  IconData _getStatusIcon(String status) {
    status = status.toLowerCase();
    if (status == 'selesai') return CupertinoIcons.checkmark_circle_fill;
    if (status == 'ditangani' || status == 'proses') {
      return CupertinoIcons.wrench_fill;
    }
    if (status == 'dibatalkan' || status == 'batal') {
      return CupertinoIcons.xmark_circle_fill;
    }
    return CupertinoIcons.exclamationmark_triangle_fill;
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  CupertinoIcons.xmark_rectangle,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    Color? color,
    Border? border,
    bool isHighContrast = false,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AccessibleColors.cardBackground(isHighContrast),
        borderRadius: BorderRadius.circular(16),
        border: border ?? AccessibleColors.cardBorder(isHighContrast),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isHighContrast ? 0.3 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDeviceInfoCard(bool isHighContrast) {
    if (_freshDeviceInfo == null) return const SizedBox.shrink();

    final tealColor = isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;
    final mobile = _freshDeviceInfo!['mobile'] is Map
        ? Map<String, dynamic>.from(_freshDeviceInfo!['mobile'] as Map)
        : null;
    final tuya = _freshDeviceInfo!['tuya'] is Map
        ? Map<String, dynamic>.from(_freshDeviceInfo!['tuya'] as Map)
        : null;

    final batteryLevel =
        mobile?['battery_level'] ?? _freshDeviceInfo!['battery_level'];
    final isCharging = mobile?['is_charging'] ?? false;
    final isCritical =
        batteryLevel != null && (batteryLevel as num) < 20 && !isCharging;
    final modelName =
        mobile?['model'] ?? _freshDeviceInfo!['device_model'] ?? 'Ponsel Korban';
    final signal =
        mobile?['signal_strength'] ?? _freshDeviceInfo!['signal_strength'] ?? '4G';

    return _buildCard(
      isHighContrast: isHighContrast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isHighContrast
                      ? const Color(0xFF1E3A34)
                      : primaryLightTeal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.device_phone_portrait,
                  color: tealColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Telemetri Perangkat Korban',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AccessibleColors.textPrimary(isHighContrast),
                      ),
                    ),
                    Text(
                      tuya != null
                          ? 'Ponsel & Tombol Darurat Tuya'
                          : 'Ponsel Mobile Korban',
                      style: TextStyle(
                        fontSize: 12,
                        color: AccessibleColors.textSecondary(isHighContrast),
                      ),
                    ),
                  ],
                ),
              ),
              if (tuya != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHighContrast
                        ? const Color(0xFF1E3A34)
                        : primaryLightTeal,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isHighContrast
                          ? const Color(0xFF80CBC4)
                          : const Color(0xFFB2DFDB),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.antenna_radiowaves_left_right,
                        size: 12,
                        color: tealColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tuya IoT',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: tealColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (isCritical) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isHighContrast
                    ? const Color(0xFF450A0A)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHighContrast
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFFCA5A5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    color: Color(0xFFDC2626),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Baterai HP Korban Kritis ($batteryLevel%) - Segera respon!',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isHighContrast
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              color: isHighContrast
                  ? const Color(0xFF374151)
                  : const Color(0xFFF3F4F6),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildDeviceStatTile(
                  icon: isCharging
                      ? CupertinoIcons.battery_charging
                      : CupertinoIcons.battery_25_percent,
                  label: 'Baterai HP',
                  value: batteryLevel != null ? '$batteryLevel%' : '—',
                  subValue: isCharging ? 'Charging' : 'Discharge',
                  color: (batteryLevel != null && (batteryLevel as num) < 20)
                      ? const Color(0xFFDC2626)
                      : ((batteryLevel != null && (batteryLevel as num) < 50)
                          ? const Color(0xFFD97706)
                          : tealColor),
                  isHighContrast: isHighContrast,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: isHighContrast
                    ? const Color(0xFF374151)
                    : const Color(0xFFE5E7EB),
              ),
              Expanded(
                child: _buildDeviceStatTile(
                  icon: CupertinoIcons.wifi,
                  label: 'Sinyal HP',
                  value: signal.toString(),
                  subValue: 'Jaringan Seluler',
                  color: tealColor,
                  isHighContrast: isHighContrast,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: isHighContrast
                    ? const Color(0xFF374151)
                    : const Color(0xFFE5E7EB),
              ),
              Expanded(
                child: _buildDeviceStatTile(
                  icon: CupertinoIcons.device_phone_portrait,
                  label: 'Perangkat',
                  value: modelName.toString(),
                  subValue: mobile?['os_version']?.toString() ?? 'Android',
                  color: AccessibleColors.textSecondary(isHighContrast),
                  isHighContrast: isHighContrast,
                ),
              ),
            ],
          ),
          if (tuya != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isHighContrast
                    ? const Color(0xFF1E2430)
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHighContrast
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.antenna_radiowaves_left_right,
                    size: 18,
                    color: tealColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tuya['device_name']?.toString() ?? 'Tombol Fisik Tuya',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AccessibleColors.textPrimary(isHighContrast),
                          ),
                        ),
                        Text(
                          'Baterai IoT: ${tuya['battery_level'] ?? 'Normal'}% • Sinyal: ${tuya['signal_strength'] ?? 'Bagus'}',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                AccessibleColors.textSecondary(isHighContrast),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isHighContrast
                          ? const Color(0xFF1E3A34)
                          : primaryLightTeal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tuya['trigger_type']?.toString() ?? 'Tombol Fisik',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: tealColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceStatTile({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    required Color color,
    bool isHighContrast = false,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AccessibleColors.textSecondary(isHighContrast),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AccessibleColors.textPrimary(isHighContrast),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9.5,
            color: AccessibleColors.textSecondary(isHighContrast),
          ),
        ),
      ],
    );
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
        final currentBg =
            isHighContrast ? Colors.black : const Color(0xFFF8FAFC);
        final tealColor =
            isHighContrast ? const Color(0xFF80CBC4) : primaryTeal;

        final isSos = widget.item.type == HistoryType.sos;
        final detailTitle = isSos ? 'Detail Panggilan SOS' : 'Detail Laporan';

        final statusString = _freshStatus ??
            (widget.item.status == HistoryStatus.selesai
                ? 'selesai'
                : widget.item.status == HistoryStatus.ditangani
                    ? 'ditangani'
                    : widget.item.status == HistoryStatus.dibatalkan
                        ? 'dibatalkan'
                        : 'aktif');

        final statusColors = _getStatusColors(statusString, isHighContrast);
        final statusIcon = _getStatusIcon(statusString);

        final hasImage = _effectiveImageUrl != null &&
            _effectiveImageUrl!.isNotEmpty &&
            !_effectiveImageUrl!.endsWith('null');

        final lat = _effectiveLatitude;
        final lng = _effectiveLongitude;

        final currentSosVal = [
          'belum ditangani',
          'ditangani',
          'selesai',
          'batal',
        ].contains(statusString)
            ? statusString
            : (statusString == 'aktif' ? 'belum ditangani' : 'belum ditangani');

        final currentLaporanVal = [
          'menunggu',
          'proses',
          'selesai',
          'dibatalkan',
        ].contains(statusString)
            ? statusString
            : (statusString == 'aktif' ? 'menunggu' : 'menunggu');

        return Scaffold(
          backgroundColor: currentBg,
          appBar: AppBar(
            backgroundColor: currentBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleSpacing: 0,
            iconTheme: IconThemeData(color: tealColor),
            leading: IconButton(
              icon: Icon(CupertinoIcons.back, color: tealColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 24, height: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    detailTitle,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title and Status Card
                  _buildCard(
                    isHighContrast: isHighContrast,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AccessibleColors.textPrimary(
                                      isHighContrast),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Nomor Kasus: $_effectiveNomorKasus',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AccessibleColors.textSecondary(
                                      isHighContrast),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColors.bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isHighContrast
                                  ? statusColors.text
                                  : Colors.transparent,
                              width: isHighContrast ? 1.2 : 0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon,
                                  color: statusColors.text, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                _getDisplayStatus(statusString),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Volunteer / Admin Status Controls
                  if (_userRole == 'relawan' || _userRole == 'admin') ...[
                    _buildCard(
                      isHighContrast: isHighContrast,
                      child: Row(
                        children: [
                          Text(
                            isSos ? 'Status Penanganan:' : 'Status Laporan:',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: tealColor,
                            ),
                          ),
                          const Spacer(),
                          DropdownButton<String>(
                            value: isSos ? currentSosVal : currentLaporanVal,
                            dropdownColor: isHighContrast
                                ? const Color(0xFF1E2430)
                                : Colors.white,
                            underline: const SizedBox.shrink(),
                            icon: Icon(CupertinoIcons.chevron_down,
                                color: tealColor, size: 16),
                            items: (isSos
                                    ? const [
                                        'belum ditangani',
                                        'ditangani',
                                        'selesai',
                                        'batal',
                                      ]
                                    : const [
                                        'menunggu',
                                        'proses',
                                        'selesai',
                                        'dibatalkan',
                                      ])
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AccessibleColors.textPrimary(
                                            isHighContrast),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null && val != statusString) {
                                _updateStatus(val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Attached Photo Card
                  if (hasImage) ...[
                    _buildCard(
                      isHighContrast: isHighContrast,
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 220,
                              color: Colors.black,
                              child: Image.network(
                                _effectiveImageUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: isHighContrast
                                      ? const Color(0xFF1E2430)
                                      : const Color(0xFFF3F4F6),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.xmark_rectangle,
                                        size: 40,
                                        color: AccessibleColors.textSecondary(
                                            isHighContrast),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Foto lampiran tidak dapat dimuat',
                                        style: TextStyle(
                                          color: AccessibleColors
                                              .textSecondary(isHighContrast),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Material(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(30),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(30),
                                  onTap: () => _showFullScreenImage(
                                    context,
                                    _effectiveImageUrl!,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      CupertinoIcons
                                          .arrow_up_left_arrow_down_right,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Time, Location, and Map Card
                  _buildCard(
                    isHighContrast: isHighContrast,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isHighContrast
                                    ? const Color(0xFF1E3A34)
                                    : primaryLightTeal,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                CupertinoIcons.calendar,
                                color: tealColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSos ? 'Waktu Kejadian' : 'Waktu Laporan',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AccessibleColors.textSecondary(
                                          isHighContrast),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.item.dateTime,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: AccessibleColors.textPrimary(
                                          isHighContrast),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                            height: 1,
                            color: isHighContrast
                                ? const Color(0xFF374151)
                                : const Color(0xFFF3F4F6),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isHighContrast
                                    ? const Color(0xFF450A0A)
                                    : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                CupertinoIcons.location_solid,
                                color: Color(0xFFDC2626),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lokasi Koordinat',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AccessibleColors.textSecondary(
                                          isHighContrast),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _readableAddress ??
                                        _freshLocation ??
                                        widget.item.location,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AccessibleColors.textPrimary(
                                          isHighContrast),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (lat != null && lng != null) ...[
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(lat, lng),
                                  initialZoom: 16.0,
                                  interactionOptions:
                                      const InteractionOptions(
                                    flags: InteractiveFlag.none,
                                  ),
                                ),
                                children: [
                                  ColorFiltered(
                                    colorFilter: isHighContrast
                                        ? const ColorFilter.matrix([
                                            -1, 0, 0, 0, 255,
                                            0, -1, 0, 0, 255,
                                            0, 0, -1, 0, 255,
                                            0, 0, 0, 1, 0,
                                          ])
                                        : const ColorFilter.mode(
                                            Colors.transparent,
                                            BlendMode.multiply,
                                          ),
                                    child: TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.example.sahabat_sos_mobile',
                                    ),
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(lat, lng),
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          CupertinoIcons.location_solid,
                                          color: Color(0xFFDC2626),
                                          size: 38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Device Telemetry Card (Kasus SOS)
                  if (isSos && _freshDeviceInfo != null) ...[
                    _buildDeviceInfoCard(isHighContrast),
                    const SizedBox(height: 12),
                  ],

                  // Officer Info Card
                  if (_effectiveOfficerInfo != null) ...[
                    _buildCard(
                      isHighContrast: isHighContrast,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: tealColor,
                            radius: 20,
                            child: const Icon(
                              CupertinoIcons.person_fill,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Petugas / Relawan Pendamping',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AccessibleColors.textSecondary(
                                        isHighContrast),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _effectiveOfficerInfo!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AccessibleColors.textPrimary(
                                        isHighContrast),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Description Card
                  if (_effectiveDescription != null &&
                      _effectiveDescription!.isNotEmpty) ...[
                    _buildCard(
                      isHighContrast: isHighContrast,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.doc_text_fill,
                                color: tealColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Keterangan & Catatan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: AccessibleColors.textPrimary(
                                      isHighContrast),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _effectiveDescription!,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: AccessibleColors.textPrimary(
                                  isHighContrast),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Audio Recording Card
                  if (_effectiveAudioUrl != null) ...[
                    _buildCard(
                      isHighContrast: isHighContrast,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _isLoadingAudio ? null : _togglePlayPause,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: tealColor,
                                shape: BoxShape.circle,
                              ),
                              child: _isLoadingAudio
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CupertinoActivityIndicator(
                                        color: Colors.white,
                                        radius: 10,
                                      ),
                                    )
                                  : Icon(
                                      _isPlaying
                                          ? CupertinoIcons.pause_fill
                                          : CupertinoIcons.play_fill,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pesan Suara Darurat',
                                  style: TextStyle(
                                    color: AccessibleColors.textPrimary(
                                        isHighContrast),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      _formatDuration(_position),
                                      style: TextStyle(
                                        color: AccessibleColors
                                            .textSecondary(isHighContrast),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 3,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                            enabledThumbRadius: 6,
                                          ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                            overlayRadius: 12,
                                          ),
                                          activeTrackColor: tealColor,
                                          inactiveTrackColor: isHighContrast
                                              ? const Color(0xFF4B5563)
                                              : const Color(0xFFE5E7EB),
                                          thumbColor: tealColor,
                                          overlayColor:
                                              tealColor.withValues(alpha: 0.2),
                                        ),
                                        child: Slider(
                                          min: 0.0,
                                          max: _duration.inSeconds.toDouble() >
                                                  0
                                              ? _duration.inSeconds.toDouble()
                                              : 1.0,
                                          value: (_position.inSeconds
                                                      .toDouble() <=
                                                  _duration.inSeconds
                                                      .toDouble())
                                              ? _position.inSeconds.toDouble()
                                              : 0.0,
                                          onChanged: (value) async {
                                            final position = Duration(
                                              seconds: value.toInt(),
                                            );
                                            await _audioPlayer.seek(position);
                                          },
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(_duration),
                                      style: TextStyle(
                                        color: AccessibleColors
                                            .textSecondary(isHighContrast),
                                        fontSize: 11.5,
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
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
