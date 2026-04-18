import 'dart:io';

void main() {
  final file = File('lib/core/main_wrapper/main_wrapper.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
'''    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );''',
'''    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _introController.forward(from: 0.0);
    });'''
  );

  content = content.replaceFirst(
'''    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );\r\n''',
'''    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );\r\n    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );\r\n    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _introController.forward(from: 0.0);
    });\r\n'''
  );

  file.writeAsStringSync(content);
}
