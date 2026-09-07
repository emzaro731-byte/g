import 'package:flutter_test/flutter_test.dart';

import 'package:iphone_style_launcher/launcher.dart';

void main() {
  testWidgets('Liquid launcher builds', (WidgetTester tester) async {
    await tester.pumpWidget(const LiquidLauncher());
    expect(find.byType(LiquidLauncher), findsOneWidget);
    expect(find.text('Liquid Glass Launcher'), findsOneWidget);
  });
}
