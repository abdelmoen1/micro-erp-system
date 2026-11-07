import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/product_repository.dart';

/// «قيمة البضاعة في المخزن» on the store-room tab. Invalidated after a sale, so the figure drops as
/// goods leave; the tab's pull-to-refresh and its own reloads fetch it again too.
final stockValueProvider = FutureProvider.autoDispose<StockValue>(
  (ref) => ref.watch(productRepositoryProvider).stockValue(),
);
