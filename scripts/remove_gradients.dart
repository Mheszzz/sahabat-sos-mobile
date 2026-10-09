import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    
    // Pattern to match the specific complex gradient with orbs in dashboard pages
    final dashboardGradientPattern = RegExp(
        r'Positioned\.fill\(\s*child: Container\(\s*decoration: const BoxDecoration\(\s*gradient: LinearGradient\(.*?\),\s*\),\s*\),\s*\),\s*Positioned\(\s*top: -50,\s*left: -50,\s*child: Container\(.*?shape: BoxShape\.circle,.*?\),\s*\),\s*\),\s*Positioned\(\s*bottom: -100,\s*right: -50,\s*child: Container\(.*?shape: BoxShape\.circle,.*?\),\s*\),\s*\),\s*Positioned\.fill\(\s*child: BackdropFilter\(\s*filter: ImageFilter\.blur.*?child: Container\(color: Colors\.transparent\),\s*\),\s*\),',
        dotAll: true);
        
    // Pattern to match standard Container gradient
    final containerGradientPattern = RegExp(
        r'Container\(\s*decoration: const BoxDecoration\(\s*gradient: LinearGradient\(.*?\),\s*\),\s*child: ',
        dotAll: true);

    bool modified = false;

    if (content.contains(dashboardGradientPattern)) {
      content = content.replaceAll(dashboardGradientPattern, '');
      modified = true;
    }

    if (content.contains(containerGradientPattern)) {
      // Replace with just a Container(color: Color(0xFFF2F2F7), child: 
      // Actually, if we just remove the decoration and put color, or simply remove decoration since Scaffold has backgroundColor
      content = content.replaceAllMapped(containerGradientPattern, (match) {
        return 'Container(\n        color: const Color(0xFFF5F6F8),\n        child: ';
      });
      modified = true;
    }
    
    // Also find Scaffold with backgroundColor: Colors.transparent and replace with Color(0xFFF5F6F8)
    final transparentScaffoldPattern = RegExp(r'backgroundColor:\s*Colors\.transparent\s*,');
    if (modified && content.contains(transparentScaffoldPattern)) {
      content = content.replaceAll(transparentScaffoldPattern, 'backgroundColor: const Color(0xFFF5F6F8),');
    }
    
    // Also, if the background of Scaffold is now solid, maybe `extendBodyBehindAppBar: true` should be evaluated?
    // Usually standard iOS apps don't extend body unless it's a map. But if we change it, it might shift layouts.
    // So let's keep extendBodyBehindAppBar for now, or just leave it.

    if (modified) {
      print('Updated \${file.path}');
      file.writeAsStringSync(content);
    }
  }
}
