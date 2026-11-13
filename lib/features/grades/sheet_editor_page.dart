import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/arabic_text.dart';
import '../../models/app_settings.dart';
import '../../models/grades_models.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import 'data/grades_repository.dart';
import 'grade_calc.dart';
import 'grades_dialogs.dart';
import 'grades_export.dart';
import 'grades_providers.dart';
import 'sheet_form_page.dart';

const double _serialW = 44;
const double _nameW = 190;
const double _colW = 88;
const double _aggW = 78;
const double _labelW = 92;
const double _actionW = 44;
const double _rowH = 48;

class _Row {
  const _Row(this.serial, this.student, this.result);

  final int serial;
  final SheetStudent student;
  final StudentResult result;
}

/// شاشة الكشف: جدول الدرجات مع إدارة الطلاب والأعمدة والتصدير.
class SheetEditorPage extends ConsumerStatefulWidget {
  const SheetEditorPage({super.key, required this.sheetId});

  final int sheetId;

  @override
  ConsumerState<SheetEditorPage> createState() => _SheetEditorPageState();
}

class _SheetEditorPageState extends ConsumerState<SheetEditorPage> {
  final _search = TextEditingController();
  bool _searching = false;
  String _filter = 'الكل';

  GradesRepository get _repo => ref.read(gradesRepositoryProvider);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sheetDataProvider(widget.sheetId));
    final scale = ref.watch(gradeScaleProvider);
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('تعذّر تحميل الكشف: $e')),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('الكشف')),
            body: const Center(child: Text('هذا الكشف غير موجود (ربما حُذف).')),
          );
        }
        return _buildSheet(context, data, scale);
      },
    );
  }

  Widget _buildSheet(BuildContext context, SheetData data, GradeScale scale) {
    final scheme = Theme.of(context).colorScheme;
    final query = normalizeArabic(_search.text);

    final rows = <_Row>[];
    var percentSum = 0.0;
    var percentCount = 0;
    for (var i = 0; i < data.students.length; i++) {
      final s = data.students[i];
      final res = computeResult(
        scores: data.scores[s.id] ?? const <int, double>{},
        columns: data.columns,
        scale: scale,
      );
      if (res.percent != null) {
        percentSum += res.percent!;
        percentCount++;
      }
      if (query.isNotEmpty && !normalizeArabic(s.name).contains(query)) continue;
      if (_filter != 'الكل' && res.label != _filter) continue;
      rows.add(_Row(i + 1, s, res));
    }

    final tableW = _serialW +
        _nameW +
        data.columns.length * _colW +
        2 * _aggW +
        _labelW +
        _actionW;

    return Scaffold(
      appBar: AppBar(
        title: Text(data.sheet.title),
        actions: [
          IconButton(
            tooltip: 'بحث وتصفية',
            icon: Icon(_searching ? Icons.search_off_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _search.clear();
                _filter = 'الكل';
              }
            }),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _onMenu(v, data, scale),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('استيراد أسماء')),
              PopupMenuItem(value: 'sort', child: Text('ترتيب أبجدي الآن')),
              PopupMenuItem(value: 'scale', child: Text('سلم التقديرات')),
              PopupMenuItem(value: 'info', child: Text('بيانات الكشف')),
              PopupMenuItem(value: 'print', child: Text('طباعة')),
              PopupMenuItem(value: 'pdf', child: Text('تصدير PDF')),
              PopupMenuItem(value: 'excel', child: Text('تصدير Excel')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => showAddStudentDialog(context, _repo, data.sheet.id),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('طالب'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => showColumnDialog(context, _repo, data.sheet.id),
                    icon: const Icon(Icons.view_column_rounded),
                    label: const Text('عمود درجات'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showImportDialog(context, _repo, data.sheet.id),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('استيراد أسماء'),
                  ),
                ],
              ),
            ),
          ),
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'ابحث عن طالب',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _filter,
                    items: [
                      for (final l in ['الكل', ...GradeScale.labels])
                        DropdownMenuItem(value: l, child: Text(l)),
                    ],
                    onChanged: (v) => setState(() => _filter = v ?? 'الكل'),
                  ),
                ],
              ),
            ),
          if (data.columns.isEmpty || data.students.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                data.columns.isEmpty && data.students.isEmpty
                    ? 'ابدأ بإضافة عمود درجات (مثل: اختبار، واجبات) ثم أضف الطلاب أو استوردهم.'
                    : data.columns.isEmpty
                        ? 'أضف عمود درجات واحداً على الأقل لتبدأ إدخال الدرجات.'
                        : 'أضف الطلاب أو استوردهم من قائمة أسماء.',
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableW,
                child: Column(
                  children: [
                    _headerRow(context, data),
                    Expanded(
                      child: ListView.builder(
                        itemExtent: _rowH,
                        itemCount: rows.length,
                        itemBuilder: (ctx, i) => _studentRow(ctx, data, rows[i], i, scheme),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: scheme.surfaceContainerHighest,
            child: Text(
              'عدد الطلاب: ${data.students.length}'
              '${rows.length != data.students.length ? ' (المعروض ${rows.length})' : ''}'
              '${percentCount == 0 ? '' : '   •   متوسط النسبة: ${(percentSum / percentCount).toStringAsFixed(1)}%'}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellBox({
    required double width,
    required Widget child,
    Color? color,
    VoidCallback? onTap,
  }) {
    final box = Container(
      width: width,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.blueGrey.withAlpha(60), width: 0.5),
      ),
      child: child,
    );
    return onTap == null ? box : InkWell(onTap: onTap, child: box);
  }

  Widget _headerRow(BuildContext context, SheetData data) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary.withAlpha(36);
    TextStyle st = const TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          _cellBox(width: _serialW, color: bg, child: Text('م', style: st)),
          _cellBox(width: _nameW, color: bg, child: Text('اسم الطالب', style: st)),
          for (final c in data.columns)
            _cellBox(
              width: _colW,
              color: bg,
              onTap: () => showColumnDialog(context, _repo, data.sheet.id, column: c),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(c.title, style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('(${fmtNum(c.maxScore)})', style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          _cellBox(width: _aggW, color: bg, child: Text('المجموع', style: st)),
          _cellBox(width: _aggW, color: bg, child: Text('النسبة', style: st)),
          _cellBox(width: _labelW, color: bg, child: Text('التقدير', style: st)),
          _cellBox(width: _actionW, color: bg, child: const SizedBox.shrink()),
        ],
      ),
    );
  }

  Color _labelColor(String label) {
    switch (label) {
      case 'ممتاز':
        return const Color(0xFF2BA84A);
      case 'جيد جداً':
        return const Color(0xFF2E86DE);
      case 'جيد':
        return const Color(0xFF0D3B73);
      case 'مقبول':
        return Colors.orange.shade800;
      case 'ضعيف':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _studentRow(BuildContext context, SheetData data, _Row row, int index, ColorScheme scheme) {
    final s = row.student;
    final r = row.result;
    final zebra = index.isOdd ? scheme.onSurface.withAlpha(10) : null;
    final byCol = data.scores[s.id] ?? const <int, double>{};
    return Row(
      children: [
        _cellBox(width: _serialW, color: zebra, child: Text('${row.serial}')),
        _cellBox(
          width: _nameW,
          color: zebra,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
        for (final c in data.columns)
          _cellBox(
            width: _colW,
            color: zebra,
            child: _ScoreCell(
              key: ValueKey('${s.id}_${c.id}'),
              value: byCol[c.id],
              max: c.maxScore,
              onSave: (v) => _repo.setScore(s.id, c.id, v),
            ),
          ),
        _cellBox(
          width: _aggW,
          color: zebra,
          child: Text(fmtNum(r.total), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        _cellBox(
          width: _aggW,
          color: zebra,
          child: Text(r.percent == null ? '-' : '${r.percent!.toStringAsFixed(1)}%'),
        ),
        _cellBox(
          width: _labelW,
          color: zebra,
          child: Text(
            r.label,
            style: TextStyle(fontWeight: FontWeight.bold, color: _labelColor(r.label)),
          ),
        ),
        _cellBox(
          width: _actionW,
          color: zebra,
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (v) async {
              if (v == 'rename') {
                await showRenameStudentDialog(context, _repo, s);
              } else if (v == 'delete') {
                final ok = await confirmDialog(
                  context,
                  title: 'حذف الطالب',
                  message: 'سيُحذف «${s.name}» وكل درجاته من هذا الكشف. هل أنت متأكد؟',
                );
                if (ok) await _repo.deleteStudent(s.id);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('تعديل الاسم')),
              PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onMenu(String v, SheetData data, GradeScale scale) async {
    switch (v) {
      case 'import':
        await showImportDialog(context, _repo, data.sheet.id);
        break;
      case 'sort':
        await _repo.sortStudents(data.sheet.id);
        if (mounted) showSnack(context, 'تم ترتيب الأسماء أبجدياً، والدرجات بقيت مع أصحابها');
        break;
      case 'scale':
        final g = await showScaleDialog(context, scale);
        if (g != null) {
          await ref.read(coreDatabaseProvider).setValue(SettingsKeys.gradeScale, g.serialize());
        }
        break;
      case 'info':
        if (mounted) {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => SheetFormPage(sheetId: data.sheet.id),
          ));
        }
        break;
      case 'print':
      case 'pdf':
      case 'excel':
        await _export(v, data, scale);
        break;
    }
  }

  Future<void> _export(String kind, SheetData data, GradeScale scale) async {
    if (data.columns.isEmpty || data.students.isEmpty) {
      showSnack(context, 'أضف أعمدة وطلاباً قبل الطباعة أو التصدير');
      return;
    }
    final settings = ref.read(settingsProvider).valueOrNull ?? const AppSettings();
    try {
      if (kind == 'excel') {
        final path = await writeGradesExcel(
          data: data,
          scale: scale,
          schoolName: settings.schoolName,
          teacherName: settings.teacherName,
        );
        await Share.shareXFiles([XFile(path)], subject: data.sheet.title);
        return;
      }
      final opt = await showPageOptionsDialog(context, data.sheet);
      if (opt == null) return;
      await _repo.setPaper(data.sheet.id, opt.size, opt.landscape);
      final bytes = await buildGradesPdf(
        data: data,
        scale: scale,
        schoolName: settings.schoolName,
        teacherName: settings.teacherName,
        size: opt.size,
        landscape: opt.landscape,
      );
      if (kind == 'print') {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: data.sheet.title,
          dynamicLayout: false,
        );
      } else {
        await Printing.sharePdf(bytes: bytes, filename: 'كشف_الدرجات.pdf');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'تعذّر التنفيذ: $e');
    }
  }
}

/// خانة درجة: تُحفظ عند مغادرة الحقل أو الضغط على «التالي»، وترفض القيم خارج المدى.
class _ScoreCell extends StatefulWidget {
  const _ScoreCell({
    super.key,
    required this.value,
    required this.max,
    required this.onSave,
  });

  final double? value;
  final double max;
  final Future<void> Function(double? value) onSave;

  @override
  State<_ScoreCell> createState() => _ScoreCellState();
}

class _ScoreCellState extends State<_ScoreCell> {
  late final TextEditingController _c =
      TextEditingController(text: widget.value == null ? '' : fmtNum(widget.value!));
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _ScoreCell old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) {
      _c.text = widget.value == null ? '' : fmtNum(widget.value!);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final raw = toLatinDigits(_c.text.trim());
    if (raw.isEmpty) {
      if (widget.value != null) await widget.onSave(null);
      return;
    }
    final v = double.tryParse(raw);
    if (v == null || v < 0 || v > widget.max) {
      if (mounted) {
        showSnack(context, 'الدرجة يجب أن تكون بين 0 و ${fmtNum(widget.max)}');
        _c.text = widget.value == null ? '' : fmtNum(widget.value!);
      }
      return;
    }
    if (v != widget.value) await widget.onSave(v);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      focusNode: _focus,
      textAlign: TextAlign.center,
      textInputAction: TextInputAction.next,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[0-9\u0660-\u0669.,\u066B]')),
        LengthLimitingTextInputFormatter(7),
      ],
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 10),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }
}
