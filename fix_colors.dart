import 'dart:io';

void main() {
  processFile('lib/features/tuya_device/presentation/screens/tuya_device_list_screen.dart');
  processFile('lib/features/tuya_device/presentation/screens/tuya_device_detail_screen.dart');
  processFile('lib/features/tuya_device/presentation/screens/tuya_device_scan_screen.dart');
  processFile('lib/features/tuya_device/presentation/screens/tuya_device_wifi_scan_screen.dart');
}

void processFile(String filepath) {
  var file = File(filepath);
  if (!file.existsSync()) return;
  
  var code = file.readAsStringSync();

  // Glass container background for light mode
  code = code.replaceAll('color ?? Colors.white.withValues(alpha: 0.1)', 'color ?? Colors.white.withValues(alpha: 0.6)');
  code = code.replaceAll('Border.all(color: Colors.white.withValues(alpha: 0.2))', 'Border.all(color: Colors.white.withValues(alpha: 0.8))');
  
  // Replace text and icon colors from white to black87, except for specific buttons where we want them to remain white.
  // First, temporarily change known white text/icons on colored backgrounds to a placeholder
  code = code.replaceAll('Icon(CupertinoIcons.wifi, color: Colors.white)', 'Icon(CupertinoIcons.wifi, color: PLACEHOLDER_WHITE)');
  code = code.replaceAll('Icon(CupertinoIcons.bluetooth, color: Colors.white)', 'Icon(CupertinoIcons.bluetooth, color: PLACEHOLDER_WHITE)');
  code = code.replaceAll("Text('Pairing Wi-Fi', style: TextStyle(color: Colors.white))", "Text('Pairing Wi-Fi', style: TextStyle(color: PLACEHOLDER_WHITE))");
  code = code.replaceAll("Text('Scan BLE', style: TextStyle(color: Colors.white))", "Text('Scan BLE', style: TextStyle(color: PLACEHOLDER_WHITE))");
  code = code.replaceAll("style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)", "style: const TextStyle(color: PLACEHOLDER_WHITE, fontWeight: FontWeight.bold)");
  code = code.replaceAll("Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white", "Icon(CupertinoIcons.exclamationmark_triangle_fill, color: PLACEHOLDER_WHITE");

  // Replace remaining white colors to black87
  code = code.replaceAll('Colors.white', 'Colors.black87');
  
  // Replace some black87 text that should actually be dark teal
  code = code.replaceAll('color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18', 'color: Color(0xFF005C61), fontWeight: FontWeight.bold, fontSize: 18');
  code = code.replaceAll('color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16', 'color: Color(0xFF005C61), fontWeight: FontWeight.bold, fontSize: 16');
  code = code.replaceAll('IconThemeData(color: Colors.black87)', 'IconThemeData(color: Color(0xFF005C61))');

  // Change some specific icons to primary teal
  code = code.replaceAll('Icon(CupertinoIcons.back, color: Colors.black87)', 'Icon(CupertinoIcons.back, color: Color(0xFF005C61))');
  code = code.replaceAll('Icon(CupertinoIcons.refresh, color: Colors.black87)', 'Icon(CupertinoIcons.refresh, color: Color(0xFF005C61))');
  code = code.replaceAll('Icon(CupertinoIcons.antenna_radiowaves_left_right, color: Colors.black87)', 'Icon(CupertinoIcons.antenna_radiowaves_left_right, color: Color(0xFF005C61))');
  
  // Also we want glass container borders and backgrounds to be white, not black87!
  code = code.replaceAll('Colors.black87.withValues(alpha: 0.6)', 'Colors.white.withValues(alpha: 0.6)');
  code = code.replaceAll('Colors.black87.withValues(alpha: 0.8)', 'Colors.white.withValues(alpha: 0.8)');
  
  // Also other alphas:
  code = code.replaceAll('Colors.black87.withValues(alpha: 0.1)', 'Colors.white.withValues(alpha: 0.6)'); // fallback
  code = code.replaceAll('Colors.black87.withValues(alpha: 0.2)', 'Colors.white.withValues(alpha: 0.8)'); // fallback
  
  // And for unselected text/icons
  code = code.replaceAll('Colors.black54', 'Colors.black54'); // already black54
  
  // Wait, I had some white54 and white70 that I converted to black54 previously!
  // No, I didn't successfully do it for everything. Let's do it now.
  code = code.replaceAll('Colors.white54', 'Colors.black54');
  code = code.replaceAll('Colors.white70', 'Colors.black54');
  
  // Restore placeholders
  code = code.replaceAll('PLACEHOLDER_WHITE', 'Colors.white');

  // Fix TuyaDeviceDetailScreen specific button text (Simulasi, Hapus)
  code = code.replaceAll("Text('Simulasi SOS', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))", "Text('Simulasi SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))");
  code = code.replaceAll("Text('Hapus Perangkat', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))", "Text('Hapus Perangkat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))");
  
  // Also CircularProgressIndicator
  code = code.replaceAll('CircularProgressIndicator(color: Colors.black87)', 'CircularProgressIndicator(color: Color(0xFF005C61))');

  // Re-run the gradient logic just in case it was missed on some files (like scan screens)
  code = code.replaceAll(
    'colors: [Color(0xFF005C61), Color(0xFF002224)],',
    'colors: [Color(0xFFE0F7FA), Color(0xFFF5F6F8), Color(0xFFE0F2F1)],'
  );

  file.writeAsStringSync(code);
}
