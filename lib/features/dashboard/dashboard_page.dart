import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/core_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/study_days.dart';
import '../../models/app_section.dart';
import '../../models/app_settings.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../bell/bell_init.dart';
import '../shell/home_shell.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    final now = DateTime.now();
    final dayIdx = studyDayIndex(now);
    final lessonCount = ref.watch(finalLessonCountProvider).valueOrNull ?? 0;
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(settings: settings, now: now),
        const SizedBox(height: 16),
        _TodayCard(dayIdx: dayIdx, lessonCount: lessonCount),
        const SizedBox(height: 12),
        const _BellStatusCard(),
        const SizedBox(height: 16),
        Text(
          'الأقسام',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: wide ? 4 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final s in AppSection.values)
              if (s != AppSection.dashboard)
                _ShortcutTile(
                  section: s,
                  onTap: () =>
                      ref.read(selectedSectionProvider.notifier).state = s,
                ),
          ],
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.settings, required this.now});

  final AppSettings settings;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE d MMMM y', 'ar').format(now);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppTheme.darkBlue, AppTheme.lightBlue],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(Icons.school_rounded, color: AppTheme.darkBlue, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    settings.teacherName.isEmpty
                        ? 'أدخل اسمك من الإعدادات'
                        : 'الأستاذ/ ${settings.teacherName}',
                  ),
                  if (settings.schoolYear.isNotEmpty)
                    Text('العام الدراسي: ${settings.schoolYear}'),
                  const SizedBox(height: 4),
                  Text(date, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.dayIdx, required this.lessonCount});

  final int? dayIdx;
  final int lessonCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TimetableSlot> slots = dayIdx == null
        ? const []
        : (ref.watch(todaySlotsProvider(dayIdx!)).valueOrNull ?? const [])
            .where((s) => s.subject.isNotEmpty || s.grade.isNotEmpty)
            .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'حصص اليوم',
                    value: dayIdx == null ? '-' : '${slots.length}',
                    color: AppTheme.lightBlue,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'الدروس المحضرة',
                    value: '$lessonCount',
                    color: AppTheme.green,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (dayIdx == null)
              const Text('اليوم إجازة أسبوعية.')
            else if (slots.isEmpty)
              const Text(
                'لا توجد حصص مضبوطة لهذا اليوم. أضفها من قسم جدول الحصص.',
              )
            else
              for (final s in slots)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${s.period}'),
                  ),
                  title: Text(s.subject.isEmpty ? 'بدون مادة' : s.subject),
                  subtitle: Text(
                    [s.grade, s.section].where((e) => e.isNotEmpty).join(' - '),
                  ),
                  trailing: s.startTime.isEmpty
                      ? null
                      : Text('${s.startTime} - ${s.endTime}'),
                ),
          ],
        ),
      ),
    );
  }
}

/// حالة الجرس: عدد الأجراس المجدولة وتنبيه عند غياب صلاحية التنبيهات الدقيقة.
class _BellStatusCard extends ConsumerWidget {
  const _BellStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bellInitProvider).state;
    if (state == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final ok = state.exactAllowed;
        return Card(
          child: ListTile(
            leading: Icon(
              ok ? Icons.notifications_active_rounded : Icons.warning_amber_rounded,
              color: ok ? AppTheme.green : Colors.orange,
            ),
            title: Text('الجرس: ${state.scheduledCount} موعد مجدول'),
            subtitle: ok
                ? null
                : const Text('امنح «التنبيهات الدقيقة» من إعدادات الجرس ليرنّ في وقته.'),
            onTap: () =>
                ref.read(selectedSectionProvider.notifier).state = AppSection.bell,
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.section, required this.onTap});

  final AppSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(section.icon, size: 30, color: scheme.primary),
              const SizedBox(height: 6),
              Text(
                section.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
