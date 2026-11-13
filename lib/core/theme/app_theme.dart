import 'package:flutter/material.dart';

class AppTheme {
  static const darkBlue = Color(0xFF0D3B73);
  static const lightBlue = Color(0xFF2E86DE);
  static const green = Color(0xFF2BA84A);
  static const _fontFamily = 'Cairo';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: darkBlue,
      brightness: brightness,
    ).copyWith(
      primary: isLight ? darkBlue : const Color(0xFF8FBBF2),
      secondary: lightBlue,
      tertiary: green,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor:
          isLight ? const Color(0xFFF3F5F8) : const Color(0xFF10161F),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: isLight ? darkBlue : const Color(0xFF16202C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
