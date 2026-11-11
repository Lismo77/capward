import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gansey/core/router.dart';

void main() {
  // The shell's Scaffold already makes room for the keyboard. A page inside
  // it (with its own Scaffold) must not make room a second time, or its body
  // shrinks to nothing and the screen above the keyboard goes blank.
  testWidgets('a page inside the shell makes room for the keyboard once',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 812);
    tester.view.viewInsets = const FakeViewPadding(bottom: 403);
    addTearDown(tester.view.reset);

    const body = Key('page-body');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: HomeShell(
            location: '/wardrobe/new',
            child: Scaffold(
              appBar: AppBar(title: const Text('Add item')),
              body: const SizedBox.expand(key: body),
            ),
          ),
        ),
      ),
    );

    // 812 tall, 403 of keyboard, 56 of app bar.
    expect(tester.getSize(find.byKey(body)).height, 812 - 403 - 56);
  });
}
