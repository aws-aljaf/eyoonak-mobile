import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_saas_driver/features/family_life/presentation/managed_banner_carousel.dart';

List<Map<String, dynamic>> slides(int count) => [
      for (var i = 0; i < count; i++)
        {
          'id': i + 1,
          'title': 'شريحة ${i + 1}',
          'body': 'وصف قصير من لوحة الإدارة',
          'page_id': 50 + i
        }
    ];
Finder currentSlide(int index, int count) => find.byWidgetPredicate((widget) =>
    widget is Semantics &&
    widget.properties.label == 'الشريحة $index من $count');
Widget screen(List<Map<String, dynamic>> rows,
        void Function(Map<String, dynamic>) open, {bool reduced = false}) =>
    MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: ManagedBannerCarousel(rows: rows, onOpen: open)))));
void main() {
  testWidgets('CMS subtitle and page link open the selected internal page',
      (tester) async {
    int? opened;
    await tester
        .pumpWidget(screen(slides(1), (row) => opened = row['page_id'] as int));
    await tester.pumpAndSettle();
    expect(find.text('وصف قصير من لوحة الإدارة'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'اعرف أكثر'));
    expect(opened, 50);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'autoplay advances and pause persists while manual next remains usable',
      (tester) async {
    await tester.pumpWidget(screen(slides(2), (_) {}));
    await tester.pumpAndSettle();
    expect(currentSlide(1, 2), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 600));
    expect(currentSlide(2, 2), findsOneWidget);
    await tester.tap(find.byTooltip('إيقاف التقليب التلقائي'));
    await tester.pump(const Duration(seconds: 15));
    expect(currentSlide(2, 2), findsOneWidget);
    await tester.tap(find.byTooltip('الشريحة التالية'));
    await tester.pumpAndSettle();
    expect(currentSlide(1, 2), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'reduced motion prevents autoplay and many slides fit a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen(slides(20), (_) {}, reduced: true));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 15));
    expect(currentSlide(1, 20), findsOneWidget);
    expect(find.byTooltip('إيقاف التقليب التلقائي'), findsNothing);
    await tester.tap(find.byTooltip('الشريحة التالية'));
    await tester.pumpAndSettle();
    expect(currentSlide(2, 20), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
