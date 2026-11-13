import 'package:flutter/material.dart';

import '../../models/app_section.dart';

/// تظهر للأقسام التي لم تصل مرحلة تنفيذها بعد.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(section.icon, size: 72, color: scheme.secondary),
            const SizedBox(height: 16),
            Text(
              section.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'هذا القسم لم يُنفَّذ بعد، وسيُضاف في المرحلة ${section.phase}.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
