import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class DeveloperPage extends StatelessWidget {
  const DeveloperPage({super.key});

  Future<void> _call(BuildContext context) async {
    final ok = await launchUrl(
      Uri(scheme: 'tel', path: AppConstants.developerPhone),
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')),
      );
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: AppConstants.developerPhone),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ رقم التواصل')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.school_rounded, size: 72, color: AppTheme.lightBlue),
        const SizedBox(height: 8),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Text('الإصدار 1.0.0', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('اسم المطور'),
                Text(
                  AppConstants.developerName,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text('رقم التواصل'),
                SelectableText(
                  AppConstants.developerPhone,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _call(context),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('اتصال'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copy(context),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('نسخ الرقم'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(
                    data: 'tel:${AppConstants.developerPhone}',
                    size: 160,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
