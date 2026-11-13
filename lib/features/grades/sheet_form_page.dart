import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/grades_models.dart';
import 'grades_providers.dart';
import 'sheet_editor_page.dart';

const _semesters = ['الفصل الأول', 'الفصل الثاني', 'العام الدراسي كاملاً'];
const _months = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// إنشاء كشف جديد أو تعديل بيانات كشف موجود.
class SheetFormPage extends ConsumerStatefulWidget {
  const SheetFormPage({super.key, this.sheetId});

  final int? sheetId;

  @override
  ConsumerState<SheetFormPage> createState() => _SheetFormPageState();
}

class _SheetFormPageState extends ConsumerState<SheetFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _greg = TextEditingController(text: '${DateTime.now().year}');
  final _hijri = TextEditingController();
  final _subject = TextEditingController();
  final _grade = TextEditingController();
  final _section = TextEditingController();
  String? _semester;
  String? _month;
  late bool _loading = widget.sheetId != null;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final id = widget.sheetId;
    if (id != null) {
      ref.read(gradesRepositoryProvider).getSheet(id).then((sheet) {
        if (!mounted) return;
        if (sheet != null) {
          final f = sheet.fields;
          _greg.text = f.gregorianYear;
          _hijri.text = f.hijriYear;
          _subject.text = f.subject;
          _grade.text = f.gradeLevel;
          _section.text = f.section;
          _semester = f.semester.isEmpty ? null : f.semester;
          _month = f.month.isEmpty ? null : f.month;
        }
        setState(() => _loading = false);
      });
    }
  }

  @override
  void dispose() {
    _greg.dispose();
    _hijri.dispose();
    _subject.dispose();
    _grade.dispose();
    _section.dispose();
    super.dispose();
  }

  String? _year(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (!RegExp('^[\\d\u0660-\u0669/\\- ]{1,12}\$').hasMatch(s)) return 'أدخل أرقاماً فقط';
    return null;
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? 'هذا الحقل مطلوب' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final fields = SheetFields(
      gregorianYear: _greg.text.trim(),
      hijriYear: _hijri.text.trim(),
      semester: _semester ?? '',
      month: _month ?? '',
      subject: _subject.text.trim(),
      gradeLevel: _grade.text.trim(),
      section: _section.text.trim(),
    );
    final repo = ref.read(gradesRepositoryProvider);
    final nav = Navigator.of(context);
    final id = widget.sheetId;
    if (id == null) {
      final newId = await repo.createSheet(fields);
      nav.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => SheetEditorPage(sheetId: newId)),
      );
    } else {
      await repo.updateSheet(id, fields);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.sheetId == null ? 'كشف جديد' : 'بيانات الكشف')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _greg,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'العام الميلادي'),
                          validator: _year,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _hijri,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'العام الهجري',
                            hintText: 'مثال: 1448',
                          ),
                          validator: _year,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _semester,
                    decoration: const InputDecoration(labelText: 'الفصل الدراسي'),
                    items: [
                      for (final s in _semesters) DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (v) => setState(() => _semester = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _month,
                    decoration: const InputDecoration(labelText: 'الشهر (اختياري)'),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('بدون شهر')),
                      for (final m in _months) DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (v) => setState(() => _month = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subject,
                    decoration: const InputDecoration(labelText: 'المادة الدراسية'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _grade,
                          decoration: const InputDecoration(labelText: 'الصف'),
                          validator: _required,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _section,
                          decoration: const InputDecoration(labelText: 'الشعبة'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(widget.sheetId == null ? 'إنشاء الكشف' : 'حفظ'),
                  ),
                ],
              ),
            ),
    );
  }
}
