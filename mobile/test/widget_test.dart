import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dha_vault/main.dart';

void main() {
  testWidgets('DHA Vault App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DhaVaultApp(),
      ),
    );

    // Pump timer for splash screen transition
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(DhaVaultApp), findsOneWidget);
  });
}
