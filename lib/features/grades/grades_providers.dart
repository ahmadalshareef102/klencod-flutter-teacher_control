import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/grades_models.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import 'data/grades_repository.dart';
import 'grade_calc.dart';

final gradesRepositoryProvider = Provider<GradesRepository>(
  (ref) => GradesRepository(ref.watch(coreDatabaseProvider)),
);

final sheetsProvider = StreamProvider<List<SheetSummary>>(
  (ref) => ref.watch(gradesRepositoryProvider).watchSheets(),
);

final sheetDataProvider = StreamProvider.family<SheetData?, int>(
  (ref, id) => ref.watch(gradesRepositoryProvider).watchSheetData(id),
);

final gradeScaleProvider = Provider<GradeScale>((ref) {
  final raw = ref.watch(settingsProvider).valueOrNull?.gradeScale;
  return GradeScale.parse(raw);
});
