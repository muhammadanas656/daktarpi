import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/screens/home_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    'if (!_launchController.isAnimating && !_launchController.isCompleted) {\n          _launchController.forward();\n        }',
    '// removed staggered network delay'
  );
  content = content.replaceAll(
    'if (!_launchController.isAnimating && !_launchController.isCompleted) {\r\n          _launchController.forward();\r\n        }',
    '// removed staggered network delay'
  );
  
  content = content.replaceAll(
    'if (mounted && !_launchController.isCompleted) {\n        _launchController.forward();\n      }',
    '// removed staggered network delay'
  );
  content = content.replaceAll(
    'if (mounted && !_launchController.isCompleted) {\r\n        _launchController.forward();\r\n      }',
    '// removed staggered network delay'
  );
  
  file.writeAsStringSync(content);
}
