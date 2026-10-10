import 'package:flutter_tts/flutter_tts.dart';

class AccessibilityService {
  static final AccessibilityService instance = AccessibilityService._internal();
  
  final FlutterTts _flutterTts = FlutterTts();
  bool isVoiceGuideEnabled = false;

  AccessibilityService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("id-ID");
  }

  Future<void> speak(String text) async {
    if (isVoiceGuideEnabled) {
      await _flutterTts.setLanguage("id-ID");
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
