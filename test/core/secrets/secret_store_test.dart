import 'package:ai_writer/core/secrets/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PrefsSecretStore round-trips secret values', () async {
    final store = PrefsSecretStore();
    await store.write('token', 'pat-123');
    expect(await store.read('token'), 'pat-123');
    await store.delete('token');
    expect(await store.read('token'), isNull);
  });
}
