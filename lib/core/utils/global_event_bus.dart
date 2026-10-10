import 'package:flutter/foundation.dart';

class GlobalEventBus {
  static final ValueNotifier<bool> refreshMap = ValueNotifier<bool>(false);

  /// Ketika relawan menerima tugas SOS, isi dengan data SOS-nya.
  /// MainVolunteerScreen akan listen dan otomatis pindah ke tab Peta.
  /// Set ke null setelah navigasi selesai.
  static final ValueNotifier<Map<String, dynamic>?> navigateToMapWithSos =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// Ketika notifikasi SOS di-tap, jalankan popup terima tugas
  static final ValueNotifier<Map<String, dynamic>?> showSosAssignmentPopup =
      ValueNotifier<Map<String, dynamic>?>(null);
}
