import 'package:flutter_test/flutter_test.dart';
import 'package:my_vault/vault_store.dart';

void main() {
  test('Vault entries preserve account fields when serialized', () {
    const entry = VaultEntry(
      id: 'test-1',
      service: 'Example',
      username: 'sample-user',
      email: 'sample@example.invalid',
      category: 'Social',
    );

    final restored = VaultEntry.fromJson(entry.toJson());

    expect(restored.id, entry.id);
    expect(restored.service, entry.service);
    expect(restored.username, entry.username);
    expect(restored.email, entry.email);
    expect(restored.category, entry.category);
  });
}
