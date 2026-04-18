import 'dart:io';

void main() {
  final file = File('lib/core/main_wrapper/main_wrapper.dart');
  var content = file.readAsStringSync();

  content = content.replaceAll(
    'late AnimationController _springController;',
    'late AnimationController _springController;\n  late AnimationController _introController;'
  );

  content = content.replaceAll(
    '_springController.dispose();',
    '_springController.dispose();\n    _introController.dispose();'
  );

  content = content.replaceAll(
'''              child: AnimatedBuilder(
                animation: _drawerController,
                builder: (context, child) {
                  final double val = _drawerController.value;
                  final double clampedVal = val.clamp(0.0, 1.0).toDouble();
                  final double dockY = val * -100.0;
                  final double dockScale = 1.0 - (clampedVal * 0.3);

                  return IgnorePointer(
                    ignoring: val > 0.0,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform:
                          Matrix4.identity()
                            ..translate(0.0, dockY, 0.0)
                            ..scale(dockScale),
                      child: Opacity(
                        opacity: math.max(0.0, 1.0 - (clampedVal * 2.5)),
                        child: child,
                      ),
                    ),
                  );
                },''',
'''              child: AnimatedBuilder(
                animation: Listenable.merge([_drawerController, _introController]),
                builder: (context, child) {
                  final double val = _drawerController.value;
                  final double introVal = CurvedAnimation(parent: _introController, curve: Curves.easeOutQuart).value;
                  final double introOffset = (1.0 - introVal) * 150.0;

                  final double clampedVal = val.clamp(0.0, 1.0).toDouble();
                  final double dockY = (val * -100.0) + introOffset;
                  final double dockScale = 1.0 - (clampedVal * 0.3);

                  return IgnorePointer(
                    ignoring: val > 0.0,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform:
                          Matrix4.identity()
                            ..translate(0.0, dockY, 0.0)
                            ..scale(dockScale),
                      child: Opacity(
                        opacity: (introVal) * math.max(0.0, 1.0 - (clampedVal * 2.5)),
                        child: child,
                      ),
                    ),
                  );
                },'''    
  );

  
  content = content.replaceAll(
'''              child: AnimatedBuilder(
                animation: _drawerController,
                builder: (context, child) {
                  final double val = _drawerController.value;
                  final double clampedVal = val.clamp(0.0, 1.0).toDouble();
                  final double dockY = val * -100.0;
                  final double dockScale = 1.0 - (clampedVal * 0.3);

                  return IgnorePointer(
                    ignoring: val > 0.0,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform:
                          Matrix4.identity()
                            ..translate(0.0, dockY, 0.0)
                            ..scale(dockScale),
                      child: Opacity(
                        opacity: math.max(0.0, 1.0 - (clampedVal * 2.5)),
                        child: child,
                      ),
                    ),
                  );
                },'''.replaceAll('\n', '\r\n'),
'''              child: AnimatedBuilder(
                animation: Listenable.merge([_drawerController, _introController]),
                builder: (context, child) {
                  final double val = _drawerController.value;
                  final double introVal = CurvedAnimation(parent: _introController, curve: Curves.easeOutQuart).value;
                  final double introOffset = (1.0 - introVal) * 150.0;

                  final double clampedVal = val.clamp(0.0, 1.0).toDouble();
                  final double dockY = (val * -100.0) + introOffset;
                  final double dockScale = 1.0 - (clampedVal * 0.3);

                  return IgnorePointer(
                    ignoring: val > 0.0,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform:
                          Matrix4.identity()
                            ..translate(0.0, dockY, 0.0)
                            ..scale(dockScale),
                      child: Opacity(
                        opacity: (introVal) * math.max(0.0, 1.0 - (clampedVal * 2.5)),
                        child: child,
                      ),
                    ),
                  );
                },'''.replaceAll('\n', '\r\n') 
  );

  file.writeAsStringSync(content);
}
