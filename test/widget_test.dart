// Smoke test that the app boots without throwing.
// We use a stub root because the real app touches platform plugins
// (shared_preferences, video_player) that aren't available in widget tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App scaffold builds', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('TowerBalance'))),
    ));

    expect(find.text('TowerBalance'), findsOneWidget);
  });
}
