// On a real phone (US-1306), with Android Keystore-backed storage:
//   flutter test integration_test/auth_flow_test.dart --dart-define-from-file=env/dev.json
import 'package:integration_test/integration_test.dart';
import 'package:smartshop/core/config/env.dart';
import 'package:smartshop/core/storage/key_value_store.dart';

import 'auth_scenarios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var n = 0;
  defineAuthScenarios(
    baseUrl: Env.apiBaseUrl,
    // Each scenario gets its own namespace inside the real secure storage.
    newStore: () => _PrefixedStore(SecureKeyValueStore(), 'it${n++}.'),
  );
}

class _PrefixedStore implements KeyValueStore {
  _PrefixedStore(this._inner, this._prefix);

  final KeyValueStore _inner;
  final String _prefix;

  @override
  Future<String?> read(String key) => _inner.read('$_prefix$key');

  @override
  Future<void> write(String key, String value) => _inner.write('$_prefix$key', value);

  @override
  Future<void> delete(String key) => _inner.delete('$_prefix$key');

  @override
  Future<Map<String, String>> readAll() async => {
    for (final e in (await _inner.readAll()).entries)
      if (e.key.startsWith(_prefix)) e.key.substring(_prefix.length): e.value,
  };
}
