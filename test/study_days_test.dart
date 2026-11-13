import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_control/core/utils/study_days.dart';

void main() {
  test('study day index runs Saturday to Wednesday', () {
    expect(studyDayIndex(DateTime(2026, 11, 14)), 0); // Saturday
    expect(studyDayIndex(DateTime(2026, 11, 15)), 1); // Sunday
    expect(studyDayIndex(DateTime(2026, 11, 16)), 2); // Monday
    expect(studyDayIndex(DateTime(2026, 11, 17)), 3); // Tuesday
    expect(studyDayIndex(DateTime(2026, 11, 18)), 4); // Wednesday
  });

  test('Thursday and Friday are not study days', () {
    expect(studyDayIndex(DateTime(2026, 11, 19)), isNull);
    expect(studyDayIndex(DateTime(2026, 11, 13)), isNull);
  });
}
