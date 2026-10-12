import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    bool modified = false;

    // Pattern 1: Any container with a LinearGradient inside its decoration
    // Container( ... decoration: BoxDecoration( ... gradient: LinearGradient(...) ... ) ... )
    // We can just replace 'decoration: BoxDecoration(gradient: LinearGradient(....))'
    // with 'color: const Color(0xFFF5F6F8)' if it's a page background.

    // A simpler approach: Just look for 'gradient: LinearGradient(' or 'gradient: const LinearGradient('
    // We will do a generic regex that targets the `decoration: ... gradient: LinearGradient( ... )` block.
    
    // Specifically target the big page background gradients first
    final backgroundGradientPattern = RegExp(
      r'decoration:\s*const\s*BoxDecoration\(\s*gradient:\s*LinearGradient\([^)]*\)\s*,\s*\)', 
      dotAll: true
    );
    if (content.contains(backgroundGradientPattern)) {
      // Replace with solid color
      content = content.replaceAll(backgroundGradientPattern, 'color: const Color(0xFFF5F6F8)');
      modified = true;
    }
    
    // Target the one with height/width
    final containerWithBgPattern = RegExp(
      r'Container\(\s*height:\s*double\.infinity,\s*width:\s*double\.infinity,\s*decoration:\s*const\s*BoxDecoration\(\s*gradient:\s*LinearGradient\([^)]*\)\s*,\s*\),',
      dotAll: true
    );
    if (content.contains(containerWithBgPattern)) {
      content = content.replaceAll(containerWithBgPattern, 'Container(\n        height: double.infinity,\n        width: double.infinity,\n        color: const Color(0xFFF5F6F8),');
      modified = true;
    }

    // Target the glass container BackdropFilter gradients
    final backdropFilterPattern = RegExp(
      r'BackdropFilter\(\s*filter:\s*ImageFilter\.blur\([^)]*\),\s*child:\s*Container\(\s*decoration:\s*BoxDecoration\(\s*gradient:\s*LinearGradient\([^)]*\)\s*,\s*borderRadius:([^,]*),\s*border:[^)]*\)\s*,\s*\)\s*,\s*child:([^,]*),\s*\)\s*,\s*\)',
      dotAll: true
    );
    // Actually, maybe we shouldn't touch glass containers if they are just cards, but they said "Hapus semua gradasi".
    // Let's replace ANY `gradient: LinearGradient( ... )` with a solid color.
    
    // Find all 'gradient:' in the file and replace it with a solid color if we can match the brackets.
    // Dart regex doesn't support recursive bracket matching easily. So let's use string manipulation.
    
    while(true) {
      int gradientIndex = content.indexOf('gradient: LinearGradient(');
      if (gradientIndex == -1) {
        gradientIndex = content.indexOf('gradient: const LinearGradient(');
      }
      if (gradientIndex == -1) break;
      
      // We found a gradient. Let's find the closing parenthesis.
      int openParenIndex = content.indexOf('(', gradientIndex);
      int parenCount = 1;
      int closeParenIndex = openParenIndex + 1;
      
      while (parenCount > 0 && closeParenIndex < content.length) {
        if (content[closeParenIndex] == '(') parenCount++;
        if (content[closeParenIndex] == ')') parenCount--;
        closeParenIndex++;
      }
      
      // Replace the gradient: LinearGradient(...) with color: Colors.white
      // Wait, if it was inside a BoxDecoration, it should just be `color: Colors.white` but if there's already a border or borderRadius, we need to be careful.
      // Replacing `gradient: ...` with `color: Colors.white` is safe inside BoxDecoration!
      content = content.replaceRange(gradientIndex, closeParenIndex, 'color: Colors.white');
      modified = true;
    }

    // Now for `gradient: isSelected ? const LinearGradient(...) : const LinearGradient(...)`
    while(true) {
      int gradientIndex = content.indexOf('gradient: isSelected');
      if (gradientIndex == -1) break;
      
      // Let's just find the end of the ternary expression, which is usually `)` or `,`
      int endIndex = content.indexOf('),', gradientIndex);
      if (endIndex == -1) break;
      // This is risky, let's just do a specific replace for the tabs in history_screen
      content = content.replaceRange(gradientIndex, endIndex + 1, 'color: isSelected ? const Color(0xFF00695C) : Colors.white');
      modified = true;
    }

    if (modified) {
      print('Updated \${file.path}');
      file.writeAsStringSync(content);
    }
  }
}
