// Basic smoke test: confirms the app tree builds without throwing.
//
// This was left over from `flutter create`'s default counter-app
// template (referenced a nonexistent `MyApp` and tested a counter that
// doesn't exist in Parchment). Replaced with a minimal build-only
// check instead of a full interaction test, since ParchmentApp's
// SplashScreen does async work (reading stored tokens) that isn't
// mocked here — asserting which screen it lands on would require
// mocking secure storage / network first.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parchment/main.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ParchmentApp()),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
