import 'dart:io';

void main() {
  fixListScreen();
  fixDetailScreen();
}

void fixListScreen() {
  final path = 'lib/features/tuya_device/presentation/screens/tuya_device_list_screen.dart';
  var file = File(path);
  if (!file.existsSync()) return;
  var code = file.readAsStringSync();
  
  // Replace Colors.greenAccent with Color(0xFF2E7D32)
  code = code.replaceAll('Colors.greenAccent', 'const Color(0xFF2E7D32)');
  
  // Wrap FAB Column with Padding
  final fabOld = '''
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
''';
  final fabNew = '''
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
''';
  code = code.replaceFirst(fabOld, fabNew);

  // Close Padding widget for FAB (the Column has a closing brace)
  final fabCloseOld = '''
          ],
        ),
      );
    }

    Widget _buildStatusCard() {
''';
  final fabCloseNew = '''
          ],
        ),
      ),
      );
    }

    Widget _buildStatusCard() {
''';
  code = code.replaceFirst(fabCloseOld, fabCloseNew);

  file.writeAsStringSync(code);
}

void fixDetailScreen() {
  final path = 'lib/features/tuya_device/presentation/screens/tuya_device_detail_screen.dart';
  var file = File(path);
  if (!file.existsSync()) return;
  var code = file.readAsStringSync();
  
  // Replace Colors.greenAccent with Color(0xFF2E7D32)
  code = code.replaceAll('Colors.greenAccent', 'const Color(0xFF2E7D32)');
  
  file.writeAsStringSync(code);
}
