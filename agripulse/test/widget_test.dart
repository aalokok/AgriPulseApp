import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agripulse/app.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AgriPulseApp()),
    );
    // Verify the app renders
    expect(find.byType(AgriPulseApp), findsOneWidget);
  });
}
