import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SosStatusPage extends StatefulWidget {
  const SosStatusPage({super.key});

  @override
  State<SosStatusPage> createState() => _SosStatusPageState();
}

class _SosStatusPageState extends State<SosStatusPage> {
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color sosRed = Color(0xFFE50000);
  
  Timer? _cancelTimer;
  bool _isCancelling = false;
  double _cancelProgress = 0.0;
  
  void _startCancelTimer() {
    setState(() {
      _isCancelling = true;
      _cancelProgress = 0.0;
    });
    
    const int durationMs = 5000;
    const int intervalMs = 50;
    int elapsedMs = 0;
    
    _cancelTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      elapsedMs += intervalMs;
      setState(() {
        _cancelProgress = elapsedMs / durationMs;
      });
      
      if (elapsedMs >= durationMs) {
        timer.cancel();
        _cancelSos();
      }
    });
  }
  
  void _stopCancelTimer() {
    _cancelTimer?.cancel();
    setState(() {
      _isCancelling = false;
      _cancelProgress = 0.0;
    });
  }
  
  void _cancelSos() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS Dibatalkan')),
    );
    context.pop();
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              
              // Icon
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: sosRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: sosRed.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.campaign,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Text
              const Text(
                'SOS SEDANG DIKIRIM',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: sosRed,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bantuan sedang diproses',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 32),
              
              // Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Laporan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildStatusItem(
                      icon: Icons.check_circle_outline,
                      iconColor: const Color(0xFF00695C),
                      iconBgColor: const Color(0xFFE0F2F1),
                      title: 'Lokasi terkirim',
                      description: 'Koordinat GPS Anda telah diterima oleh sistem.',
                    ),
                    const SizedBox(height: 20),
                    _buildStatusItem(
                      icon: Icons.autorenew,
                      iconColor: const Color(0xFFF57F17),
                      iconBgColor: const Color(0xFFFFF9C4),
                      title: 'Operator diberitahu',
                      description: 'Menunggu konfirmasi dari tim respons darurat.',
                    ),
                    const SizedBox(height: 20),
                    _buildStatusItem(
                      icon: Icons.more_horiz,
                      iconColor: Colors.grey.shade700,
                      iconBgColor: Colors.grey.shade200,
                      title: 'Keluarga diberitahu',
                      description: 'Kontak darurat akan segera dihubungi.',
                      isFaded: true,
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Hubungi Customer Services Button
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.support_agent, color: Colors.white),
                label: const Text(
                  'Hubungi Customer Services',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Batalkan SOS Button
              GestureDetector(
                onTapDown: (_) => _startCancelTimer(),
                onTapUp: (_) => _stopCancelTimer(),
                onTapCancel: () => _stopCancelTimer(),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Stack(
                    children: [
                      // Progress fill
                      if (_isCancelling)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _cancelProgress,
                            child: Container(
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      // Content
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.cancel_outlined, color: Colors.black87),
                            SizedBox(width: 8),
                            Text(
                              'Batalkan SOS (Tahan 5d)',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
              const Text(
                'Tahan tombol batal selama 5 detik untuk membatalkan keadaan darurat.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
    bool isFaded = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isFaded ? Colors.black54 : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: isFaded ? Colors.black38 : Colors.black54,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
