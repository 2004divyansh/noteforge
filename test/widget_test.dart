import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteforge/app.dart';
import 'package:noteforge/core/database/database.dart';

void main() {
  testWidgets('NoteForgeApp renders home screen with initial state', (WidgetTester tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
        ],
        child: const NoteForgeApp(),
      ),
    );

    // Initial pump
    await tester.pumpAndSettle();

    // Verify app title and empty state text
    expect(find.text('All Notes'), findsOneWidget);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.text('New Note'), findsOneWidget);

    await database.close();
  });
}
