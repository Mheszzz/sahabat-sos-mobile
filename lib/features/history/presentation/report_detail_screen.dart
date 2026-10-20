import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'history_screen.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:geocoding/geocoding.dart';

class ReportDetailScreen extends StatefulWidget {
  final HistoryItem item;

  const ReportDetailScreen({super.key, required this.item});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlayerInitialized = false;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _completeSub;

  // Fresh data from API
  String? _freshStatus;
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

  String? get _effectiveImageUrl => _freshImageUrl ?? widget.item.imageUrl;
  String? get _effectiveAudioUrl => _freshAudioUrl ?? widget.item.audioUrl;
  String? get _effectiveDescription => _freshDescription ?? widget.item.description;
  String? get _effectiveOfficerInfo => _freshOfficerInfo ?? widget.item.officerInfo;
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
        final placemarks = await Geocoding().placemarkFromCoordinates(lat, lng);
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
      } catch (e) {
        // Fallback
      }
    }
  }

  Future<void> _fetchUserRole() async {
    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token == null) return;
      final response = await sl<Dio>().get(
        ApiConstants.me,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _userRole = response.data['data']['role']?.toString().toLowerCase();
        });
      }
    } catch (e) {
      debugPrint('Gagal fetch user role: $e');
    }
  }

  /// Fetch fresh detail from API to get latest status, officer info, etc.
  Future<void> _fetchDetailFromApi() async {
    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final url = widget.item.type == HistoryType.sos
          ? ApiConstants.sosDetail(widget.item.id)
          : ApiConstants.laporanDetail(widget.item.id);

      final response = await sl<Dio>().get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data['data'];
        if (data != null && data is Map) {
          final statusVal = (data['status'] ?? data['status_sos'])?.toString().toLowerCase();

          // Foto URL
          String? photo = (data['foto_laporan_url'] ?? data['foto_sos_url'] ?? data['foto_url'])?.toString();
          if (photo == null && (data['foto_laporan'] ?? data['foto_sos']) != null) {
            final raw = (data['foto_laporan'] ?? data['foto_sos']).toString();
            photo = raw.startsWith('http') ? raw : '${ApiConstants.storageUrl}/${raw.replaceFirst('public/', '')}';
          }

          // Audio URL
          String? audio = (data['rekam_suara_url'] ?? data['audio_sos_url'] ?? data['audio_url'])?.toString();
          if (audio == null && (data['rekam_suara'] ?? data['rekam_suara_sos']) != null) {
            final raw = (data['rekam_suara'] ?? data['rekam_suara_sos']).toString();
            audio = raw.startsWith('http') ? raw : '${ApiConstants.storageUrl}/${raw.replaceFirst('public/', '')}';
          }

          // Officer / Relawan
          String? officer;
          if (data['relawan'] != null && data['relawan'] is Map) {
            officer = 'Relawan ${data['relawan']['name']}';
          }

          // Description
          final desc = data['deskripsi']?.toString() ??
              data['deskripsi_sos']?.toString() ??
              (data['alasan_batal'] != null ? 'Alasan Batal: ${data['alasan_batal']}' : null);

          // Location
          String? loc;
          if (data['lokasi'] is Map) {
            loc = data['lokasi']['alamat']?.toString();
          } else {
            loc = (data['lokasi_laporan'] ?? data['lokasi_sos'] ?? data['lokasi'] ?? data['lokasi_user'])?.toString();
          }

          // Coordinates
          double? lat;
          if (data['latitude'] != null) {
            lat = (data['latitude'] is num) ? (data['latitude'] as num).toDouble() : double.tryParse(data['latitude'].toString());
          } else if (data['lokasi'] is Map && data['lokasi']['latitude'] != null) {
            lat = (data['lokasi']['latitude'] is num) ? (data['lokasi']['latitude'] as num).toDouble() : double.tryParse(data['lokasi']['latitude'].toString());
          }

          double? lng;
          if (data['longitude'] != null) {
            lng = (data['longitude'] is num) ? (data['longitude'] as num).toDouble() : double.tryParse(data['longitude'].toString());
          } else if (data['lokasi'] is Map && data['lokasi']['longitude'] != null) {
            lng = (data['lokasi']['longitude'] is num) ? (data['lokasi']['longitude'] as num).toDouble() : double.tryParse(data['lokasi']['longitude'].toString());
          }

          Map<String, dynamic>? devInfo;
          if (data['device_info'] != null && data['device_info'] is Map) {
            devInfo = Map<String, dynamic>.from(data['device_info'] as Map);
          } else if (data['battery_level'] != null || data['signal_strength'] != null) {
            devInfo = {
              'battery_level': data['battery_level'],
              'signal_strength': data['signal_strength'],
            };
          }

          setState(() {
            _freshStatus = statusVal;
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
            _resolveAddress();
          }
        }
      }
    } catch (e) {
      debugPrint('Gagal fetch detail laporan: $e');
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CupertinoActivityIndicator(radius: 16)),
      );

      final url = widget.item.type == HistoryType.sos
          ? ApiConstants.sosStatusUpdate(widget.item.id)
          : ApiConstants.laporanStatus(widget.item.id);

      final payload = widget.item.type == HistoryType.sos
          ? {'status_sos': newStatus}
          : {'status': newStatus};

      final response = await sl<Dio>().put(
        url,
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (mounted) Navigator.pop(context); // close loading

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status berhasil diperbarui')),
        );
        _fetchDetailFromApi(); // refresh
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Gagal update status: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memperbarui status: $e')));
      }
    }
  }

  bool _isCompleted = false;

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

  String? _localAudioPath;

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
            String ext = 'm4a';
            try {
              final uriPath = Uri.parse(audioUrl).path;
              if (uriPath.contains('.')) {
                ext = uriPath.split('.').last;
              }
            } catch (_) {}
            final filePath = '${tempDir.path}/temp_audio_${widget.item.id}.$ext';

            if (await File(filePath).exists()) {
              _localAudioPath = filePath;
            } else {
              await sl<Dio>().download(audioUrl, filePath);
              _localAudioPath = filePath;
            }
          }

          _isCompleted = false;
          await _audioPlayer.play(DeviceFileSource(_localAudioPath!));
          _isPlayerInitialized = true;
        } else {
          if (_isCompleted) {
            // Jalankan ulang dari awal jika sudah selesai
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
      }
      debugPrint("Gagal memutar audio: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memutar pesan suara.')),
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

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status == 'selesai') return Colors.green;
    if (status == 'ditangani') return Colors.orange;
    if (status == 'dibatalkan' || status == 'batal') return Colors.grey;
    return Colors.red;
  }

  String _getDisplayStatus(String status) {
    status = status.toLowerCase();
    if (status == 'batal' || status == 'dibatalkan') return 'DIBATALKAN';
    if (status == 'selesai') return 'SELESAI';
    if (status == 'ditangani') return 'SEDANG DITANGANI';
    if (status == 'aktif') return 'MENUNGGU RELAWAN';
    return status.toUpperCase();
  }

  IconData _getStatusIcon(String status) {
    status = status.toLowerCase();
    if (status == 'selesai') return CupertinoIcons.checkmark_circle_fill;
    if (status == 'ditangani') return CupertinoIcons.wrench_fill;
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

  Widget _buildGlassContainer({
    required Widget child,
    BorderRadius? borderRadius,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    if (_freshDeviceInfo == null) return const SizedBox.shrink();

    final mobile = _freshDeviceInfo!['mobile'] is Map
        ? Map<String, dynamic>.from(_freshDeviceInfo!['mobile'] as Map)
        : null;
    final tuya = _freshDeviceInfo!['tuya'] is Map
        ? Map<String, dynamic>.from(_freshDeviceInfo!['tuya'] as Map)
        : null;

    final batteryLevel = mobile?['battery_level'] ?? _freshDeviceInfo!['battery_level'];
    final isCharging = mobile?['is_charging'] ?? false;
    final isCritical = batteryLevel != null && (batteryLevel as num) < 20 && !isCharging;
    final modelName = mobile?['model'] ?? _freshDeviceInfo!['device_model'] ?? 'Ponsel Korban';
    final signal = mobile?['signal_strength'] ?? _freshDeviceInfo!['signal_strength'] ?? '4G';

    return _buildGlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    CupertinoIcons.device_phone_portrait,
                    color: primaryTeal,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Telemetri Perangkat Korban',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        tuya != null ? 'Ponsel & Tombol IoT Tuya' : 'Ponsel Mobile Korban',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tuya != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.radiowaves_right, size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Tuya IoT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
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
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Baterai HP Korban Kritis ($batteryLevel%) - Segera hubungi sebelum kontak terputus!',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildDeviceStatTile(
                    icon: isCharging ? CupertinoIcons.battery_charging : CupertinoIcons.battery_25_percent,
                    label: 'Baterai HP',
                    value: batteryLevel != null ? '$batteryLevel%' : '—',
                    subValue: isCharging ? 'Charging' : 'Discharge',
                    color: (batteryLevel != null && (batteryLevel as num) < 20)
                        ? Colors.red
                        : ((batteryLevel != null && (batteryLevel as num) < 50) ? Colors.orange : Colors.green),
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.grey.shade200),
                Expanded(
                  child: _buildDeviceStatTile(
                    icon: CupertinoIcons.wifi,
                    label: 'Sinyal HP',
                    value: signal.toString(),
                    subValue: 'Jaringan Seluler',
                    color: primaryTeal,
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.grey.shade200),
                Expanded(
                  child: _buildDeviceStatTile(
                    icon: CupertinoIcons.device_phone_portrait,
                    label: 'Perangkat',
                    value: modelName.toString(),
                    subValue: mobile?['os_version']?.toString() ?? 'Android',
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
            if (tuya != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FDF9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 18, color: primaryTeal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tuya['device_name']?.toString() ?? 'Tombol Fisik Tuya',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Baterai IoT: ${tuya['battery_level'] ?? 'Normal'}% • Sinyal: ${tuya['signal_strength'] ?? 'Bagus'}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.teal.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tuya['trigger_type']?.toString() ?? 'Tombol Fisik',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: primaryTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceStatTile({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.black45,
          ),
        ),
      ],
    );
  }

  static const Color primaryTeal = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    final statusString =
        _freshStatus ?? widget.item.status.toString().split('.').last;
    final statusColor = _getStatusColor(statusString);
    final statusIcon = _getStatusIcon(statusString);
    final hasImage = _effectiveImageUrl != null;
    final isSos = widget.item.type == HistoryType.sos;
    final detailTitle = isSos ? 'Detail Kasus SOS' : 'Detail Laporan';

    String currentSosVal = (statusString == 'aktif' ? 'belum ditangani' : (statusString == 'dibatalkan' ? 'batal' : statusString));
    if (!const ['belum ditangani', 'ditangani', 'selesai', 'batal'].contains(currentSosVal)) {
      currentSosVal = 'belum ditangani';
    }

    String currentLaporanVal = (statusString == 'aktif' ? 'menunggu' : (statusString == 'batal' ? 'dibatalkan' : statusString));
    if (!const ['menunggu', 'proses', 'selesai', 'dibatalkan'].contains(currentLaporanVal)) {
      currentLaporanVal = 'menunggu';
    }

    final lat = _effectiveLatitude;
    final lng = _effectiveLongitude;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: primaryTeal),
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 24, height: 24),
            const SizedBox(width: 8),
            Text(
              detailTitle,
              style: const TextStyle(
                color: primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        color: const Color(0xFFF5F6F8),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status
                _buildGlassContainer(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.item.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                _getDisplayStatus(statusString),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_userRole == 'relawan' || _userRole == 'admin') ...[
                  _buildGlassContainer(
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            isSos ? 'Update Status SOS:' : 'Update Status Laporan:',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryTeal,
                            ),
                          ),
                          const Spacer(),
                          DropdownButton<String>(
                            value: isSos ? currentSosVal : currentLaporanVal,
                            items: (isSos
                                    ? const ['belum ditangani', 'ditangani', 'selesai', 'batal']
                                    : const ['menunggu', 'proses', 'selesai', 'dibatalkan'])
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e.toUpperCase()),
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
                  ),
                  const SizedBox(height: 16),
                ],

                // Image Card
                if (hasImage) ...[
                  _buildGlassContainer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          Stack(
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
                                        color: Colors.grey[200],
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              CupertinoIcons.xmark_rectangle,
                                              size: 40,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Gambar tidak tersedia',
                                              style: TextStyle(
                                                color: Colors.grey[500],
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
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Info Section (Waktu & Lokasi & Map)
                _buildGlassContainer(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                CupertinoIcons.calendar,
                                color: Color(0xFF00695C),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSos ? 'Waktu Kejadian' : 'Waktu Laporan',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.item.dateTime,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBE9E7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                CupertinoIcons.location_solid,
                                color: Color(0xFFD84315),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Lokasi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _readableAddress ?? _freshLocation ?? widget.item.location,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (lat != null && lng != null) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(lat, lng),
                                  initialZoom: 16.0,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag
                                        .none, // Prevent map scrolling inside scrollview
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.example.sahabat_sos_mobile',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(lat, lng),
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          CupertinoIcons.location_solid,
                                          color: Colors.red,
                                          size: 40,
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
                ),

                // Device Telemetry Card (Khusus Kasus SOS)
                if (isSos && _freshDeviceInfo != null) ...[
                  const SizedBox(height: 16),
                  _buildDeviceInfoCard(),
                ],

                // Officer Info Card
                if (_effectiveOfficerInfo != null) ...[
                  const SizedBox(height: 16),
                  _buildGlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: primaryTeal,
                            child: Icon(
                              CupertinoIcons.person_fill,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Petugas Pendamping',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _effectiveOfficerInfo!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Description Card
                if (_effectiveDescription != null &&
                    _effectiveDescription!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildGlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                CupertinoIcons.doc_text,
                                color: Colors.black54,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Keterangan Tambahan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _effectiveDescription!,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Audio Section
                if (_effectiveAudioUrl != null) ...[
                  const SizedBox(height: 16),
                  _buildGlassContainer(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00695C).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _isLoadingAudio ? null : _togglePlayPause,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryTeal,
                                shape: BoxShape.circle,
                              ),
                              child: _isLoadingAudio
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
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
                                      size: 28,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pesan Suara Terlampir',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Real Progress Slider
                                Row(
                                  children: [
                                    Text(
                                      _formatDuration(_position),
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 3,
                                          thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 6,
                                          ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 12,
                                              ),
                                          activeTrackColor: primaryTeal,
                                          inactiveTrackColor: primaryTeal.withValues(alpha: 0.2),
                                          thumbColor: primaryTeal,
                                          overlayColor: primaryTeal.withValues(alpha: 0.2),
                                        ),
                                        child: Slider(
                                          min: 0.0,
                                          max: _duration.inSeconds.toDouble() > 0
                                              ? _duration.inSeconds.toDouble()
                                              : 1.0,
                                          value:
                                              (_position.inSeconds.toDouble() <=
                                                  _duration.inSeconds.toDouble())
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
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
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
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
