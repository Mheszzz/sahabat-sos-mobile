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
  Map<String, dynamic>? _deviceInfo;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _fetchDetailFromApi();
    _fetchUserRole();
    _resolveAddress();
  }

  Future<void> _resolveAddress() async {
    if (widget.item.latitude != null && widget.item.longitude != null) {
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(
            widget.item.latitude!, widget.item.longitude!);
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
        if (data != null) {
          setState(() {
            _freshStatus = (data['status'] ?? data['status_sos'])?.toString().toLowerCase();
            // Parse device_info dari API response (berisi smartwatch heart_rate, battery, dll)
            if (data['device_info'] is Map<String, dynamic>) {
              _deviceInfo = data['device_info'] as Map<String, dynamic>;
            }
          });
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
    if (widget.item.audioUrl != null) {
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
    if (widget.item.audioUrl == null) return;

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
            final filePath = '${tempDir.path}/temp_audio_${widget.item.id}.wav';

            if (await File(filePath).exists()) {
              _localAudioPath = filePath;
            } else {
              await sl<Dio>().download(widget.item.audioUrl!, filePath);
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

  static const Color primaryTeal = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    final statusString =
        _freshStatus ?? widget.item.status.toString().split('.').last;
    final statusColor = _getStatusColor(statusString);
    final statusIcon = _getStatusIcon(statusString);
    final hasImage = widget.item.imageUrl != null;
    final isSos = widget.item.type == HistoryType.sos;
    final detailTitle = isSos ? 'Detail Kasus SOS' : 'Detail Laporan';

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
                            value: isSos
                                ? (['belum ditangani', 'ditangani', 'selesai', 'batal'].contains(statusString)
                                    ? statusString
                                    : 'belum ditangani')
                                : (['menunggu', 'proses', 'selesai', 'dibatalkan', 'batal'].contains(statusString)
                                    ? statusString
                                    : 'menunggu'),
                            items: (isSos
                                    ? const ['belum ditangani', 'ditangani', 'selesai', 'batal']
                                    : const ['menunggu', 'proses', 'selesai', 'dibatalkan', 'batal'])
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
                                  widget.item.imageUrl!,
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
                                      widget.item.imageUrl!,
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
                                    _readableAddress ?? widget.item.location,
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
                        if (widget.item.latitude != null &&
                            widget.item.longitude != null) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(
                                    widget.item.latitude!,
                                    widget.item.longitude!,
                                  ),
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
                                        point: LatLng(
                                          widget.item.latitude!,
                                          widget.item.longitude!,
                                        ),
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

                // Officer Info Card
                if (widget.item.officerInfo != null) ...[
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
                                  widget.item.officerInfo!,
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

                // Smartwatch Telemetry Card (BPM & Battery)
                if (isSos) ...[
                  Builder(
                    builder: (context) {
                      final deviceInfo = _deviceInfo ?? widget.item.deviceInfo;
                      final smartwatch = deviceInfo?['smartwatch'] as Map<String, dynamic>?;

                      if (smartwatch == null) return const SizedBox.shrink();

                      final heartRate = smartwatch['heart_rate'] as int?;
                      final batteryLevel = smartwatch['battery_level'] as int?;
                      final fallDetected = smartwatch['fall_detected'] == true;
                      final triggerType = smartwatch['trigger_type']?.toString() ?? 'Smartwatch';
                      final deviceName = smartwatch['device_name']?.toString() ?? 'Smartwatch';

                      final isAnomalousHr = heartRate != null && (heartRate > 120 || heartRate < 50);

                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildGlassContainer(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFCE4EC),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.watch,
                                          color: Color(0xFFE53935),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Telemetri Smartwatch',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$deviceName · $triggerType',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Warning: Anomali Denyut Nadi
                                  if (isAnomalousHr) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFECACA)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded,
                                              color: Color(0xFFDC2626), size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              heartRate > 120
                                                  ? 'Anomali: Detak jantung tinggi ($heartRate BPM) — kemungkinan panik/syok'
                                                  : 'Anomali: Detak jantung rendah ($heartRate BPM) — perlu bantuan medis!',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF991B1B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Warning: Fall Detected
                                  if (fallDetected) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFED7AA)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.personal_injury,
                                              color: Color(0xFFEA580C), size: 18),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Sensor deteksi jatuh terpicu — waspadai cedera fisik',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9A3412),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 14),

                                  // Telemetry Grid: Heart Rate & Battery
                                  Row(
                                    children: [
                                      // Heart Rate
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: isAnomalousHr
                                                ? const Color(0xFFFEF2F2)
                                                : const Color(0xFFFFF1F2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isAnomalousHr
                                                  ? const Color(0xFFFECACA)
                                                  : const Color(0xFFFFE4E6),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.favorite,
                                                    color: isAnomalousHr
                                                        ? const Color(0xFFDC2626)
                                                        : const Color(0xFFE53935),
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Denyut Nadi',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                heartRate != null ? '$heartRate BPM' : '— BPM',
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: heartRate != null
                                                      ? (isAnomalousHr
                                                          ? const Color(0xFFDC2626)
                                                          : const Color(0xFFE53935))
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                heartRate != null
                                                    ? (heartRate > 120
                                                        ? 'Tinggi (Panik)'
                                                        : (heartRate < 50
                                                            ? 'Rendah (Bahaya)'
                                                            : 'Normal'))
                                                    : 'Tidak tersedia',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: isAnomalousHr
                                                      ? const Color(0xFFDC2626)
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Battery
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: batteryLevel != null && batteryLevel < 20
                                                  ? const Color(0xFFFED7AA)
                                                  : const Color(0xFFBBF7D0),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.battery_std,
                                                    color: batteryLevel != null && batteryLevel < 20
                                                        ? Colors.orange
                                                        : Colors.green,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Baterai Jam',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                batteryLevel != null
                                                    ? '$batteryLevel%'
                                                    : '—',
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                batteryLevel != null
                                                    ? (batteryLevel < 20
                                                        ? 'Kritis'
                                                        : (batteryLevel < 50 ? 'Sedang' : 'Baik'))
                                                    : 'Tidak tersedia',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: batteryLevel != null && batteryLevel < 20
                                                      ? Colors.orange
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],

                // Description Card
                if (widget.item.description != null &&
                    widget.item.description!.isNotEmpty) ...[
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
                            widget.item.description!,
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
                if (widget.item.audioUrl != null) ...[
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
