import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sepehr/screens/tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('telescope calculator derives magnification and exit pupil', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: ToolsScreen())));
    await tester.pumpAndSettle();

    expect(find.textContaining('۷۵٫۰×'), findsOneWidget);
    expect(find.textContaining('۲٫۰۰ میلی‌متر'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '200');
    await tester.pump();
    expect(find.textContaining('۱۰۰٫۰×'), findsOneWidget);
  });

  testWidgets('dark-adaptation timer starts, pauses, and resets', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: ToolsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('۲۰:۰۰'), findsOneWidget);

    await tester.ensureVisible(find.text('شروع'));
    await tester.tap(find.text('شروع'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('۱۹:۵۹'), findsOneWidget);

    await tester.tap(find.text('مکث'));
    await tester.pump();
    await tester.tap(find.byTooltip('شروع از ۲۰ دقیقه'));
    await tester.pump();
    expect(find.text('۲۰:۰۰'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
