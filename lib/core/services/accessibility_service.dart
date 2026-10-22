import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';
import 'package:sahabat_sos_mobile/features/profile/data/datasources/profile_remote_data_source.dart';

class AccessibilityService extends ChangeNotifier {
  static final AccessibilityService instance =
      AccessibilityService._internal();

  AccessibilityService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  SharedPreferences? _prefs;

  bool _isVoiceGuideEnabled = true;
  bool _isHapticEnabled = true;
  bool _isHighContrastEnabled = false;
  bool _isLargeTextEnabled = false;
  bool _isVisualAlertEnabled = false;
  String _disabilityCategory = 'umum';
  bool _isTtsInitialized = false;

  bool get isVoiceGuideEnabled => _isVoiceGuideEnabled;
  bool get isHapticEnabled => _isHapticEnabled;
  bool get isHighContrastEnabled => _isHighContrastEnabled;
  bool get isLargeTextEnabled => _isLargeTextEnabled;
  bool get isVisualAlertEnabled => _isVisualAlertEnabled;
  String get disabilityCategory => _disabilityCategory;

  Future<void> init([SharedPreferences? preferences]) async {
    _prefs = preferences ?? (sl.isRegistered<SharedPreferences>() ? sl<SharedPreferences>() : null);

    if (_prefs != null) {
      _isVoiceGuideEnabled =
          _prefs!.getBool('accessibility_voice_guide') ?? true;
      _isHapticEnabled =
          _prefs!.getBool('accessibility_haptic') ?? true;
      _isHighContrastEnabled =
          _prefs!.getBool('accessibility_high_contrast') ?? false;
      _isLargeTextEnabled =
          _prefs!.getBool('accessibility_large_text') ?? false;
      _disabilityCategory =
          _prefs!.getString('user_disability_category') ?? 'umum';
      _isVisualAlertEnabled =
          _prefs!.getBool('accessibility_visual_alert') ??
              (_disabilityCategory == 'tunarungu');
    }

    await _initTts();
    notifyListeners();
  }

  Future<void> _initTts() async {
    if (_isTtsInitialized) return;
    try {
      await _flutterTts.setLanguage("id-ID");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isTtsInitialized = true;
    } catch (e) {
      debugPrint("FlutterTts init warning: $e");
    }
  }

  // Setters with persistent storage and backend sync
  Future<void> setVoiceGuide(bool value, {bool syncBackend = true}) async {
    _isVoiceGuideEnabled = value;
    await _prefs?.setBool('accessibility_voice_guide', value);
    notifyListeners();

    if (value) {
      await speak("Panduan suara diaktifkan");
    } else {
      await stop();
    }

    if (syncBackend) {
      _syncToBackend({'panduan_suara': value ? 1 : 0});
    }
  }

  Future<void> setHaptic(bool value, {bool syncBackend = true}) async {
    _isHapticEnabled = value;
    await _prefs?.setBool('accessibility_haptic', value);
    notifyListeners();

    if (value) {
      await HapticFeedback.mediumImpact();
    }

    if (syncBackend) {
      _syncToBackend({'getaran': value ? 1 : 0});
    }
  }

  Future<void> setHighContrast(bool value, {bool syncBackend = true}) async {
    _isHighContrastEnabled = value;
    await _prefs?.setBool('accessibility_high_contrast', value);
    notifyListeners();

    if (_isHapticEnabled) {
      await HapticFeedback.selectionClick();
    }

    if (syncBackend) {
      _syncToBackend({'kontras_tinggi': value ? 1 : 0});
    }
  }

  Future<void> setLargeText(bool value, {bool syncBackend = true}) async {
    _isLargeTextEnabled = value;
    await _prefs?.setBool('accessibility_large_text', value);
    notifyListeners();

    if (_isHapticEnabled) {
      await HapticFeedback.selectionClick();
    }

    if (syncBackend) {
      _syncToBackend({'text_besar': value ? 1 : 0});
    }
  }

  /// Menyesuaikan logika & fitur aksesibilitas secara otomatis sesuai kebutuhan disabilitas
  Future<void> applyCategoryDefaults(
    String category, {
    bool syncBackend = true,
  }) async {
    final cleanCategory = category.trim().toLowerCase();
    _disabilityCategory = cleanCategory;
    await _prefs?.setString('user_disability_category', cleanCategory);

    switch (cleanCategory) {
      case 'tunanetra':
        // Tunanetra: Panduan Suara, Getaran Taktil, Kontras Tinggi, dan Teks Besar diaktifkan penuh
        _isVoiceGuideEnabled = true;
        _isHapticEnabled = true;
        _isHighContrastEnabled = true;
        _isLargeTextEnabled = true;
        _isVisualAlertEnabled = false;
        await _prefs?.setBool('accessibility_voice_guide', true);
        await _prefs?.setBool('accessibility_haptic', true);
        await _prefs?.setBool('accessibility_high_contrast', true);
        await _prefs?.setBool('accessibility_large_text', true);
        await _prefs?.setBool('accessibility_visual_alert', false);
        unawaited(speak(
          'Kategori Tunanetra aktif. Panduan suara, getaran, kontras tinggi, dan teks besar dioptimalkan.',
        ));
        break;

      case 'tunarungu':
        // Tunarungu: Suara tidak efektif, maksimalkan getaran taktil, kontras visual pekat, dan lampu visual flash
        _isVoiceGuideEnabled = false;
        _isHapticEnabled = true;
        _isHighContrastEnabled = true;
        _isVisualAlertEnabled = true;
        await _prefs?.setBool('accessibility_voice_guide', false);
        await _prefs?.setBool('accessibility_haptic', true);
        await _prefs?.setBool('accessibility_high_contrast', true);
        await _prefs?.setBool('accessibility_visual_alert', true);
        await stop();
        break;

      case 'tunawicara':
        // Tunawicara: Maksimalkan getaran respon dan komunikasi visual non-verbal
        _isHapticEnabled = true;
        _isVisualAlertEnabled = true;
        await _prefs?.setBool('accessibility_haptic', true);
        await _prefs?.setBool('accessibility_visual_alert', true);
        break;

      case 'umum':
      default:
        // Kategori umum: pertahankan preferensi kustom pengguna
        break;
    }

    notifyListeners();

    if (syncBackend) {
      _syncToBackend({
        'kategori_user': cleanCategory,
        'panduan_suara': _isVoiceGuideEnabled ? 1 : 0,
        'getaran': _isHapticEnabled ? 1 : 0,
        'kontras_tinggi': _isHighContrastEnabled ? 1 : 0,
        'text_besar': _isLargeTextEnabled ? 1 : 0,
      });
    }
  }

  void syncFromBackend(Map<String, dynamic> data) {
    bool changed = false;

    if (data.containsKey('kategori_user')) {
      final rawCat = (data['kategori_user'] as String?)?.toLowerCase() ?? 'umum';
      if (_disabilityCategory != rawCat && rawCat.isNotEmpty) {
        _disabilityCategory = rawCat;
        _prefs?.setString('user_disability_category', rawCat);
        if (rawCat == 'tunarungu') {
          _isVisualAlertEnabled = true;
          _prefs?.setBool('accessibility_visual_alert', true);
        }
        changed = true;
      }
    }

    // Data can be nested inside 'aksesibilitas' or flat
    final Map<String, dynamic> source =
        (data['aksesibilitas'] is Map)
            ? Map<String, dynamic>.from(data['aksesibilitas'] as Map)
            : data;

    if (source.containsKey('panduan_suara')) {
      final v = source['panduan_suara'] == true || source['panduan_suara'] == 1;
      if (_isVoiceGuideEnabled != v) {
        _isVoiceGuideEnabled = v;
        _prefs?.setBool('accessibility_voice_guide', v);
        changed = true;
      }
    }

    if (source.containsKey('getaran')) {
      final v = source['getaran'] == true || source['getaran'] == 1;
      if (_isHapticEnabled != v) {
        _isHapticEnabled = v;
        _prefs?.setBool('accessibility_haptic', v);
        changed = true;
      }
    }

    if (source.containsKey('kontras_tinggi')) {
      final v = source['kontras_tinggi'] == true || source['kontras_tinggi'] == 1;
      if (_isHighContrastEnabled != v) {
        _isHighContrastEnabled = v;
        _prefs?.setBool('accessibility_high_contrast', v);
        changed = true;
      }
    }

    if (source.containsKey('text_besar')) {
      final v = source['text_besar'] == true || source['text_besar'] == 1;
      if (_isLargeTextEnabled != v) {
        _isLargeTextEnabled = v;
        _prefs?.setBool('accessibility_large_text', v);
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _syncToBackend(Map<String, dynamic> payload) {
    try {
      if (sl.isRegistered<ProfileRemoteDataSource>()) {
        sl<ProfileRemoteDataSource>().updateProfile(payload).catchError((e) {
          debugPrint('Gagal sinkron aksesibilitas ke backend: $e');
          return <String, dynamic>{};
        });
      }
    } catch (e) {
      debugPrint('SyncToBackend exception: $e');
    }
  }

  // Haptic trigger methods
  void hapticLight() {
    if (_isHapticEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void hapticMedium() {
    if (_isHapticEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  void hapticHeavy() {
    if (_isHapticEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void hapticSelection() {
    if (_isHapticEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  // Voice & Announcement methods
  Future<void> speak(String text) async {
    if (!_isVoiceGuideEnabled) return;
    try {
      await _initTts();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS Speak error: $e");
    }
  }

  Future<void> announce(String message) async {
    // 1. Standar sistem untuk OS TalkBack / VoiceOver
    try {
      // ignore: deprecated_member_use
      await SemanticsService.announce(message, TextDirection.ltr);
    } catch (_) {}

    // 2. Panduan suara in-app jika diaktifkan pengguna
    if (_isVoiceGuideEnabled) {
      await speak(message);
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
