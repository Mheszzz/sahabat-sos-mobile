import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AccessibilityService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    service = AccessibilityService.instance;
    await service.init(prefs);
  });

  group('AccessibilityService TalkBack Tests', () {
    test('When TalkBack is disabled, single tap immediately executes action', () {
      service.clearFocus();
      // Ensure TalkBack is disabled
      service.setTalkback(false, syncBackend: false);
      expect(service.isTalkbackEnabled, isFalse);

      bool executed = false;
      service.handleTalkbackTap(
        id: 'test_btn_1',
        speakText: 'Tombol Uji 1',
        onAction: () {
          executed = true;
        },
      );

      expect(executed, isTrue, reason: 'Action should execute immediately on 1st tap when TalkBack is off');
      expect(service.isElementFocused('test_btn_1'), isFalse);
    });

    test('When TalkBack is enabled, 1st tap focuses & speaks, 2nd tap executes action', () async {
      service.clearFocus();
      await service.setTalkback(true, syncBackend: false);
      expect(service.isTalkbackEnabled, isTrue);

      bool executed = false;

      // Ketukan 1 (Tekan 1): Harusnya memfokuskan dan belum mengeksekusi aksi
      service.handleTalkbackTap(
        id: 'test_btn_2',
        speakText: 'Tombol Uji 2',
        onAction: () {
          executed = true;
        },
      );

      expect(executed, isFalse, reason: 'Action must NOT execute on 1st tap when TalkBack is active');
      expect(service.isElementFocused('test_btn_2'), isTrue, reason: 'Element must be focused after 1st tap');

      // Ketukan 2 (Tekan lagi): Harusnya mengeksekusi aksi dan membersihkan fokus
      service.handleTalkbackTap(
        id: 'test_btn_2',
        speakText: 'Tombol Uji 2',
        onAction: () {
          executed = true;
        },
      );

      expect(executed, isTrue, reason: 'Action MUST execute on 2nd tap on the same element');
      expect(service.isElementFocused('test_btn_2'), isFalse, reason: 'Focus should be cleared after execution');
    });

    test('When TalkBack is enabled, tapping a different element switches focus without executing first element', () async {
      service.clearFocus();
      await service.setTalkback(true, syncBackend: false);

      bool action1Executed = false;
      bool action2Executed = false;

      // Tap element A (1st tap)
      service.handleTalkbackTap(
        id: 'elem_a',
        speakText: 'Elemen A',
        onAction: () {
          action1Executed = true;
        },
      );
      expect(service.isElementFocused('elem_a'), isTrue);
      expect(action1Executed, isFalse);

      // Tap element B (1st tap on new element)
      service.handleTalkbackTap(
        id: 'elem_b',
        speakText: 'Elemen B',
        onAction: () {
          action2Executed = true;
        },
      );
      expect(service.isElementFocused('elem_a'), isFalse);
      expect(service.isElementFocused('elem_b'), isTrue);
      expect(action1Executed, isFalse);
      expect(action2Executed, isFalse);

      // Tap element B again (2nd tap)
      service.handleTalkbackTap(
        id: 'elem_b',
        speakText: 'Elemen B',
        onAction: () {
          action2Executed = true;
        },
      );
      expect(action2Executed, isTrue);
      expect(action1Executed, isFalse);
    });

    test('When TalkBack is enabled, tapping after timeout expires resets focus and acts as new 1st tap', () async {
      service.clearFocus();
      await service.setTalkback(true, syncBackend: false);

      bool executed = false;

      // Tap 1
      service.handleTalkbackTap(
        id: 'test_timeout_btn',
        speakText: 'Tombol Timeout',
        onAction: () {
          executed = true;
        },
      );
      expect(service.isElementFocused('test_timeout_btn'), isTrue);
      expect(executed, isFalse);

      // Tunggu hingga timer timeout 2500ms berakhir
      await Future.delayed(const Duration(milliseconds: 2600));

      expect(service.isElementFocused('test_timeout_btn'), isFalse,
          reason: 'Focus should have reset after timeout');

      // Ketukan berikutnya setelah timeout: bertindak sebagai ketukan ke-1 yang baru (belum eksekusi)
      service.handleTalkbackTap(
        id: 'test_timeout_btn',
        speakText: 'Tombol Timeout',
        onAction: () {
          executed = true;
        },
      );
      expect(executed, isFalse,
          reason: 'Tap after timeout must act as a new 1st tap and not execute immediately');
      expect(service.isElementFocused('test_timeout_btn'), isTrue);
    });

    test('Category defaults for tunanetra automatically enables TalkBack', () async {
      await service.applyCategoryDefaults('tunanetra', syncBackend: false);
      expect(service.isTalkbackEnabled, isTrue);
      expect(service.isVoiceGuideEnabled, isTrue);
      expect(service.isHighContrastEnabled, isTrue);
      expect(service.isLargeTextEnabled, isTrue);
    });

    test('Category defaults for umum automatically disables all accessibility features', () async {
      // First enable tunanetra
      await service.applyCategoryDefaults('tunanetra', syncBackend: false);
      expect(service.isTalkbackEnabled, isTrue);

      // Now switch to umum
      await service.applyCategoryDefaults('umum', syncBackend: false);
      expect(service.isTalkbackEnabled, isFalse);
      expect(service.isVoiceGuideEnabled, isFalse);
      expect(service.isHapticEnabled, isFalse);
      expect(service.isHighContrastEnabled, isFalse);
      expect(service.isLargeTextEnabled, isFalse);
      expect(service.isVisualAlertEnabled, isFalse);
    });

    test('Disabling voice guide automatically turns off TalkBack', () async {
      await service.setVoiceGuide(true, syncBackend: false);
      await service.setTalkback(true, syncBackend: false);
      expect(service.isVoiceGuideEnabled, isTrue);
      expect(service.isTalkbackEnabled, isTrue);

      // Turn off voice guide
      await service.setVoiceGuide(false, syncBackend: false);
      expect(service.isVoiceGuideEnabled, isFalse);
      expect(service.isTalkbackEnabled, isFalse);
    });
  });
}
