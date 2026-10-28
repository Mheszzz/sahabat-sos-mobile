import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan persisten untuk daftar ID SOS yang telah ditolak/dilewati oleh relawan.
/// Mencegah notifikasi sistem (suara & getaran sirine) dan popup berulang
/// saat SOS yang ditolak mengalami eskalasi lanjutan ke relawan-channel.
class SosRejectionStorage {
  static const String _storageKey = 'rejected_sos_ids';
  static final Set<int> _inMemoryRejectedIds = <int>{};

  /// Inisialisasi daftar SOS yang ditolak dari SharedPreferences
  static Future<void> init(SharedPreferences prefs) async {
    final list = prefs.getStringList(_storageKey) ?? [];
    _inMemoryRejectedIds.clear();
    for (final item in list) {
      final id = int.tryParse(item);
      if (id != null) {
        _inMemoryRejectedIds.add(id);
      }
    }
  }

  /// Cek apakah ID SOS tertentu sudah ditolak oleh relawan
  static bool isRejected(int sosId) {
    return _inMemoryRejectedIds.contains(sosId);
  }

  /// Catat penolakan SOS dan simpan secara persisten ke SharedPreferences
  static Future<void> addRejectedId(int sosId, SharedPreferences prefs) async {
    _inMemoryRejectedIds.add(sosId);
    final stringList = _inMemoryRejectedIds.map((e) => e.toString()).toList();
    await prefs.setStringList(_storageKey, stringList);
  }

  /// Ambil salinan Set ID yang ditolak
  static Set<int> get rejectedIds => Set.unmodifiable(_inMemoryRejectedIds);
}
