import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';

class SlideToCancelButton extends StatefulWidget {
  final Future<void> Function()? onCancelled;
  final String label;
  final double height;

  const SlideToCancelButton({
    super.key,
    required this.onCancelled,
    this.label = 'Geser untuk Batalkan SOS',
    this.height = 48.0,
  });

  @override
  State<SlideToCancelButton> createState() => _SlideToCancelButtonState();
}

class _SlideToCancelButtonState extends State<SlideToCancelButton> {
  double _dragPosition = 0.0;
  bool _isCompleted = false;
  double get _thumbSize => widget.height;

  @override
  Widget build(BuildContext context) {
    final isHighContrast =
        AccessibilityService.instance.isHighContrastEnabled ||
        Theme.of(context).brightness == Brightness.dark ||
        MediaQuery.of(context).highContrast;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxDrag = (maxWidth - _thumbSize).clamp(0.0, double.infinity);

        return Container(
          width: maxWidth,
          height: _thumbSize,
          decoration: BoxDecoration(
            color: isHighContrast
                ? const Color(0xFF201212)
                : const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(_thumbSize / 2),
            border: Border.all(
              color: isHighContrast
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFFFCDD2),
              width: isHighContrast ? 1.5 : 1.0,
            ),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              if (_isCompleted) return;
              setState(() {
                _dragPosition += details.delta.dx;
                if (_dragPosition < 0) _dragPosition = 0;
                if (_dragPosition > maxDrag) _dragPosition = maxDrag;
              });
            },
            onHorizontalDragEnd: (details) async {
              if (_isCompleted) return;

              final isFling = (details.primaryVelocity ?? 0) > 300 &&
                  _dragPosition > maxDrag * 0.3;
              final isDraggedPastThreshold = _dragPosition >= maxDrag * 0.75;

              if (isFling || isDraggedPastThreshold) {
                AccessibilityService.instance.hapticHeavy();
                unawaited(AccessibilityService.instance.speak("Membatalkan SOS"));
                setState(() {
                  _dragPosition = maxDrag;
                  _isCompleted = true;
                });
                if (widget.onCancelled != null) {
                  try {
                    await widget.onCancelled!();
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        _isCompleted = false;
                        _dragPosition = 0.0;
                      });
                    }
                  }
                }
              } else {
                AccessibilityService.instance.hapticLight();
                setState(() {
                  _dragPosition = 0.0; // Snap back
                });
              }
            },
            child: Stack(
              children: [
                // 1. Base Text & Icon
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 20),
                      if (!_isCompleted) ...[
                        Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 18,
                          color: isHighContrast
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFD32F2F),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _isCompleted ? 'Membatalkan SOS...' : widget.label,
                        style: TextStyle(
                          color: isHighContrast
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFD32F2F),
                          fontWeight: FontWeight.bold,
                          fontSize: _thumbSize > 50 ? 15 : 13.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Filled track following the thumb
                AnimatedContainer(
                  duration: _dragPosition == 0.0
                      ? const Duration(milliseconds: 250)
                      : Duration.zero,
                  curve: Curves.easeOut,
                  width: _dragPosition + _thumbSize,
                  height: _thumbSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(_thumbSize / 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_thumbSize / 2),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          width: maxWidth,
                          child: Container(
                            height: _thumbSize,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(width: 20),
                                if (!_isCompleted) ...[
                                  const Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  _isCompleted
                                      ? 'Membatalkan SOS...'
                                      : widget.label,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: _thumbSize > 50 ? 15 : 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Draggable Thumb (Knob)
                AnimatedPositioned(
                  duration: _dragPosition == 0.0
                      ? const Duration(milliseconds: 250)
                      : Duration.zero,
                  curve: Curves.easeOut,
                  left: _dragPosition,
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC62828),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isCompleted
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                            )
                          : Icon(
                              CupertinoIcons.chevron_right_2,
                              color: Colors.white,
                              size: _thumbSize > 50 ? 26 : 22,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
