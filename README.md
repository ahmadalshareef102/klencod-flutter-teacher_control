# كنترول المدرس – Teacher Control (تطبيق Android)

تطبيق Flutter/Dart للمعلم. يحتوي حتى الآن على:
- لوحة التحكم، التنقل (قائمة جانبية للشاشات الكبيرة وشريط سفلي للهاتف)، الإعدادات، عن المطور.
- **جرس الحصص**: تطبيق «الجرس المدرسي الذكي» مدمج كاملاً (جدولة عبر AlarmManager وخدمة Kotlin، يعمل والتطبيق مغلق).
- بقية الأقسام تعرض صفحة تبيّن المرحلة التي ستُنفَّذ فيها.

## التشغيل
1. الخطوط مضافة في `assets/fonts/` (Cairo وMontserrat وMohammad).
2. إن اشتكى IDE من غياب `android/local.properties` أو Gradle wrapper:
   `flutter create --platforms=android --project-name teacher_control .`
   (احتفظ بملفاتك إن سأل عن الاستبدال. وإن أنشأ `test/widget_test.dart` فاحذفه.)
3. نفّذ:
   ```
   flutter pub get
   flutter analyze
   flutter test
   flutter run
   ```
4. بناء APK: `flutter build apk --release` ← `build/app/outputs/flutter-apk/app-release.apk`

## ملاحظات
- لم يُبنَ هذا المشروع ولم يُختبر في بيئة الإنشاء (لا يوجد Flutter SDK). أرسل أي خطأ يظهر لتصحيحه.
- وحدة الجرس في `lib/features/school_bell/` بقاعدتها الخاصة (`smart_school_bell.db`) وقاعدة التطبيق في `teacher_control.db`.
  عند تنفيذ النسخ الاحتياطي الشامل (المرحلة 8) سنضم القاعدتين.
- معرّف التطبيق `com.teachercontrol.app`، فهو يُثبَّت بجانب تطبيق الجرس المستقل ولا يستبدله.
- للجرس: امنح «التنبيهات الدقيقة» واستثنِ التطبيق من توفير البطارية من قسم الجرس ← المزيد ← الإعدادات.
