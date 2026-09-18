import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        code = f.read()

    # Gradient
    code = code.replace(
        'colors: [Color(0xFF005C61), Color(0xFF002224)],',
        'colors: [Color(0xFFE0F7FA), Color(0xFFF5F6F8), Color(0xFFE0F2F1)],'
    )

    # Text colors
    code = code.replace('color: Colors.white,', 'color: Colors.black87,')
    code = code.replace('color: Colors.white)', 'color: Colors.black87)')
    code = code.replace('color: Colors.white54', 'color: Colors.black54')
    code = code.replace('color: Colors.white70', 'color: Colors.black54')

    # AppBar Icon
    code = code.replace('IconThemeData(color: Colors.black87)', 'IconThemeData(color: Color(0xFF005C61))')
    code = code.replace(
        '''style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),''',
        '''style: TextStyle(
                color: Color(0xFF005C61),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),'''
    )
    code = code.replace(
        '''style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),''',
        '''style: const TextStyle(
            color: Color(0xFF005C61),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),'''
    )
    
    code = code.replace('Icon(CupertinoIcons.antenna_radiowaves_left_right, color: Colors.black87)', 'Icon(CupertinoIcons.antenna_radiowaves_left_right, color: Color(0xFF005C61))')
    code = code.replace('Icon(CupertinoIcons.refresh, color: Colors.black87)', 'Icon(CupertinoIcons.refresh, color: Color(0xFF005C61))')
    code = code.replace('Icon(CupertinoIcons.back, color: Colors.black87)', 'Icon(CupertinoIcons.back, color: Color(0xFF005C61))')

    # Glass container
    code = code.replace('color: color ?? Colors.black87.withValues(alpha: 0.1)', 'color: color ?? Colors.white.withValues(alpha: 0.4)')
    code = code.replace('border: Border.all(color: Colors.black87.withValues(alpha: 0.2))', 'border: Border.all(color: Colors.white.withValues(alpha: 0.6))')
    
    code = code.replace('Colors.black87.withValues(alpha: 0.1)', 'Colors.white.withValues(alpha: 0.6)')

    code = code.replace('Icon(CupertinoIcons.chevron_right, color: Colors.black87)', 'Icon(CupertinoIcons.chevron_right, color: Colors.black54)')

    # Loading indicator
    code = code.replace('CircularProgressIndicator(color: Colors.black87)', 'CircularProgressIndicator(color: Color(0xFF005C61))')
    code = code.replace('''CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black87,
                      )''', '''CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      )''')

    # Revert FAB and button text/icons to white
    code = code.replace("Text('Pairing Wi-Fi', style: TextStyle(color: Colors.black87))", "Text('Pairing Wi-Fi', style: TextStyle(color: Colors.white))")
    code = code.replace("Text('Scan BLE', style: TextStyle(color: Colors.black87))", "Text('Scan BLE', style: TextStyle(color: Colors.white))")
    code = code.replace("Icon(CupertinoIcons.wifi, color: Colors.black87)", "Icon(CupertinoIcons.wifi, color: Colors.white)")
    code = code.replace("Icon(CupertinoIcons.bluetooth, color: Colors.black87)", "Icon(CupertinoIcons.bluetooth, color: Colors.white)")
    code = code.replace("icon: const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.black87)", "icon: const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.white)")
    code = code.replace('''Text(
                _isSimulating ? 'Mengirim...' : 'Simulasi SOS',
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
              )''', '''Text(
                _isSimulating ? 'Mengirim...' : 'Simulasi SOS',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              )''')
    code = code.replace('Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.black87', 'Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white')
    
    code = code.replace("Icon(CupertinoIcons.lab_flask, color: Colors.orangeAccent, size: 20)", "Icon(CupertinoIcons.lab_flask, color: Color(0xFFE65100), size: 20)")
    code = code.replace("color: Colors.orange.withValues(alpha: 0.15)", "color: Colors.orange.withValues(alpha: 0.2)")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(code)

process_file('d:/sahabat-sos-mobile/sahabat_sos_mobile/lib/features/tuya_device/presentation/screens/tuya_device_list_screen.dart')
process_file('d:/sahabat-sos-mobile/sahabat_sos_mobile/lib/features/tuya_device/presentation/screens/tuya_device_detail_screen.dart')
process_file('d:/sahabat-sos-mobile/sahabat_sos_mobile/lib/features/tuya_device/presentation/screens/tuya_device_scan_screen.dart')
process_file('d:/sahabat-sos-mobile/sahabat_sos_mobile/lib/features/tuya_device/presentation/screens/tuya_device_wifi_scan_screen.dart')
