import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _teacher = TextEditingController();
  final _school = TextEditingController();
  final _year = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _teacher.dispose();
    _school.dispose();
    _year.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    if ((v ?? '').trim().length > 60) return 'الحد الأقصى 60 حرفاً';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = ref.read(coreDatabaseProvider);
    await db.setValue(SettingsKeys.teacherName, _teacher.text.trim());
    await db.setValue(SettingsKeys.schoolName, _school.text.trim());
    await db.setValue(SettingsKeys.schoolYear, _year.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الإعدادات')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(settingsProvider);
    if (!async.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final settings = async.requireValue;
    if (!_loaded) {
      _teacher.text = settings.teacherName;
      _school.text = settings.schoolName;
      _year.text = settings.schoolYear;
      _loaded = true;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _teacher,
                decoration: const InputDecoration(labelText: 'اسم المعلم'),
                validator: _validate,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _school,
                decoration: const InputDecoration(labelText: 'اسم المدرسة'),
                validator: _validate,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _year,
                decoration: const InputDecoration(
                  labelText: 'العام الدراسي',
                  hintText: 'مثال: 1448 / 2026',
                ),
                validator: _validate,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('حفظ'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('المظهر', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('نهاري'),
              icon: Icon(Icons.light_mode_rounded),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('ليلي'),
              icon: Icon(Icons.dark_mode_rounded),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('تلقائي'),
              icon: Icon(Icons.phone_android_rounded),
            ),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (s) => ref
              .read(coreDatabaseProvider)
              .setValue(SettingsKeys.themeMode, s.first.name),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ترتيب أسماء الطلاب أبجدياً تلقائياً'),
          subtitle: const Text('يُطبّق عند إضافة طالب أو استيراد أسماء أو تعديل اسم.'),
          value: settings.autoSortStudents,
          onChanged: (v) => ref
              .read(coreDatabaseProvider)
              .setValue(SettingsKeys.autoSortStudents, v ? '1' : '0'),
        ),
      ],
    );
  }
}
