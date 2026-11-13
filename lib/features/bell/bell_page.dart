import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_section.dart';
import '../school_bell/screens/main_shell.dart';
import '../shell/home_shell.dart';
import 'bell_init.dart';

/// قسم «جرس الحصص»: يعرض تطبيق الجرس المدرسي الذكي كاملاً داخل كنترول المدرس.
class BellPage extends ConsumerWidget {
  const BellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(bellInitProvider);
    if (init.state == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'تعذّر تشغيل وحدة الجرس:\n${init.error ?? ''}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return MainShell(
      onExit: () =>
          ref.read(selectedSectionProvider.notifier).state = AppSection.dashboard,
    );
  }
}
