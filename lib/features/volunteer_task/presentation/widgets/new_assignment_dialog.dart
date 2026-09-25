import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _startTimer();
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
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pengguna = widget.sosData['pengguna'] ?? {};
    final namaPelapor = pengguna['name'] ?? 'Tanpa Nama';
    final lat = widget.sosData['latitude'] ?? 0.0;
    final lng = widget.sosData['longitude'] ?? 0.0;
    final String lokasiStr = "Lat: $lat, Lng: $lng";
    
    final kategori = pengguna['kategori_user'] ?? 'Umum';
    final metodeKomunikasi = pengguna['metode_komunikasi'] ?? 'Standar';
    final bool hasDisability = (kategori != 'Umum' && kategori != '');

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
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
              // Header Gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.teal.shade800,
                      Colors.teal.shade600,
                    ],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.amber, size: 28),
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
                                decoration: const BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'TINDAKAN CEPAT DIBUTUHKAN',
                                style: TextStyle(
                                  color: Colors.amber,
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
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
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
                          Icon(CupertinoIcons.time, size: 14, color: Colors.teal.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Baru saja',
                            style: TextStyle(color: Colors.teal.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Panggilan Darurat SOS',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E), letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pelapor: $namaPelapor',
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 20),
                      
                      // Location Info Card (Glassy White)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(CupertinoIcons.location_solid, color: Colors.teal.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Titik Koordinat SOS', 
                                  style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              lokasiStr,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1C1C1E)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Silakan gunakan peta untuk rute menuju lokasi',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Special Needs Card (Glassy Yellow)
                      if (hasDisability)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.amber.withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade600,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(CupertinoIcons.person_solid, color: Colors.white, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Kebutuhan Khusus',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1C1C1E)),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      kategori,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Metode Komunikasi:',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      metodeKomunikasi,
                                      style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.w600, fontSize: 13),
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
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                          icon: const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.white, size: 20),
                          label: const Text(
                            'Terima & Mulai Tugas',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                          icon: Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey.shade600, size: 20),
                          label: Text(
                            'Alihkan Tugas',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.grey.shade700),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
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
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
  }
}
