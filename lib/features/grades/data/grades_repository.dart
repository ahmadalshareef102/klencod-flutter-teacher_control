import 'package:sqflite/sqflite.dart';

import '../../../core/database/core_database.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../models/app_settings.dart';
import '../../../models/grades_models.dart';

/// كل عمليات كشوف الدرجات (كشوف، طلاب، أعمدة، درجات) على قاعدة SQLite.
/// الدوال التي تعيد String? تعيد رسالة الخطأ، أو null عند النجاح.
class GradesRepository {
  GradesRepository(this._core);

  final CoreDatabase _core;

  Database get _db => _core.db;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  // ---------------- قراءة ----------------
  Stream<List<SheetSummary>> watchSheets() {
    return _core.watch<List<SheetSummary>>(() async {
      final rows = await _db.rawQuery('''
        SELECT s.*, (SELECT COUNT(*) FROM sheet_students t WHERE t.sheet_id = s.id) AS student_count
        FROM grade_sheets s
        ORDER BY s.updated_at DESC, s.id DESC''');
      return rows
          .map((r) => SheetSummary(GradeSheet.fromMap(r), (r['student_count'] as int?) ?? 0))
          .toList();
    });
  }

  Future<GradeSheet?> getSheet(int id) async {
    final rows = await _db.query('grade_sheets', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : GradeSheet.fromMap(rows.first);
  }

  Stream<SheetData?> watchSheetData(int id) {
    return _core.watch<SheetData?>(() async {
      final sheets = await _db.query('grade_sheets', where: 'id = ?', whereArgs: [id]);
      if (sheets.isEmpty) return null;
      final students = await _db.query(
        'sheet_students',
        where: 'sheet_id = ?',
        whereArgs: [id],
        orderBy: 'sort_order ASC, id ASC',
      );
      final cols = await _db.query(
        'sheet_columns',
        where: 'sheet_id = ?',
        whereArgs: [id],
        orderBy: 'position ASC, id ASC',
      );
      final scoreRows = await _db.rawQuery('''
        SELECT sc.student_id, sc.column_id, sc.value
        FROM sheet_scores sc JOIN sheet_students st ON st.id = sc.student_id
        WHERE st.sheet_id = ?''', [id]);
      final scores = <int, Map<int, double>>{};
      for (final r in scoreRows) {
        final byCol = scores.putIfAbsent(r['student_id'] as int, () => <int, double>{});
        byCol[r['column_id'] as int] = (r['value'] as num).toDouble();
      }
      return SheetData(
        sheet: GradeSheet.fromMap(sheets.first),
        students: students.map(SheetStudent.fromMap).toList(),
        columns: cols.map(SheetColumn.fromMap).toList(),
        scores: scores,
      );
    });
  }

  // ---------------- الكشوف ----------------
  Future<int> createSheet(SheetFields f) async {
    final now = _now();
    final id = await _db.insert('grade_sheets', {
      ...f.toMap(),
      'paper_size': 'A4',
      'landscape': 0,
      'created_at': now,
      'updated_at': now,
    });
    _core.notifyChanged();
    return id;
  }

  Future<void> updateSheet(int id, SheetFields f) async {
    await _db.update(
      'grade_sheets',
      {...f.toMap(), 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
    _core.notifyChanged();
  }

  Future<void> setPaper(int id, String size, bool landscape) async {
    await _db.update(
      'grade_sheets',
      {'paper_size': size, 'landscape': landscape ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _core.notifyChanged();
  }

  Future<void> deleteSheet(int id) async {
    await _db.delete('grade_sheets', where: 'id = ?', whereArgs: [id]);
    _core.notifyChanged();
  }

  /// نسخة كاملة من الكشف (الطلاب والأعمدة والدرجات).
  Future<int> duplicateSheet(int id) async {
    final now = _now();
    late int newId;
    await _db.transaction((txn) async {
      final src = (await txn.query('grade_sheets', where: 'id = ?', whereArgs: [id])).first;
      final copy = Map<String, Object?>.of(src);
      copy.remove('id');
      copy['created_at'] = now;
      copy['updated_at'] = now;
      newId = await txn.insert('grade_sheets', copy);

      final colMap = <int, int>{};
      for (final c in await txn.query('sheet_columns', where: 'sheet_id = ?', whereArgs: [id])) {
        final m = Map<String, Object?>.of(c);
        m.remove('id');
        m['sheet_id'] = newId;
        colMap[c['id'] as int] = await txn.insert('sheet_columns', m);
      }
      final stMap = <int, int>{};
      for (final s in await txn.query('sheet_students', where: 'sheet_id = ?', whereArgs: [id])) {
        final m = Map<String, Object?>.of(s);
        m.remove('id');
        m['sheet_id'] = newId;
        stMap[s['id'] as int] = await txn.insert('sheet_students', m);
      }
      final scores = await txn.rawQuery('''
        SELECT sc.* FROM sheet_scores sc
        JOIN sheet_students st ON st.id = sc.student_id
        WHERE st.sheet_id = ?''', [id]);
      for (final r in scores) {
        final ns = stMap[r['student_id'] as int];
        final nc = colMap[r['column_id'] as int];
        if (ns == null || nc == null) continue;
        await txn.insert('sheet_scores', {'student_id': ns, 'column_id': nc, 'value': r['value']});
      }
    });
    _core.notifyChanged();
    return newId;
  }

  Future<void> _touch(int sheetId) async {
    await _db.update(
      'grade_sheets',
      {'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [sheetId],
    );
  }

  // ---------------- الطلاب ----------------
  Future<bool> _autoSort() async {
    final rows = await _db.query(
      'key_values',
      where: 'key = ?',
      whereArgs: [SettingsKeys.autoSortStudents],
    );
    return rows.isNotEmpty && rows.first['value'] == '1';
  }

  String? _validateName(String name) {
    if (name.isEmpty) return 'اكتب اسم الطالب';
    if (name.length > 80) return 'الاسم أطول من 80 حرفاً';
    return null;
  }

  Future<bool> _nameExists(int sheetId, String key, {int? exceptId}) async {
    final n = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM sheet_students WHERE sheet_id = ? AND name_key = ? AND id != ?',
      [sheetId, key, exceptId ?? -1],
    ));
    return (n ?? 0) > 0;
  }

  Future<String?> addStudent(int sheetId, String raw) async {
    final name = cleanName(raw);
    final err = _validateName(name);
    if (err != null) return err;
    final key = normalizeArabic(name);
    if (await _nameExists(sheetId, key)) return 'الطالب «$name» موجود مسبقاً في هذا الكشف';
    final next = Sqflite.firstIntValue(await _db.rawQuery(
          'SELECT COALESCE(MAX(sort_order), 0) + 1 FROM sheet_students WHERE sheet_id = ?',
          [sheetId],
        )) ??
        1;
    await _db.insert('sheet_students', {
      'sheet_id': sheetId,
      'name': name,
      'name_key': key,
      'sort_order': next,
    });
    if (await _autoSort()) await sortStudents(sheetId, notify: false);
    await _touch(sheetId);
    _core.notifyChanged();
    return null;
  }

  Future<String?> renameStudent(int studentId, String raw) async {
    final name = cleanName(raw);
    final err = _validateName(name);
    if (err != null) return err;
    final rows = await _db.query('sheet_students', where: 'id = ?', whereArgs: [studentId]);
    if (rows.isEmpty) return 'الطالب غير موجود';
    final sheetId = rows.first['sheet_id'] as int;
    final key = normalizeArabic(name);
    if (await _nameExists(sheetId, key, exceptId: studentId)) {
      return 'الطالب «$name» موجود مسبقاً في هذا الكشف';
    }
    await _db.update(
      'sheet_students',
      {'name': name, 'name_key': key},
      where: 'id = ?',
      whereArgs: [studentId],
    );
    if (await _autoSort()) await sortStudents(sheetId, notify: false);
    await _touch(sheetId);
    _core.notifyChanged();
    return null;
  }

  Future<void> deleteStudent(int studentId) async {
    final rows = await _db.query('sheet_students', where: 'id = ?', whereArgs: [studentId]);
    if (rows.isEmpty) return;
    await _db.delete('sheet_students', where: 'id = ?', whereArgs: [studentId]);
    await _touch(rows.first['sheet_id'] as int);
    _core.notifyChanged();
  }

  /// استيراد قائمة أسماء: يتخطى المكرر (داخل القائمة وفي الكشف).
  Future<ImportResult> importNames(int sheetId, List<String> names) async {
    var added = 0;
    var duplicates = 0;
    await _db.transaction((txn) async {
      final existing = <String>{
        for (final r in await txn.query('sheet_students',
            columns: ['name_key'], where: 'sheet_id = ?', whereArgs: [sheetId]))
          r['name_key'] as String,
      };
      var next = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COALESCE(MAX(sort_order), 0) FROM sheet_students WHERE sheet_id = ?',
            [sheetId],
          )) ??
          0;
      for (final raw in names) {
        final name = cleanName(raw);
        if (_validateName(name) != null) continue;
        final key = normalizeArabic(name);
        if (existing.contains(key)) {
          duplicates++;
          continue;
        }
        existing.add(key);
        next++;
        await txn.insert('sheet_students', {
          'sheet_id': sheetId,
          'name': name,
          'name_key': key,
          'sort_order': next,
        });
        added++;
      }
    });
    if (added > 0) {
      if (await _autoSort()) await sortStudents(sheetId, notify: false);
      await _touch(sheetId);
    }
    _core.notifyChanged();
    return ImportResult(added: added, duplicates: duplicates);
  }

  /// ترتيب أبجدي: يغيّر sort_order فقط، فتبقى الدرجات مرتبطة بكل طالب.
  Future<void> sortStudents(int sheetId, {bool notify = true}) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'sheet_students',
        columns: ['id', 'name_key'],
        where: 'sheet_id = ?',
        whereArgs: [sheetId],
      );
      final list = rows.map((r) => (r['id'] as int, r['name_key'] as String)).toList()
        ..sort((a, b) => a.$2.compareTo(b.$2));
      for (var i = 0; i < list.length; i++) {
        await txn.update(
          'sheet_students',
          {'sort_order': i + 1},
          where: 'id = ?',
          whereArgs: [list[i].$1],
        );
      }
    });
    if (notify) {
      await _touch(sheetId);
      _core.notifyChanged();
    }
  }

  // ---------------- الأعمدة ----------------
  String? _validateColumn(String title, double max) {
    if (title.isEmpty) return 'اكتب اسم العمود';
    if (title.length > 30) return 'اسم العمود أطول من 30 حرفاً';
    if (max <= 0 || max > 1000) return 'الدرجة العظمى يجب أن تكون بين 0 و 1000';
    return null;
  }

  Future<String?> addColumn(int sheetId, String rawTitle, double max) async {
    final title = cleanName(rawTitle);
    final err = _validateColumn(title, max);
    if (err != null) return err;
    final next = Sqflite.firstIntValue(await _db.rawQuery(
          'SELECT COALESCE(MAX(position), 0) + 1 FROM sheet_columns WHERE sheet_id = ?',
          [sheetId],
        )) ??
        1;
    await _db.insert('sheet_columns', {
      'sheet_id': sheetId,
      'title': title,
      'max_score': max,
      'position': next,
    });
    await _touch(sheetId);
    _core.notifyChanged();
    return null;
  }

  Future<String?> updateColumn(int columnId, String rawTitle, double max) async {
    final title = cleanName(rawTitle);
    final err = _validateColumn(title, max);
    if (err != null) return err;
    final rows = await _db.query('sheet_columns', where: 'id = ?', whereArgs: [columnId]);
    if (rows.isEmpty) return 'العمود غير موجود';
    final over = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM sheet_scores WHERE column_id = ? AND value > ?',
      [columnId, max],
    ));
    if ((over ?? 0) > 0) {
      return 'توجد درجات مدخلة أكبر من الدرجة العظمى الجديدة، عدّلها أولاً';
    }
    await _db.update(
      'sheet_columns',
      {'title': title, 'max_score': max},
      where: 'id = ?',
      whereArgs: [columnId],
    );
    await _touch(rows.first['sheet_id'] as int);
    _core.notifyChanged();
    return null;
  }

  Future<void> deleteColumn(int columnId) async {
    final rows = await _db.query('sheet_columns', where: 'id = ?', whereArgs: [columnId]);
    if (rows.isEmpty) return;
    await _db.delete('sheet_columns', where: 'id = ?', whereArgs: [columnId]);
    await _touch(rows.first['sheet_id'] as int);
    _core.notifyChanged();
  }

  // ---------------- الدرجات ----------------
  /// value == null يمسح الدرجة.
  Future<void> setScore(int studentId, int columnId, double? value) async {
    if (value == null) {
      await _db.delete(
        'sheet_scores',
        where: 'student_id = ? AND column_id = ?',
        whereArgs: [studentId, columnId],
      );
    } else {
      await _db.insert(
        'sheet_scores',
        {'student_id': studentId, 'column_id': columnId, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _db.rawUpdate(
      'UPDATE grade_sheets SET updated_at = ? WHERE id = (SELECT sheet_id FROM sheet_students WHERE id = ?)',
      [_now(), studentId],
    );
    _core.notifyChanged();
  }
}
