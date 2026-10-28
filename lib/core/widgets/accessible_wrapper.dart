import 'package:flutter/material.dart';
import '../services/accessibility_service.dart';

class AccessibleWrapper extends StatelessWidget {
  final Widget child;
  final String speakText;
  final VoidCallback? onExecute;
  final bool isSwitch;
  final String? id;
  final String? hintText;
  final BorderRadius? borderRadius;
  final bool showFocusBorder;

  const AccessibleWrapper({
    super.key,
    required this.child,
    required this.speakText,
    this.onExecute,
    this.isSwitch = false,
    this.id,
    this.hintText,
    this.borderRadius,
    this.showFocusBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    if (onExecute == null) {
      return Semantics(
        label: speakText,
        button: false,
        excludeSemantics: false,
        child: child,
      );
    }

    final elementId = id ?? speakText;

    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final service = AccessibilityService.instance;
        final isFocused = service.isElementFocused(elementId);

        Widget content = child;

        // Visual indicator border when focused in TalkBack mode
        if (showFocusBorder && isFocused) {
          content = Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: service.isHighContrastEnabled
                    ? const Color(0xFF00FFCC)
                    : const Color(0xFF00897B),
                width: 2.5,
              ),
              borderRadius: borderRadius ?? BorderRadius.circular(12),
            ),
            child: content,
          );
        }

        return Semantics(
          label: speakText,
          button: true,
          hint: service.isTalkbackEnabled
              ? (hintText ?? "Tekan sekali lagi untuk melakukan aksi")
              : null,
          excludeSemantics: false,
          child: InkWell(
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            onTap: () {
              service.handleTalkbackTap(
                id: elementId,
                speakText: speakText,
                onAction: onExecute!,
                hintText: hintText,
              );
            },
            child: content,
          ),
        );
      },
    );
  }
}

