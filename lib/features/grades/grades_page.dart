import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/arabic_text.dart';
import '../../models/grades_models.dart';
import 'grades_dialogs.dart';
import 'grades_providers.dart';
import 'sheet_editor_page.dart';
import 'sheet_form_page.dart';

/// قائمة كشوف الدرجات المحفوظة.
class GradesPage extends ConsumerStatefulWidget {
  const GradesPage({super.key});

  @override
  ConsumerState<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends ConsumerState<GradesPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(int id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SheetEditorPage(sheetId: id)),
    );
  }

  bool _matches(SheetSummary s, String q) {
    if (q.isEmpty) return true;
    final f = s.sheet.fields;
    final hay = normalizeArabic(
      [f.subject, f.gradeLevel, f.section, f.semester, f.month, f.gregorianYear, f.hijriYear]
          .join(' '),
    );
    return hay.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sheetsProvider);
    final repo = ref.read(gradesRepositoryProvider);
    final q = normalizeArabic(_search.text);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SheetFormPage()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('كشف جديد'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('تعذّر تحميل الكشوف: $e')),
        data: (sheets) {
          final list = sheets.where((s) => _matches(s, q)).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'بحث في الكشوف (مادة، صف، شعبة، شهر...)',
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            sheets.isEmpty
                                ? 'لا توجد كشوف بعد. اضغط «كشف جديد» لإنشاء أول كشف.'
                                : 'لا توجد نتائج مطابقة.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        itemCount: list.length,
                        itemBuilder: (ctx, i) {
                          final s = list[i];
                          final f = s.sheet.fields;
                          final sub = [
                            f.semester,
                            f.month,
                            '${s.studentCount} طالب',
                          ].where((e) => e.isNotEmpty).join(' • ');
                          return Card(
                            child: ListTile(
                              onTap: () => _open(s.sheet.id),
                              leading: const Icon(Icons.grading_rounded),
                              title: Text(s.sheet.title),
                              subtitle: Text(sub),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'open') {
                                    _open(s.sheet.id);
                                  } else if (v == 'edit') {
                                    Navigator.of(context).push(MaterialPageRoute<void>(
                                      builder: (_) => SheetFormPage(sheetId: s.sheet.id),
                                    ));
                                  } else if (v == 'copy') {
                                    await repo.duplicateSheet(s.sheet.id);
                                    if (context.mounted) showSnack(context, 'تم نسخ الكشف');
                                  } else if (v == 'delete') {
                                    final ok = await confirmDialog(
                                      context,
                                      title: 'حذف الكشف',
                                      message:
                                          'سيُحذف الكشف «${s.sheet.title}» بكل طلابه ودرجاته نهائياً. هل أنت متأكد؟',
                                    );
                                    if (ok) await repo.deleteSheet(s.sheet.id);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'open', child: Text('فتح')),
                                  PopupMenuItem(value: 'edit', child: Text('بيانات الكشف')),
                                  PopupMenuItem(value: 'copy', child: Text('نسخ الكشف')),
                                  PopupMenuItem(value: 'delete', child: Text('حذف')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
