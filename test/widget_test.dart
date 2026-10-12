import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_final/main.dart';

void main() {
  testWidgets('MarketApp smoke test launches SplashScreen and navigates', (WidgetTester tester) async {
    await tester.pumpWidget(const MarketApp());
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('MARK'), findsNothing);
    expect(find.text('Connecting MSMEs to Potential Customers'), findsNothing);

    // Allow splash timer to complete and route
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
