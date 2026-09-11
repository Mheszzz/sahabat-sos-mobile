import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'history_screen.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';

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
  String? _freshDescription;
  String? _freshOfficerInfo;
  bool _isFetchingDetail = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _fetchDetailFromApi();
  }

  /// Fetch fresh detail from API to get latest status, officer info, etc.
  Future<void> _fetchDetailFromApi() async {
    setState(() => _isFetchingDetail = true);
    try {
      final prefs = sl<SharedPreferences>();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await sl<Dio>().get(
        '${ApiConstants.laporan}/${widget.item.id}',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        }),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data['data'];
        if (data != null) {
          setState(() {
            _freshStatus = data['status'];
            _freshDescription = data['deskripsi'];
            if (data['relawan'] != null) {
              _freshOfficerInfo = 'Relawan: ${data['relawan']['name'] ?? '-'}';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Gagal fetch detail laporan: $e');
    } finally {
      if (mounted) setState(() => _isFetchingDetail = false);
    }
  }

  bool _isCompleted = false;

  void _initAudioPlayer() {
    if (widget.item.audioUrl != null) {
      _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
            if (state == PlayerState.playing || state == PlayerState.paused || state == PlayerState.completed) {
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
    return Colors.red;
  }

  IconData _getStatusIcon(String status) {
    status = status.toLowerCase();
    if (status == 'selesai') return Icons.check_circle;
    if (status == 'ditangani') return Icons.engineering;
    return Icons.warning;
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
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
              errorBuilder: (context, error, stackTrace) => 
                  const Icon(Icons.broken_image, size: 50, color: Colors.grey),
            ),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final statusString = _freshStatus ?? widget.item.status.toString().split('.').last;
    final statusColor = _getStatusColor(statusString);
    final statusIcon = _getStatusIcon(statusString);
    final hasImage = widget.item.imageUrl != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        iconTheme: const IconThemeData(color: Color(0xFF00695C)),
        title: Row(
          children: const [
            Icon(Icons.accessibility_new, color: Color(0xFF00695C), size: 22),
            SizedBox(width: 8),
            Text(
              'Detail Laporan',
              style: TextStyle(
                color: Color(0xFF00695C),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.item.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          statusString.toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Image Card
              if (hasImage) ...[
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.item.imageUrl!,
                          fit: BoxFit.contain, // Prevent cropping
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[200],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 40, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text('Gambar tidak tersedia', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                              ],
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
                              onTap: () => _showFullScreenImage(context, widget.item.imageUrl!),
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.open_in_full_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Info Section (Waktu & Lokasi & Map)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
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
                            child: const Icon(Icons.calendar_today, color: Color(0xFF00695C), size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Waktu Laporan', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                const SizedBox(height: 2),
                                Text(widget.item.dateTime, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                            child: const Icon(Icons.location_on, color: Color(0xFFD84315), size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Lokasi', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                const SizedBox(height: 2),
                                Text(widget.item.location, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.item.latitude != null && widget.item.longitude != null) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(widget.item.latitude!, widget.item.longitude!),
                                initialZoom: 16.0,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none, // Prevent map scrolling inside scrollview
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.example.sahabat_sos_mobile',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(widget.item.latitude!, widget.item.longitude!),
                                      width: 40,
                                      height: 40,
                                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFB2DFDB)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF00695C),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Petugas Pendamping', style: TextStyle(fontSize: 12, color: Color(0xFF004D40))),
                            const SizedBox(height: 4),
                            Text(widget.item.officerInfo!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Description Card
              if (widget.item.description != null && widget.item.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.description_outlined, color: Colors.black54, size: 20),
                            SizedBox(width: 8),
                            Text('Keterangan Tambahan', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(widget.item.description!, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
              ],

              // Audio Section
              if (widget.item.audioUrl != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _isLoadingAudio ? null : _togglePlayPause,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: _isLoadingAudio 
                            ? const SizedBox(
                                width: 32, 
                                height: 32, 
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                              )
                            : Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow, 
                                color: Colors.white, 
                                size: 32,
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pesan Suara Terlampir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 6),
                            // Real Progress Slider
                            Row(
                              children: [
                                Text(
                                  _formatDuration(_position),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                      activeTrackColor: Colors.white,
                                      inactiveTrackColor: Colors.white30,
                                      thumbColor: Colors.white,
                                      overlayColor: Colors.white24,
                                    ),
                                    child: Slider(
                                      min: 0.0,
                                      max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                                      value: (_position.inSeconds.toDouble() <= _duration.inSeconds.toDouble()) 
                                          ? _position.inSeconds.toDouble() 
                                          : 0.0,
                                      onChanged: (value) async {
                                        final position = Duration(seconds: value.toInt());
                                        await _audioPlayer.seek(position);
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDuration(_duration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
              
              // Back Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali ke Riwayat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00695C),
                    side: const BorderSide(color: Color(0xFF00695C), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
