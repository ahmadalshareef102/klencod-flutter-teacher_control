import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/utils/arabic_text.dart';
import '../../models/grades_models.dart';
import 'data/grades_repository.dart';
import 'grade_calc.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'حذف',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmText)),
      ],
    ),
  );
  return r ?? false;
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// إضافة طلاب واحداً تلو الآخر: تبقى النافذة مفتوحة بعد كل إضافة ناجحة.
Future<void> showAddStudentDialog(
  BuildContext context,
  GradesRepository repo,
  int sheetId,
) async {
  final c = TextEditingController();
  String? msg;
  var isError = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        Future<void> submit() async {
          final name = cleanName(c.text);
          final e = await repo.addStudent(sheetId, c.text);
          setS(() {
            if (e == null) {
              msg = 'تمت إضافة: $name';
              isError = false;
              c.clear();
            } else {
              msg = e;
              isError = true;
            }
          });
        }

        return AlertDialog(
          title: const Text('إضافة طالب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'اسم الطالب'),
                onSubmitted: (_) => submit(),
              ),
              if (msg != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    msg!,
                    style: TextStyle(
                      color: isError
                          ? Theme.of(ctx).colorScheme.error
                          : Theme.of(ctx).colorScheme.tertiary,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
            FilledButton(onPressed: submit, child: const Text('إضافة')),
          ],
        );
      },
    ),
  );
  c.dispose();
}

Future<void> showRenameStudentDialog(
  BuildContext context,
  GradesRepository repo,
  SheetStudent student,
) async {
  final c = TextEditingController(text: student.name);
  String? error;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('تعديل اسم الطالب'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: 'اسم الطالب', errorText: error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final e = await repo.renameStudent(student.id, c.text);
              if (e == null) {
                if (ctx.mounted) Navigator.pop(ctx);
              } else {
                setS(() => error = e);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  c.dispose();
}

/// استيراد أسماء من نص ملصوق أو ملف txt/csv.
Future<void> showImportDialog(
  BuildContext context,
  GradesRepository repo,
  int sheetId,
) async {
  final c = TextEditingController();
  String? error;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('استيراد أسماء الطلاب'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اكتب أو الصق الأسماء، اسم في كل سطر (يمكنك نسخها من Excel أو Word).'),
              const SizedBox(height: 8),
              TextField(
                controller: c,
                minLines: 6,
                maxLines: 10,
                decoration: InputDecoration(errorText: error, hintText: 'أحمد علي\nمحمد صالح'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('من ملف (txt / csv)'),
                onPressed: () async {
                  try {
                    final r = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const ['txt', 'csv'],
                      withData: true,
                    );
                    final bytes = r?.files.single.bytes;
                    if (bytes == null) return;
                    setS(() {
                      c.text = utf8.decode(bytes, allowMalformed: true);
                      error = null;
                    });
                  } catch (e) {
                    setS(() => error = 'تعذّرت قراءة الملف: $e');
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final names = parseNameLines(c.text);
              if (names.isEmpty) {
                setS(() => error = 'لم أجد أسماء صالحة في النص');
                return;
              }
              final res = await repo.importNames(sheetId, names);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                showSnack(
                  context,
                  'أُضيف ${res.added} طالب'
                  '${res.duplicates > 0 ? ' وتُخطّي ${res.duplicates} مكرراً' : ''}',
                );
              }
            },
            child: const Text('استيراد'),
          ),
        ],
      ),
    ),
  );
  c.dispose();
}

/// إضافة عمود، أو تعديله/حذفه إذا مُرّر [column].
Future<void> showColumnDialog(
  BuildContext context,
  GradesRepository repo,
  int sheetId, {
  SheetColumn? column,
}) async {
  final title = TextEditingController(text: column?.title ?? '');
  final max = TextEditingController(text: column == null ? '' : fmtNum(column.maxScore));
  String? error;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(column == null ? 'إضافة عمود درجات' : 'تعديل العمود'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم العمود',
                hintText: 'مثال: اختبار شهري، واجبات، مشاركة',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: max,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'الدرجة العظمى', errorText: error),
            ),
          ],
        ),
        actions: [
          if (column != null)
            TextButton(
              onPressed: () async {
                final ok = await confirmDialog(
                  ctx,
                  title: 'حذف العمود',
                  message: 'سيُحذف العمود «${column.title}» وكل الدرجات المدخلة فيه. هل أنت متأكد؟',
                );
                if (!ok) return;
                await repo.deleteColumn(column.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('حذف', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final m = double.tryParse(toLatinDigits(max.text.trim()));
              if (m == null) {
                setS(() => error = 'أدخل رقماً صحيحاً');
                return;
              }
              final e = column == null
                  ? await repo.addColumn(sheetId, title.text, m)
                  : await repo.updateColumn(column.id, title.text, m);
              if (e == null) {
                if (ctx.mounted) Navigator.pop(ctx);
              } else {
                setS(() => error = e);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  max.dispose();
}

/// تعديل حدود التقديرات. يعيد السلم الجديد أو null عند الإلغاء.
Future<GradeScale?> showScaleDialog(BuildContext context, GradeScale current) async {
  final fields = [current.excellent, current.veryGood, current.good, current.pass]
      .map((v) => TextEditingController(text: fmtNum(v)))
      .toList();
  String? error;
  final result = await showDialog<GradeScale>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('سلم التقديرات'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('الحد الأدنى للنسبة المئوية لكل تقدير:'),
              const SizedBox(height: 8),
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: fields[i],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: GradeScale.labels[i]),
                  ),
                ),
              const Text('أقل من حد «مقبول» = ضعيف'),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, const GradeScale()),
            child: const Text('الافتراضي'),
          ),
          FilledButton(
            onPressed: () {
              final v = fields.map((f) => double.tryParse(toLatinDigits(f.text.trim()))).toList();
              if (v.any((e) => e == null)) {
                setS(() => error = 'أدخل أرقاماً صحيحة في كل الحقول');
                return;
              }
              final g = GradeScale(excellent: v[0]!, veryGood: v[1]!, good: v[2]!, pass: v[3]!);
              if (!g.isValid) {
                setS(() => error = 'يجب أن تتناقص الحدود: ممتاز > جيد جداً > جيد > مقبول > 0، وألا يتجاوز الأول 100');
                return;
              }
              Navigator.pop(ctx, g);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  for (final f in fields) {
    f.dispose();
  }
  return result;
}

typedef PageOptions = ({String size, bool landscape});

/// اختيار حجم الورق واتجاه الطباعة.
Future<PageOptions?> showPageOptionsDialog(BuildContext context, GradeSheet sheet) {
  var size = sheet.paperSize;
  var landscape = sheet.landscape;
  return showDialog<PageOptions>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('إعدادات الصفحة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('حجم الورق'),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'A4', label: Text('A4')),
                ButtonSegment(value: 'A5', label: Text('A5')),
                ButtonSegment(value: 'A3', label: Text('A3')),
              ],
              selected: {size},
              onSelectionChanged: (s) => setS(() => size = s.first),
            ),
            const SizedBox(height: 16),
            const Text('الاتجاه'),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('عمودي')),
                ButtonSegment(value: true, label: Text('أفقي')),
              ],
              selected: {landscape},
              onSelectionChanged: (s) => setS(() => landscape = s.first),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, (size: size, landscape: landscape)),
            child: const Text('متابعة'),
          ),
        ],
      ),
    ),
  );
}
