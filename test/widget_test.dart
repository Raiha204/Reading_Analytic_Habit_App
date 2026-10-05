import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_demo_app/main.dart';

void main() {
  testWidgets('shows the Reading Habit Analytics dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ReadingHabitAnalyticsApp(requireAuthentication: false),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(', Reader'), findsOneWidget);
    expect(find.text('Start your reading streak today'), findsOneWidget);
    expect(find.text('Your reading rhythm'), findsOneWidget);
    expect(find.text('Weekly activity'), findsOneWidget);
  });
}
