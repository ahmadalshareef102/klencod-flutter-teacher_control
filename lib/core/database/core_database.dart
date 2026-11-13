import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// صف من جدول الحصص الأسبوعي. day: 0=السبت ... 4=الأربعاء. period: 1..7.
class TimetableSlot {
  const TimetableSlot({
    required this.id,
    required this.day,
    required this.period,
    this.grade = '',
    this.section = '',
    this.subject = '',
    this.lessonTitle = '',
    this.startTime = '',
    this.endTime = '',
    this.notes = '',
  });

  final int id;
  final int day;
  final int period;
  final String grade;
  final String section;
  final String subject;
  final String lessonTitle;
  final String startTime;
  final String endTime;
  final String notes;

  factory TimetableSlot.fromMap(Map<String, Object?> m) => TimetableSlot(
        id: m['id'] as int,
        day: m['day'] as int,
        period: m['period'] as int,
        grade: (m['grade'] as String?) ?? '',
        section: (m['section'] as String?) ?? '',
        subject: (m['subject'] as String?) ?? '',
        lessonTitle: (m['lesson_title'] as String?) ?? '',
        startTime: (m['start_time'] as String?) ?? '',
        endTime: (m['end_time'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
      );
}

/// قاعدة بيانات كنترول المدرس (SQLite). قاعدة الجرس منفصلة داخل وحدة الجرس.
class CoreDatabase {
  CoreDatabase._(this.db);

  final Database db;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static const int version = 2;
  static const String fileName = 'teacher_control.db';

  static Future<CoreDatabase> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
    return CoreDatabase._(db);
  }

  static Future<void> _create(Database db, int v) async {
    await db.execute('''
      CREATE TABLE key_values(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE timetable_slots(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day INTEGER NOT NULL,
        period INTEGER NOT NULL,
        grade TEXT NOT NULL DEFAULT '',
        section TEXT NOT NULL DEFAULT '',
        subject TEXT NOT NULL DEFAULT '',
        lesson_title TEXT NOT NULL DEFAULT '',
        start_time TEXT NOT NULL DEFAULT '',
        end_time TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        UNIQUE(day, period)
      )''');
    await db.execute('''
      CREATE TABLE lesson_plans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'draft',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )''');
    await _createGradeTables(db);
  }

  static Future<void> _upgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) await _createGradeTables(db);
  }

  static Future<void> _createGradeTables(Database db) async {
    await db.execute('''
      CREATE TABLE grade_sheets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gregorian_year TEXT NOT NULL DEFAULT '',
        hijri_year TEXT NOT NULL DEFAULT '',
        semester TEXT NOT NULL DEFAULT '',
        month TEXT NOT NULL DEFAULT '',
        subject TEXT NOT NULL DEFAULT '',
        grade_level TEXT NOT NULL DEFAULT '',
        section TEXT NOT NULL DEFAULT '',
        paper_size TEXT NOT NULL DEFAULT 'A4',
        landscape INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE sheet_students(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sheet_id INTEGER NOT NULL REFERENCES grade_sheets(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        name_key TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        UNIQUE(sheet_id, name_key)
      )''');
    await db.execute('''
      CREATE TABLE sheet_columns(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sheet_id INTEGER NOT NULL REFERENCES grade_sheets(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        max_score REAL NOT NULL,
        position INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE sheet_scores(
        student_id INTEGER NOT NULL REFERENCES sheet_students(id) ON DELETE CASCADE,
        column_id INTEGER NOT NULL REFERENCES sheet_columns(id) ON DELETE CASCADE,
        value REAL NOT NULL,
        PRIMARY KEY(student_id, column_id)
      )''');
  }

  void notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> close() async {
    await _changes.close();
    await db.close();
  }

  /// يبثّ نتيجة الاستعلام فور الاشتراك ثم عند كل تغيير في البيانات.
  Stream<T> watch<T>(Future<T> Function() query) {
    late final StreamController<T> controller;
    StreamSubscription<void>? sub;

    Future<void> emit() async {
      try {
        final v = await query();
        if (!controller.isClosed) controller.add(v);
      } catch (e, s) {
        if (!controller.isClosed) controller.addError(e, s);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        sub = _changes.stream.listen((_) => emit());
        emit();
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

  // ---------- الإعدادات ----------
  Future<void> setValue(String key, String value) async {
    await db.insert(
      'key_values',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  Stream<Map<String, String>> watchAllValues() {
    return watch(() async {
      final rows = await db.query('key_values');
      return {for (final r in rows) r['key'] as String: r['value'] as String};
    });
  }

  // ---------- جدول الحصص ----------
  Stream<List<TimetableSlot>> watchSlotsForDay(int day) {
    return watch(() async {
      final rows = await db.query(
        'timetable_slots',
        where: 'day = ?',
        whereArgs: [day],
        orderBy: 'period ASC',
      );
      return rows.map(TimetableSlot.fromMap).toList();
    });
  }

  // ---------- التحاضير ----------
  Stream<int> watchFinalLessonCount() {
    return watch(() async {
      final r = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM lesson_plans WHERE status = 'final'",
      );
      return (r.first['c'] as int?) ?? 0;
    });
  }
}
