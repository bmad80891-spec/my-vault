import 'package:flutter_test/flutter_test.dart';
import 'package:my_vault/main.dart';

void main() {
  testWidgets('My Vault starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MyVaultApp());

    expect(find.text('My Vault'), findsOneWidget);
    expect(find.text('Your digital life, safely stored.'), findsOneWidget);
  });
}
