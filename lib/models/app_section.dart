import 'package:flutter/material.dart';

enum AppSection {
  dashboard('الرئيسية', Icons.dashboard_rounded, null),
  grades('كشف الدرجات', Icons.grading_rounded, 3),
  examEditor('محرر الاختبارات', Icons.edit_document, 4),
  lessons('تحضير الدروس', Icons.menu_book_rounded, 5),
  timetable('جدول الحصص', Icons.calendar_view_week_rounded, 6),
  bell('جرس الحصص', Icons.notifications_active_rounded, null),
  data('إدارة البيانات', Icons.storage_rounded, 8),
  backup('النسخ الاحتياطي', Icons.backup_rounded, 8),
  settings('الإعدادات', Icons.settings_rounded, null),
  developer('عن المطور', Icons.info_rounded, null);

  const AppSection(this.title, this.icon, this.phase);

  final String title;
  final IconData icon;

  /// مرحلة التنفيذ، أو null إذا كان القسم منفذاً.
  final int? phase;
}
