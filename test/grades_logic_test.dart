import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_control/core/utils/arabic_text.dart';
import 'package:teacher_control/features/grades/grade_calc.dart';
import 'package:teacher_control/models/grades_models.dart';

SheetColumn col(int id, double max) =>
    SheetColumn(id: id, sheetId: 1, title: 'c$id', maxScore: max);

void main() {
  group('computeResult', () {
    final cols = [col(1, 20), col(2, 30)];
    const scale = GradeScale();

    test('sums scores and computes percentage over total max', () {
      final r = computeResult(scores: {1: 18, 2: 27}, columns: cols, scale: scale);
      expect(r.total, 45);
      expect(r.maxTotal, 50);
      expect(r.percent, 90);
      expect(r.label, 'ممتاز');
    });

    test('missing score counts as zero', () {
      final r = computeResult(scores: {1: 10}, columns: cols, scale: scale);
      expect(r.total, 10);
      expect(r.percent, 20);
      expect(r.label, 'ضعيف');
    });

    test('no columns gives no percentage', () {
      final r = computeResult(scores: {}, columns: const [], scale: scale);
      expect(r.percent, isNull);
      expect(r.label, '-');
    });

    test('grade boundaries', () {
      expect(scale.labelFor(85), 'ممتاز');
      expect(scale.labelFor(84.99), 'جيد جداً');
      expect(scale.labelFor(75), 'جيد جداً');
      expect(scale.labelFor(65), 'جيد');
      expect(scale.labelFor(50), 'مقبول');
      expect(scale.labelFor(49.99), 'ضعيف');
    });

    test('decimal sums are rounded cleanly', () {
      final r = computeResult(
        scores: {1: 0.1, 2: 0.2},
        columns: [col(1, 1), col(2, 1)],
        scale: scale,
      );
      expect(r.total, 0.3);
    });
  });

  group('GradeScale', () {
    test('parse and serialize round trip', () {
      final g = GradeScale.parse('90,80,70,60');
      expect(g.excellent, 90);
      expect(g.pass, 60);
      expect(GradeScale.parse(g.serialize()).good, 70);
    });

    test('invalid input falls back to defaults', () {
      expect(GradeScale.parse('abc').excellent, 85);
      expect(GradeScale.parse('50,60,70,80').excellent, 85);
      expect(GradeScale.parse(null).pass, 50);
    });
  });

  test('fmtNum', () {
    expect(fmtNum(12), '12');
    expect(fmtNum(12.5), '12.5');
    expect(fmtNum(12.25), '12.25');
  });

  group('arabic text', () {
    test('normalize unifies alef, ya, ta marbuta and removes tashkeel', () {
      expect(normalizeArabic('أَحْمَد'), normalizeArabic('احمد'));
      expect(normalizeArabic('فاطمة'), normalizeArabic('فاطمه'));
      expect(normalizeArabic('علي'), normalizeArabic('على'));
    });

    test('alphabetical order by normalized key', () {
      final names = ['يوسف', 'أحمد', 'بكر', 'إبراهيم', 'ثابت'];
      names.sort((a, b) => normalizeArabic(a).compareTo(normalizeArabic(b)));
      expect(names, ['إبراهيم', 'أحمد', 'بكر', 'ثابت', 'يوسف']);
    });

    test('parseNameLines strips numbering and headers', () {
      const text = 'الاسم\n1- أحمد علي\n2. محمد صالح\n٣) خالد\n\n  \n4,سالم ناصر\n';
      expect(parseNameLines(text), ['أحمد علي', 'محمد صالح', 'خالد', 'سالم ناصر']);
    });

    test('parseNameLines takes the first text cell of a csv row', () {
      expect(parseNameLines('1,أحمد,90\n2,سعيد,80'), ['أحمد', 'سعيد']);
    });

    test('toLatinDigits', () {
      expect(toLatinDigits('١٢٫٥'), '12.5');
      expect(toLatinDigits('7,5'), '7.5');
    });
  });
}
