import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gansey/features/feedback/presentation/feedback_screen.dart';
import 'package:gansey/features/wardrobe/data/item_repository.dart';
import 'package:gansey/features/wardrobe/domain/item.dart';
import 'package:gansey/features/wardrobe/presentation/wardrobe_screen.dart';

void main() {
  // #28: picking an outfit one category at a time.
  testWidgets('category chips keep the selection', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        itemsProvider.overrideWith((ref) async => const [
              Item(id: 1, name: 'Oxford', category: ItemCategory.top),
              Item(id: 2, name: 'Chinos', category: ItemCategory.bottom),
            ]),
      ],
      child: const MaterialApp(home: WardrobeScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Oxford'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    // The chip; item cards also show their category.
    await tester.tap(find.text('Bottom').first);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Chinos'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    // Deselect all only clears what's on screen (the chinos).
    await tester.tap(find.byTooltip('Deselect all'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
  });

  // #27: the form empties once the report has gone somewhere, with Undo.
  testWidgets('feedback form clears after copying, and Undo restores it',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    // Tall enough to show every button without scrolling.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FeedbackScreen())),
    );
    await tester.pumpAndSettle();

    final summary = find.widgetWithText(TextField, 'Short summary');
    await tester.enterText(summary, 'Filters clear selection');
    await tester.tap(find.text('Copy text'));
    await tester.pumpAndSettle();

    expect(find.text('Filters clear selection'), findsNothing);
    expect(find.text('Copied. Form cleared.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Filters clear selection'), findsOneWidget);
  });
}
