import 'package:flutter/material.dart';
import '../services/accessibility_service.dart';

class AccessibleWrapper extends StatelessWidget {
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
  Widget build(BuildContext context) {
    Widget content = child;

    if (onExecute != null) {
      content = InkWell(
        onTap: () {
          if (AccessibilityService.instance.isVoiceGuideEnabled) {
            AccessibilityService.instance.speak(speakText);
          }
          onExecute!();
        },
        child: child,
      );
    }

    return Semantics(
      label: speakText,
      button: onExecute != null,
      excludeSemantics: false,
      child: content,
    );
  }
}
