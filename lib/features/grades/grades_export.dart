import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/grades_models.dart';
import 'grade_calc.dart';

PdfPageFormat _format(String size, bool landscape) {
  final base = switch (size) {
    'A5' => PdfPageFormat.a5,
    'A3' => PdfPageFormat.a3,
    _ => PdfPageFormat.a4,
  };
  return landscape ? base.landscape : base;
}

List<String> _infoLines(GradeSheet sheet) {
  final f = sheet.fields;
  final years = [f.gregorianYear, f.hijriYear.isEmpty ? '' : '${f.hijriYear} هـ']
      .where((e) => e.isNotEmpty)
      .join(' - ');
  final cls = [f.gradeLevel, f.section].where((e) => e.isNotEmpty).join(' / ');
  return [
    if (f.subject.isNotEmpty) 'المادة: ${f.subject}',
    if (cls.isNotEmpty) 'الصف/الشعبة: $cls',
    if (f.semester.isNotEmpty) f.semester,
    if (f.month.isNotEmpty) 'الشهر: ${f.month}',
    if (years.isNotEmpty) 'العام الدراسي: $years',
  ];
}

String _percentText(double? p) => p == null ? '-' : '${p.toStringAsFixed(1)}%';

/// يبني ملف PDF لكشف الدرجات (عربي RTL، خط Cairo المضمّن).
Future<Uint8List> buildGradesPdf({
  required SheetData data,
  required GradeScale scale,
  required String schoolName,
  required String teacherName,
  required String size,
  required bool landscape,
}) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));

  pw.Widget t(
    String s, {
    bool isBold = false,
    double fontSize = 10,
    pw.TextAlign align = pw.TextAlign.center,
    pw.TextDirection dir = pw.TextDirection.rtl,
  }) =>
      pw.Text(
        s,
        textDirection: dir,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      );

  pw.Widget cell(pw.Widget child) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        child: pw.Center(child: child),
      );

  pw.Widget numCell(String s, {bool isBold = false}) =>
      cell(t(s, isBold: isBold, dir: pw.TextDirection.ltr));

  // الأعمدة بالترتيب المنطقي (من اليمين لليسار)، ثم نعكسها للرسم لأن الجدول يُرسم من اليسار.
  final headers = <String>[
    'م',
    'اسم الطالب',
    for (final c in data.columns) '${c.title}\n(${fmtNum(c.maxScore)})',
    'المجموع',
    'النسبة',
    'التقدير',
  ];
  final totalMax = data.columns.fold<double>(0, (a, c) => a + c.maxScore);
  headers[headers.length - 3] = 'المجموع\n(${fmtNum(totalMax)})';

  final logicalWidths = <pw.TableColumnWidth>[
    const pw.FixedColumnWidth(26),
    const pw.FlexColumnWidth(4),
    for (final _ in data.columns) const pw.FlexColumnWidth(1.3),
    const pw.FlexColumnWidth(1.4),
    const pw.FlexColumnWidth(1.4),
    const pw.FlexColumnWidth(1.7),
  ];
  final widths = <int, pw.TableColumnWidth>{
    for (var i = 0; i < logicalWidths.length; i++)
      logicalWidths.length - 1 - i: logicalWidths[i],
  };

  final rows = <pw.TableRow>[
    pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        for (final h in headers.reversed) cell(t(h, isBold: true, fontSize: 9)),
      ],
    ),
  ];

  var percentSum = 0.0;
  var percentCount = 0;
  for (var i = 0; i < data.students.length; i++) {
    final s = data.students[i];
    final byCol = data.scores[s.id] ?? const <int, double>{};
    final r = computeResult(scores: byCol, columns: data.columns, scale: scale);
    if (r.percent != null) {
      percentSum += r.percent!;
      percentCount++;
    }
    final logical = <pw.Widget>[
      numCell('${i + 1}'),
      cell(t(s.name, align: pw.TextAlign.right)),
      for (final c in data.columns)
        numCell(byCol[c.id] == null ? '' : fmtNum(byCol[c.id]!)),
      numCell(fmtNum(r.total), isBold: true),
      numCell(_percentText(r.percent)),
      cell(t(r.label, isBold: true)),
    ];
    rows.add(pw.TableRow(children: logical.reversed.toList()));
  }

  final info = _infoLines(data.sheet);
  final rightCol = [
    if (schoolName.isNotEmpty) schoolName,
    if (teacherName.isNotEmpty) 'المدرس: $teacherName',
  ];
  final avg = percentCount == 0 ? null : percentSum / percentCount;

  pw.Widget block(List<String> lines, pw.TextAlign align, {bool firstBold = false}) => pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: align == pw.TextAlign.right
              ? pw.CrossAxisAlignment.end
              : align == pw.TextAlign.left
                  ? pw.CrossAxisAlignment.start
                  : pw.CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < lines.length; i++)
              t(lines[i], align: align, isBold: firstBold && i == 0, fontSize: 10),
          ],
        ),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: _format(size, landscape),
      margin: const pw.EdgeInsets.all(24),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 6),
        child: t('${ctx.pageNumber} / ${ctx.pagesCount}', fontSize: 9, dir: pw.TextDirection.ltr),
      ),
      build: (ctx) => [
        // الترتيب المرسوم من اليسار: [يسار، وسط، يمين]
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            block(info, pw.TextAlign.left),
            block(['كشف درجات أعمال السنة', if (data.sheet.title.isNotEmpty) data.sheet.title],
                pw.TextAlign.center,
                firstBold: true),
            block(rightCol, pw.TextAlign.right),
          ],
        ),
        pw.SizedBox(height: 10),
        if (data.columns.isEmpty || data.students.isEmpty)
          t('لا توجد بيانات في هذا الكشف بعد.')
        else
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: widths,
            children: rows,
          ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            t('التوقيع: ....................', align: pw.TextAlign.left),
            t(
              'عدد الطلاب: ${data.students.length}'
              '${avg == null ? '' : '   متوسط النسبة: ${avg.toStringAsFixed(1)}%'}',
              align: pw.TextAlign.right,
            ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

/// يكتب ملف Excel مؤقتاً ويعيد مساره (للمشاركة/الحفظ).
Future<String> writeGradesExcel({
  required SheetData data,
  required GradeScale scale,
  required String schoolName,
  required String teacherName,
}) async {
  final book = xl.Excel.createExcel();
  final sheet = book['Sheet1'];

  sheet.appendRow([xl.TextCellValue('كشف درجات أعمال السنة - ${data.sheet.title}')]);
  if (schoolName.isNotEmpty) sheet.appendRow([xl.TextCellValue('المدرسة: $schoolName')]);
  if (teacherName.isNotEmpty) sheet.appendRow([xl.TextCellValue('المدرس: $teacherName')]);
  for (final line in _infoLines(data.sheet)) {
    sheet.appendRow([xl.TextCellValue(line)]);
  }
  sheet.appendRow([xl.TextCellValue('')]);

  final totalMax = data.columns.fold<double>(0, (a, c) => a + c.maxScore);
  sheet.appendRow([
    xl.TextCellValue('م'),
    xl.TextCellValue('اسم الطالب'),
    for (final c in data.columns) xl.TextCellValue('${c.title} (${fmtNum(c.maxScore)})'),
    xl.TextCellValue('المجموع (${fmtNum(totalMax)})'),
    xl.TextCellValue('النسبة %'),
    xl.TextCellValue('التقدير'),
  ]);

  for (var i = 0; i < data.students.length; i++) {
    final s = data.students[i];
    final byCol = data.scores[s.id] ?? const <int, double>{};
    final r = computeResult(scores: byCol, columns: data.columns, scale: scale);
    sheet.appendRow([
      xl.IntCellValue(i + 1),
      xl.TextCellValue(s.name),
      for (final c in data.columns)
        byCol[c.id] == null ? xl.TextCellValue('') : xl.DoubleCellValue(byCol[c.id]!),
      xl.DoubleCellValue(r.total),
      r.percent == null ? xl.TextCellValue('-') : xl.DoubleCellValue(r.percent!),
      xl.TextCellValue(r.label),
    ]);
  }

  final bytes = book.encode();
  if (bytes == null) throw StateError('تعذّر إنشاء ملف Excel');
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/grades_${data.sheet.id}.xlsx');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
