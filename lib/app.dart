import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/bell/bell_init.dart';
import 'features/school_bell/app/app_state.dart' show AppScope;
import 'features/shell/home_shell.dart';
import 'providers/settings_provider.dart';

class TeacherControlApp extends ConsumerWidget {
  const TeacherControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final bellState = ref.watch(bellInitProvider).state;

    final app = MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );

    // AppScope فوق MaterialApp ليصل لكل شاشات الجرس (بما فيها المفتوحة بـ Navigator.push).
    return bellState == null ? app : AppScope(state: bellState, child: app);
  }
}
