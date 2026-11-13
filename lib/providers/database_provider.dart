import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/core_database.dart';

final coreDatabaseProvider = Provider<CoreDatabase>(
  (ref) => throw UnimplementedError('coreDatabaseProvider must be overridden in main()'),
);

final todaySlotsProvider =
    StreamProvider.family<List<TimetableSlot>, int>((ref, day) {
  return ref.watch(coreDatabaseProvider).watchSlotsForDay(day);
});

final finalLessonCountProvider = StreamProvider<int>((ref) {
  return ref.watch(coreDatabaseProvider).watchFinalLessonCount();
});
