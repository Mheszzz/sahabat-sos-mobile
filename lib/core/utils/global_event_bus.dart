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

  /// Untuk meminta perpindahan tab pada MainVolunteerScreen
  /// 0: Beranda, 1: Tugas, 2: Peta, 3: Profil
  static final ValueNotifier<int?> changeVolunteerTab =
      ValueNotifier<int?>(null);

  /// Dipicu ketika status verifikasi relawan berubah
  static final ValueNotifier<bool?> volunteerVerificationStatus =
      ValueNotifier<bool?>(null);

  /// Dipicu ketika status aktif relawan (is_active) berubah
  static final ValueNotifier<bool?> volunteerActiveStatus =
      ValueNotifier<bool?>(null);
}
