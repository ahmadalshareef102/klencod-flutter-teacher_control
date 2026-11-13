import 'package:flutter/material.dart';

class SettingsKeys {
  static const teacherName = 'teacher_name';
  static const schoolName = 'school_name';
  static const schoolYear = 'school_year';
  static const themeMode = 'theme_mode';
}

class AppSettings {
  const AppSettings({
    this.teacherName = '',
    this.schoolName = '',
    this.schoolYear = '',
    this.themeMode = ThemeMode.system,
  });

  final String teacherName;
  final String schoolName;
  final String schoolYear;
  final ThemeMode themeMode;

  factory AppSettings.fromMap(Map<String, String> m) {
    ThemeMode mode;
    switch (m[SettingsKeys.themeMode]) {
      case 'dark':
        mode = ThemeMode.dark;
        break;
      case 'light':
        mode = ThemeMode.light;
        break;
      default:
        mode = ThemeMode.system;
    }
    return AppSettings(
      teacherName: m[SettingsKeys.teacherName] ?? '',
      schoolName: m[SettingsKeys.schoolName] ?? '',
      schoolYear: m[SettingsKeys.schoolYear] ?? '',
      themeMode: mode,
    );
  }
}
