import 'package:flutter_test/flutter_test.dart';
import 'package:market_final/main.dart';

void main() {
  testWidgets('MarketApp smoke test launches SplashScreen and navigates', (WidgetTester tester) async {
    await tester.pumpWidget(const MarketApp());
    expect(find.text('MARK'), findsOneWidget);
    expect(find.text('et'), findsOneWidget);
    expect(find.text('Connecting MSMEs to Potential Customers'), findsOneWidget);

    // Allow splash timer to complete and route
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
