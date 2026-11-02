import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/app/splash_screen.dart';

void main() {
  for (final viewport in [
    const Size(360, 800),
    const Size(414, 896),
    const Size(768, 1024)
  ]) {
    testWidgets(
        'portrait artwork fills $viewport instead of landscape letterboxing',
        (tester) async {
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const contentKey = ValueKey('portrait-artwork');
      const frame = Center(
          child: SizedBox(
              key: contentKey,
              width: 607.5,
              height: 1080,
              child: ColoredBox(color: Colors.teal)));
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: SplashVideoViewport(
                  sourceSize: Size(1920, 1080), child: frame))));
      final box = tester.renderObject<RenderBox>(find.byKey(contentKey));
      final topLeft = box.localToGlobal(Offset.zero);
      final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
      expect(topLeft.dx, lessThanOrEqualTo(.01));
      expect(topLeft.dy, lessThanOrEqualTo(.01));
      expect(bottomRight.dx, greaterThanOrEqualTo(viewport.width - .01));
      expect(bottomRight.dy, greaterThanOrEqualTo(viewport.height - .01));
      expect(find.text('تخطّي'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
