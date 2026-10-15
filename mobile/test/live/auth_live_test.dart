// Host-side run of the US-1306 scenarios against a real local API (no phone):
//   flutter test test/live --dart-define=LIVE_API=http://127.0.0.1:8000/api/v1
// Skipped unless LIVE_API is set, so the normal suite and CI never need a server.
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/storage/key_value_store.dart';

import '../../integration_test/auth_scenarios.dart';

const _liveApi = String.fromEnvironment('LIVE_API');

void main() {
  group('live /api/v1 (host)', () {
    defineAuthScenarios(baseUrl: _liveApi, newStore: MemoryKeyValueStore.new);
  }, skip: _liveApi.isEmpty ? 'set --dart-define=LIVE_API=<base url> to run' : null);
}
