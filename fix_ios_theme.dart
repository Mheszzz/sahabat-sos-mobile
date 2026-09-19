import 'dart:io';

void main() {
  processFile('lib/features/tuya_device/presentation/screens/tuya_device_list_screen.dart');
  processFile('lib/features/tuya_device/presentation/screens/tuya_device_detail_screen.dart');
}

void processFile(String filepath) {
  var file = File(filepath);
  if (!file.existsSync()) return;
  var code = file.readAsStringSync();

  // 1. Update _buildGlassContainer
  final glassOld = '''
  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding, Color? color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: child,
        ),
      ),
    );
  }
''';
  
  final glassNew = '''
  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding, Color? color}) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
''';

  code = code.replaceFirst(glassOld.trim(), glassNew.trim());

  // 2. Update background in build()
  final bodyOld = '''
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F7FA), Color(0xFFF5F6F8), Color(0xFFE0F2F1)],
          ),
        ),
        child: SafeArea(
''';

  final bodyNew = '''
      body: Stack(
        children: [
          Container(color: const Color(0xFFF2F2F7)),
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF005C61).withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
''';

  code = code.replaceFirst(bodyOld.trim(), bodyNew.trim());

  // 3. Change BoxShape.circle to BorderRadius.circular(14) for iOS logo theme
  // We will do this via regex for decoration: BoxDecoration( ... shape: BoxShape.circle ... )
  // Actually, we can just replace shape: BoxShape.circle with borderRadius: BorderRadius.circular(16)
  // But we need to remove shape: BoxShape.circle. 
  // Let's use simple string replacements for the known ones:
  code = code.replaceAll(
    '''
              shape: BoxShape.circle,
              border: Border.all(
                color: isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
''', 
    '''
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
'''
  );

  code = code.replaceAll('shape: BoxShape.circle,', 'borderRadius: BorderRadius.circular(14),');

  // One issue: the decorative circles in our new body Stack use BoxShape.circle!
  // So let's restore those specifically in bodyNew!
  code = code.replaceAll(
    '''
                color: const Color(0xFF005C61).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
''', 
    '''
                color: const Color(0xFF005C61).withValues(alpha: 0.3),
                shape: BoxShape.circle,
'''
  );
  code = code.replaceAll(
    '''
                color: Colors.blueAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
''',
    '''
                color: Colors.blueAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
'''
  );

  file.writeAsStringSync(code);
}
