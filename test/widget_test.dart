import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:near_me/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame wrapped in ProviderScope.
    await tester.pumpWidget(
      const ProviderScope(
        child: NearMeApp(),
      ),
    );

    // Verify that the app mounts
    expect(find.byType(NearMeApp), findsOneWidget);
  });
}
