import 'package:flutter_test/flutter_test.dart';

import 'package:ai_finance_tracker/main.dart';

void main() {
  testWidgets('App loads and shows splash screen text', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FinanceApp());

    // Verify that our splash screen text is shown.
    expect(find.text('AI Finance Tracker'), findsOneWidget);
  });
}

