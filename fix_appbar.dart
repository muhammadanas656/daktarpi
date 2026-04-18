import 'dart:io';

void main() {
  replaceAppBar('lib/features/doctors/presentation/screens/popular_doctors_screen.dart');
}

void replaceAppBar(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) return;
  
  var content = file.readAsStringSync();
  
  // Find the AppBar start and count braces
  final startIndex = content.indexOf('appBar: AppBar(');
  if (startIndex == -1) return;
  
  int braceCount = 0;
  int endIndex = -1;
  bool inAppBar = false;
  
  for (int i = startIndex; i < content.length; i++) {
    if (content[i] == '(') {
      if (!inAppBar) inAppBar = true;
      braceCount++;
    } else if (content[i] == ')') {
      braceCount--;
      if (inAppBar && braceCount == 0) {
        endIndex = i;
        break;
      }
    }
  }
  
  if (endIndex != -1) {
    // If it's a comma after, include it
    if (endIndex + 1 < content.length && content[endIndex + 1] == ',') {
      endIndex++;
    }
    
    final substitution = '''appBar: CustomAppBar(
        title: (_activeRadiusKm ?? 500.0) <= _popularHighlightRangeKm
            ? "Popular Doctors"
            : "Recommended Specialists",
      ),''';
      
    content = content.replaceRange(startIndex, endIndex + 1, substitution);
    
    if (!content.contains('custom_app_bar.dart')) {
      final importIndex = content.indexOf('import ');
      if (importIndex != -1) {
        content = content.replaceRange(importIndex, importIndex, "import '../../../../core/widgets/custom_app_bar.dart';\n");
      }
    }
    
    file.writeAsStringSync(content);
    print('Updated \$filePath');
  }
}
