class SheetFields {
  const SheetFields({
    this.gregorianYear = '',
    this.hijriYear = '',
    this.semester = '',
    this.month = '',
    this.subject = '',
    this.gradeLevel = '',
    this.section = '',
  });

  final String gregorianYear;
  final String hijriYear;
  final String semester;
  final String month;
  final String subject;
  final String gradeLevel;
  final String section;

  Map<String, Object?> toMap() => {
        'gregorian_year': gregorianYear,
        'hijri_year': hijriYear,
        'semester': semester,
        'month': month,
        'subject': subject,
        'grade_level': gradeLevel,
        'section': section,
      };
}

class GradeSheet {
  const GradeSheet({
    required this.id,
    required this.fields,
    required this.paperSize,
    required this.landscape,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final SheetFields fields;
  final String paperSize;
  final bool landscape;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get title {
    final f = fields;
    final cls = [f.gradeLevel, f.section].where((e) => e.isNotEmpty).join(' / ');
    final parts = [f.subject, cls].where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? 'كشف بدون عنوان' : parts.join(' - ');
  }

  factory GradeSheet.fromMap(Map<String, Object?> m) => GradeSheet(
        id: m['id'] as int,
        fields: SheetFields(
          gregorianYear: (m['gregorian_year'] as String?) ?? '',
          hijriYear: (m['hijri_year'] as String?) ?? '',
          semester: (m['semester'] as String?) ?? '',
          month: (m['month'] as String?) ?? '',
          subject: (m['subject'] as String?) ?? '',
          gradeLevel: (m['grade_level'] as String?) ?? '',
          section: (m['section'] as String?) ?? '',
        ),
        paperSize: (m['paper_size'] as String?) ?? 'A4',
        landscape: ((m['landscape'] as int?) ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch((m['created_at'] as int?) ?? 0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch((m['updated_at'] as int?) ?? 0),
      );
}

class SheetStudent {
  const SheetStudent({required this.id, required this.sheetId, required this.name});

  final int id;
  final int sheetId;
  final String name;

  factory SheetStudent.fromMap(Map<String, Object?> m) => SheetStudent(
        id: m['id'] as int,
        sheetId: m['sheet_id'] as int,
        name: m['name'] as String,
      );
}

class SheetColumn {
  const SheetColumn({
    required this.id,
    required this.sheetId,
    required this.title,
    required this.maxScore,
  });

  final int id;
  final int sheetId;
  final String title;
  final double maxScore;

  factory SheetColumn.fromMap(Map<String, Object?> m) => SheetColumn(
        id: m['id'] as int,
        sheetId: m['sheet_id'] as int,
        title: m['title'] as String,
        maxScore: (m['max_score'] as num).toDouble(),
      );
}

class SheetSummary {
  const SheetSummary(this.sheet, this.studentCount);

  final GradeSheet sheet;
  final int studentCount;
}

class SheetData {
  const SheetData({
    required this.sheet,
    required this.students,
    required this.columns,
    required this.scores,
  });

  final GradeSheet sheet;

  /// بالترتيب المعروض (حسب sort_order).
  final List<SheetStudent> students;
  final List<SheetColumn> columns;

  /// studentId -> (columnId -> درجة)
  final Map<int, Map<int, double>> scores;
}

class ImportResult {
  const ImportResult({required this.added, required this.duplicates});

  final int added;
  final int duplicates;
}
