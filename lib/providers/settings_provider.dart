import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import 'database_provider.dart';

final settingsProvider = StreamProvider<AppSettings>((ref) {
  return ref
      .watch(coreDatabaseProvider)
      .watchAllValues()
      .map(AppSettings.fromMap);
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.themeMode ?? ThemeMode.system;
});
