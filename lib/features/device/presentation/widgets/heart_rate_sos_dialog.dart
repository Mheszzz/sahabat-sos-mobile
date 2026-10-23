import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/health_connect_service.dart';

class HeartRateSosDialog extends StatefulWidget {
  final HeartRateRecord record;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const HeartRateSosDialog({
    super.key,
    required this.record,
    required this.onConfirm,
    required this.onCancel,
  });

  /// Static helper untuk menampilkan dialog dari context manapun
  static Future<bool?> show(
    BuildContext context, {
    required HeartRateRecord record,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => HeartRateSosDialog(
        record: record,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
    );
  }

  @override
  State<HeartRateSosDialog> createState() => _HeartRateSosDialogState();
}

class _HeartRateSosDialogState extends State<HeartRateSosDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _countdownTimer;
  int _secondsLeft = 10;
  bool _actionTaken = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Getar pertama kali
    HapticFeedback.heavyImpact();

    // Start 10-second countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Haptic feedback tiap detik countdown
      HapticFeedback.vibrate();

      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _secondsLeft = 0;
          timer.cancel();
          _triggerSos();
        }
      });
    });
  }

  void _triggerSos() {
    if (_actionTaken) return;
    _actionTaken = true;
    _countdownTimer?.cancel();
    Navigator.of(context, rootNavigator: true).pop(true);
    widget.onConfirm();
  }

  void _cancelSos() {
    if (_actionTaken) return;
    _actionTaken = true;
    _countdownTimer?.cancel();
    Navigator.of(context, rootNavigator: true).pop(false);
    widget.onCancel();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTooHigh = widget.record.bpm > 100;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Pulsing Heart Icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              const Text(
                'PERINGATAN DARURAT!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.red,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

              // Status message
              Text(
                'Detak jantung Anda terdeteksi ${isTooHigh ? "sangat tinggi" : "sangat rendah"}:',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // BPM Display Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monitor_heart, color: Colors.red, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.record.bpm} BPM',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Countdown display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Sinyal SOS Darurat Otomatis dikirim dalam:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_secondsLeft DETIK',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Batalkan (Prioritas Utama untuk false positive)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _cancelSos,
                  icon: const Icon(Icons.close, color: Colors.white, size: 22),
                  label: const Text(
                    'BATALKAN (SAYA BAIK-BAIK SAJA)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Tombol Kirim Segera
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _triggerSos,
                  icon: const Icon(Icons.send_rounded, color: Colors.red, size: 20),
                  label: const Text(
                    'KIRIM SOS SEKARANG',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
