import 'package:flutter/material.dart';
import '../services/accessibility_service.dart';

class AccessibleWrapper extends StatefulWidget {
  final Widget child;
  final String speakText;
  final VoidCallback? onExecute;
  final bool isSwitch;

  const AccessibleWrapper({
    super.key,
    required this.child,
    required this.speakText,
    this.onExecute,
    this.isSwitch = false,
  });

  @override
  State<AccessibleWrapper> createState() => _AccessibleWrapperState();
}

class _AccessibleWrapperState extends State<AccessibleWrapper> {
  DateTime? _lastTap;

  void _handleTap() {
    if (!AccessibilityService.instance.isVoiceGuideEnabled) {
      if (widget.onExecute != null) widget.onExecute!();
      return;
    }

    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < const Duration(seconds: 2)) {
      // Tap kedua (dalam 2 detik) -> Eksekusi
      if (widget.onExecute != null) widget.onExecute!();
      _lastTap = null;
    } else {
      // Tap pertama -> Bicara
      AccessibilityService.instance.speak(widget.speakText);
      _lastTap = now;
      
      // Jika ini adalah switch/toggle biasa, pengguna sering bingung harus double tap.
      // Tapi karena requirementnya "tekan satu bicara, tekan lagi berfungsi", kita terapkan ke semua.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kita selalu serap event tap jika ada onExecute, agar tidak terjadi double-trigger 
    // antara GestureDetector ini dengan widget aslinya (seperti Switch).
    final bool absorb = widget.onExecute != null;
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AbsorbPointer(
        absorbing: absorb,
        child: widget.child,
      ),
    );
  }
}
