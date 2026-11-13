import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../developer/developer_page.dart';

/// بيانات المطور الموحّدة (تستخدمها الشاشة الرئيسية للجرس).
const String kDeveloperName = AppConstants.developerName;
const String kDeveloperPhone = AppConstants.developerPhone;

/// صفحة «عن المطوّر» الموحّدة لتطبيق كنترول المدرس.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('عن المطوّر')),
        body: const DeveloperPage(),
      ),
    );
  }
}
