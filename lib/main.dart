import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/database/core_database.dart';
import 'features/bell/bell_init.dart';
import 'features/school_bell/app/app_state.dart';
import 'features/school_bell/database/app_database.dart' as bell_db;
import 'providers/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');

  final core = await CoreDatabase.open();

  // وحدة الجرس المدرسي: تهيئتها عند كل تشغيل تعيد جدولة الأجراس القادمة.
  BellInit bell;
  try {
    final db = await bell_db.AppDatabase.open();
    final state = AppState(db);
    await state.init();
    bell = BellInit(state: state);
  } catch (e) {
    bell = BellInit(error: '$e');
  }

  runApp(ProviderScope(
    overrides: [
      coreDatabaseProvider.overrideWithValue(core),
      bellInitProvider.overrideWithValue(bell),
    ],
    child: const TeacherControlApp(),
  ));
}