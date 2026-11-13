/// أدوات للتعامل مع الأسماء العربية (تطبيع، ترتيب، قراءة قوائم الأسماء).

final RegExp _diacritics = RegExp('[\u064B-\u065F\u0670\u0640]');
final RegExp _spaces = RegExp(r'\s+');
final RegExp _hasLetter = RegExp('[A-Za-z\u0600-\u06FF]');
final RegExp _listNumber =
    RegExp('^\\s*[\\d\u0660-\u0669]+\\s*[-\u2013.)\u060C:]*\\s*');

const Set<String> _headerWords = {
  'الاسم',
  'اسم',
  'اسم الطالب',
  'الطالب',
  'اسم الطالبة',
  'الطلاب',
  'name',
};

/// ينظّف المسافات الزائدة من الاسم.
String cleanName(String s) => s.replaceAll(_spaces, ' ').trim();

/// مفتاح مقارنة/ترتيب: يزيل التشكيل ويوحّد صور الألف والياء والتاء المربوطة.
String normalizeArabic(String s) {
  var t = s.replaceAll(_diacritics, '');
  t = t
      .replaceAll('\u0622', '\u0627')
      .replaceAll('\u0623', '\u0627')
      .replaceAll('\u0625', '\u0627')
      .replaceAll('\u0649', '\u064A')
      .replaceAll('\u0629', '\u0647')
      .replaceAll('\u0624', '\u0648')
      .replaceAll('\u0626', '\u064A');
  return t.replaceAll(_spaces, ' ').trim().toLowerCase();
}

/// يحوّل الأرقام الهندية إلى لاتينية والفاصلة العربية إلى نقطة.
String toLatinDigits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      b.writeCharCode(r - 0x0660 + 0x30);
    } else if (r == 0x066B || r == 0x066C || r == 0x2C) {
      b.write('.');
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

/// يقرأ نصاً (ملصوقاً أو من ملف txt/csv) ويستخرج أسماء الطلاب، اسم في كل سطر.
/// يتجاهل الترقيم في أول السطر وسطر العنوان، ويأخذ أول خلية فيها حروف عند وجود فواصل.
List<String> parseNameLines(String text) {
  final out = <String>[];
  final lines = text.replaceAll('\uFEFF', '').split(RegExp(r'[\r\n]+'));
  for (final line in lines) {
    for (final cell in line.split(RegExp(r'[,;\t\u060C]'))) {
      final name = cleanName(cell.replaceFirst(_listNumber, ''));
      if (name.isEmpty || !_hasLetter.hasMatch(name)) continue;
      if (_headerWords.contains(name.toLowerCase())) break;
      out.add(name);
      break;
    }
  }
  return out;
}
