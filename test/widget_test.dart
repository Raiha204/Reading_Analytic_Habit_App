import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:flutter_demo_app/features/library/presentation/pages/library_page.dart';
import 'package:flutter_demo_app/data/repositories/local_reading_store.dart';
import 'package:flutter_demo_app/app.dart';
import 'package:flutter_demo_app/domain/models/reading_models.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

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

  testWidgets('creates, edits, and removes a reading goal', (tester) async {
    await tester.pumpWidget(
      const ReadingHabitAnalyticsApp(requireAuthentication: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Read every day');
    await tester.enterText(find.byType(TextField).at(1), '15');
    await tester.tap(find.text('Add goal'));
    await tester.pumpAndSettle();
    expect(find.text('Read every day'), findsOneWidget);

    final goalMenu = find.byIcon(Icons.more_vert).last;
    await tester.ensureVisible(goalMenu);
    await tester.pumpAndSettle();
    await tester.tap(goalMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Read 20 pages');
    await tester.enterText(find.byType(TextField).at(1), '20');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Read 20 pages'), findsOneWidget);

    final updatedGoalMenu = find.byIcon(Icons.more_vert).last;
    await tester.ensureVisible(updatedGoalMenu);
    await tester.pumpAndSettle();
    await tester.tap(updatedGoalMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(find.text('Read 20 pages'), findsNothing);
  });

  testWidgets('edits a library book title without a dialog crash', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      title: 'Original title',
      author: 'Test author',
      progress: 0.2,
      coverColor: const Color(0xFF567C9B),
      status: 'In progress',
      createdAt: DateTime(2026, 1, 1),
    );
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'reading_books': jsonEncode([book.toJson(includeFileBytes: false)]),
        });
    final store = LocalReadingStore();
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryPage(
            store: store,
            onOpenBook: (_) {},
            onImportPdf: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bookMenu = find.byTooltip('Book options');
    await tester.ensureVisible(bookMenu);
    await tester.pumpAndSettle();
    await tester.tap(bookMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Updated title');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Updated title'), findsOneWidget);
    expect(tester.takeException(), isNull);
    store.dispose();
  });
}
