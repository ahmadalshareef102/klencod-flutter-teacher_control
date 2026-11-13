import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../models/app_section.dart';
import '../bell/bell_page.dart';
import '../dashboard/dashboard_page.dart';
import '../developer/developer_page.dart';
import '../grades/grades_page.dart';
import '../placeholder/placeholder_page.dart';
import '../settings/settings_page.dart';

final selectedSectionProvider =
    StateProvider<AppSection>((ref) => AppSection.dashboard);

const _bottomSections = [
  AppSection.dashboard,
  AppSection.grades,
  AppSection.lessons,
  AppSection.timetable,
];

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  Widget _page(AppSection s) {
    switch (s) {
      case AppSection.dashboard:
        return const DashboardPage();
      case AppSection.grades:
        return const GradesPage();
      case AppSection.bell:
        return const BellPage();
      case AppSection.settings:
        return const SettingsPage();
      case AppSection.developer:
        return const DeveloperPage();
      default:
        return PlaceholderPage(section: s);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedSectionProvider);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    // قسم الجرس له أشرطته الخاصة (شريط علوي وسفلي) فلا نكررها.
    final ownChrome = selected == AppSection.bell;

    final Widget scaffold;
    if (wide) {
      scaffold = Scaffold(
        body: Row(
          children: [
            _SideMenu(selected: selected),
            const VerticalDivider(width: 1),
            Expanded(
              child: Scaffold(
                appBar: ownChrome ? null : AppBar(title: Text(selected.title)),
                body: _page(selected),
              ),
            ),
          ],
        ),
      );
    } else {
      final bottomIndex = _bottomSections.indexOf(selected);
      scaffold = Scaffold(
        appBar: ownChrome ? null : AppBar(title: Text(selected.title)),
        body: _page(selected),
        bottomNavigationBar: ownChrome
            ? null
            : NavigationBar(
                selectedIndex: bottomIndex == -1 ? 4 : bottomIndex,
                onDestinationSelected: (i) {
                  if (i < _bottomSections.length) {
                    ref.read(selectedSectionProvider.notifier).state =
                        _bottomSections[i];
                  } else {
                    _showMore(context, ref);
                  }
                },
                destinations: [
                  for (final s in _bottomSections)
                    NavigationDestination(icon: Icon(s.icon), label: s.title),
                  const NavigationDestination(
                    icon: Icon(Icons.more_horiz_rounded),
                    label: 'المزيد',
                  ),
                ],
              ),
      );
    }

    // زر الرجوع في أندرويد: من أي قسم إلى الرئيسية أولاً ثم الخروج.
    return PopScope(
      canPop: selected == AppSection.dashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(selectedSectionProvider.notifier).state =
              AppSection.dashboard;
        }
      },
      child: scaffold,
    );
  }

  void _showMore(BuildContext context, WidgetRef ref) {
    final others =
        AppSection.values.where((s) => !_bottomSections.contains(s)).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in others)
              ListTile(
                leading: Icon(s.icon),
                title: Text(s.title),
                onTap: () {
                  ref.read(selectedSectionProvider.notifier).state = s;
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SideMenu extends ConsumerWidget {
  const _SideMenu({required this.selected});

  final AppSection selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 250,
      child: Material(
        color: scheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.school_rounded, color: scheme.primary, size: 32),
                    const SizedBox(width: 10),
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final s in AppSection.values)
                      ListTile(
                        leading: Icon(s.icon),
                        title: Text(s.title),
                        selected: s == selected,
                        selectedTileColor: scheme.primary.withAlpha(26),
                        onTap: () => ref
                            .read(selectedSectionProvider.notifier)
                            .state = s,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
