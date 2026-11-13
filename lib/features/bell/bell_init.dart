import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../school_bell/app/app_state.dart';

/// نتيجة تهيئة وحدة الجرس عند تشغيل التطبيق.
class BellInit {
  const BellInit({this.state, this.error});

  final AppState? state;
  final String? error;
}

final bellInitProvider = Provider<BellInit>(
  (ref) => throw UnimplementedError('bellInitProvider must be overridden in main()'),
);
