import 'package:flutter/material.dart';

class SettingsKeys {
  static const teacherName = 'teacher_name';
  static const schoolName = 'school_name';
  static const schoolYear = 'school_year';
  static const themeMode = 'theme_mode';
  static const autoSortStudents = 'auto_sort_students';
  static const gradeScale = 'grade_scale';
}

class AppSettings {
  const AppSettings({
    this.teacherName = '',
    this.schoolName = '',
    this.schoolYear = '',
    this.themeMode = ThemeMode.system,
    this.autoSortStudents = false,
    this.gradeScale = '',
  });

  final String teacherName;
  final String schoolName;
  final String schoolYear;
  final ThemeMode themeMode;
  final bool autoSortStudents;

  /// "85,75,65,50" أو فارغ للقيم الافتراضية.
  final String gradeScale;

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
      autoSortStudents: m[SettingsKeys.autoSortStudents] == '1',
      gradeScale: m[SettingsKeys.gradeScale] ?? '',
    );
  }
}
