import 'dart:io';

void main() {
  final dir = Directory('lib/features');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
  
  for (var file in files) {
    if (file.path.contains('custom_app_bar.dart')) continue;
    replaceIfMatches(file);
  }
}

void replaceIfMatches(File file) {
  var content = file.readAsStringSync();
  
  // Look for the specific boilerplate we want to replace.
  // AppBar( ... centerTitle: true, flexibleSpace: ClipRRect( ... BackdropFilter ... title: Text("TITLE" ...
  if (!content.contains('appBar: AppBar(')) return;
  if (!content.contains('flexibleSpace: ClipRRect(') && !content.contains('filter: ImageFilter.blur(')) return;

  int startIndex = 0;
  bool updated = false;

  while (true) {
    startIndex = content.indexOf('appBar: AppBar(', startIndex);
    if (startIndex == -1) break;

    int braceCount = 0;
    int endIndex = -1;
    bool inAppBar = false;
    
    // Find the end parenthesis of the AppBar
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
        String appBarBlock = content.substring(startIndex, endIndex + 1);
        if (appBarBlock.contains('flexibleSpace: ClipRRect(')) {
            // Find the title string precisely
            // Usually it looks like: title: Text("Global Search", style...
            // Or title: Text('Title', style...
            
            String title = "Unknown";
            final titleMatch = RegExp(r'title:\s*Text\(\s*[\"\'](.*?)[\"\']').firstMatch(appBarBlock);
            if (titleMatch != null) {
                title = titleMatch.group(1)!;
                
                // If there's a comma after, include it
                int replaceEnd = endIndex;
                if (replaceEnd + 1 < content.length && content[replaceEnd + 1] == ',') {
                    replaceEnd++;
                }

                final substitution = "appBar: CustomAppBar(title: '\$title'),";
                content = content.replaceRange(startIndex, replaceEnd + 1, substitution);
                updated = true;
                continue; // startIndex remains valid for next loop because we didn't advance it properly yet, but wait, the string gets shorter. It's safe to continue because the next `indexOf` searches after the replacement. Actually, next `indexOf` should continue from `startIndex`.
            }
        }
    }
    startIndex += 15; // advance
  }
  
  if (updated) {
    if (!content.contains('custom_app_bar.dart')) {
      final importIndex = content.indexOf('import ');
      if (importIndex != -1) {
        content = content.replaceRange(importIndex, importIndex, "import '../../../../core/widgets/custom_app_bar.dart';\n");
      }
    }
    file.writeAsStringSync(content);
    print("Updated \${file.path}");
  }
}
