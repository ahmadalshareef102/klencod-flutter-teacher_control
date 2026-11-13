import '../../models/grades_models.dart';

/// سلم التقديرات: الحدود الدنيا للنسبة المئوية لكل تقدير.
class GradeScale {
  const GradeScale({
    this.excellent = 85,
    this.veryGood = 75,
    this.good = 65,
    this.pass = 50,
  });

  final double excellent;
  final double veryGood;
  final double good;
  final double pass;

  static const labels = ['ممتاز', 'جيد جداً', 'جيد', 'مقبول', 'ضعيف'];

  bool get isValid =>
      pass > 0 && good > pass && veryGood > good && excellent > veryGood && excellent <= 100;

  String labelFor(double percent) {
    if (percent >= excellent) return labels[0];
    if (percent >= veryGood) return labels[1];
    if (percent >= good) return labels[2];
    if (percent >= pass) return labels[3];
    return labels[4];
  }

  String serialize() => '$excellent,$veryGood,$good,$pass';

  factory GradeScale.parse(String? s) {
    if (s == null || s.isEmpty) return const GradeScale();
    final p = s.split(',').map(double.tryParse).toList();
    if (p.length != 4 || p.any((e) => e == null)) return const GradeScale();
    final g = GradeScale(
      excellent: p[0]!,
      veryGood: p[1]!,
      good: p[2]!,
      pass: p[3]!,
    );
    return g.isValid ? g : const GradeScale();
  }
}

class StudentResult {
  const StudentResult({
    required this.total,
    required this.maxTotal,
    required this.percent,
    required this.label,
  });

  final double total;
  final double maxTotal;

  /// null إذا لم تُضف أعمدة بعد.
  final double? percent;
  final String label;
}

/// المجموع = مجموع الدرجات المدخلة (الخانة الفارغة = 0)،
/// والنسبة = المجموع ÷ مجموع الدرجات العظمى لكل الأعمدة.
StudentResult computeResult({
  required Map<int, double> scores,
  required List<SheetColumn> columns,
  required GradeScale scale,
}) {
  var total = 0.0;
  var maxTotal = 0.0;
  for (final c in columns) {
    maxTotal += c.maxScore;
    total += scores[c.id] ?? 0;
  }
  total = (total * 100).round() / 100;
  maxTotal = (maxTotal * 100).round() / 100;
  if (maxTotal <= 0) {
    return StudentResult(total: total, maxTotal: maxTotal, percent: null, label: '-');
  }
  final percent = ((total / maxTotal * 100) * 100).round() / 100;
  return StudentResult(
    total: total,
    maxTotal: maxTotal,
    percent: percent,
    label: scale.labelFor(percent),
  );
}

/// 12.0 -> "12" ، 12.5 -> "12.5" ، 12.25 -> "12.25"
String fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}
