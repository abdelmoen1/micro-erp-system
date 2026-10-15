import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runApp(
    // Riverpod 3 retries failing providers by default; session errors must surface instead.
    ProviderScope(retry: (_, _) => null, child: const SmartShopApp()),
  );
}
