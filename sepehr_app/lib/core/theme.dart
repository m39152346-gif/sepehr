import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const night = Color(0xFF080F2B);
  static const plate = Color(0xFF121F4B);
  static const plateLight = Color(0xFF1B2D63);
  static const brass = Color(0xFFF0A44B);
  static const gold = Color(0xFFF6DB76);
  static const teal = Color(0xFF19798B);
  static const red = Color(0xFFE74B47);
  static const text = Color(0xFFFBF3DC);
  static const muted = Color(0xFFB8C3E8);
  static const good = Color(0xFF6BCB98);
  static const warning = Color(0xFFE5B75E);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.vazirmatnTextTheme(base.textTheme).apply(
    bodyColor: C.text,
    displayColor: C.text,
  );
  return base.copyWith(
    scaffoldBackgroundColor: C.night,
    colorScheme: base.colorScheme.copyWith(
      primary: C.brass,
      secondary: C.gold,
      surface: C.plate,
      error: C.red,
    ),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: C.night,
      foregroundColor: C.text,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: C.plate,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.plate,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: C.muted.withOpacity(.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: C.brass, width: 1.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.plate,
      indicatorColor: C.brass.withOpacity(.18),
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.vazirmatn(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: C.plateLight,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String fa(num number, [int digits = 0]) {
  const digitsFa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return number.toStringAsFixed(digits).split('').map((character) {
    final digit = int.tryParse(character);
    if (digit != null) return digitsFa[digit];
    if (character == '.') return '٫';
    if (character == '-') return '−';
    return character;
  }).join();
}

String faText(String value) => value.replaceAllMapped(RegExp(r'\d'), (match) {
      const digitsFa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
      return digitsFa[int.parse(match.group(0)!)];
    });

String formatTemperature(double celsius, {required bool fahrenheit, int digits = 0}) {
  final value = fahrenheit ? celsius * 9 / 5 + 32 : celsius;
  return '${fa(value, digits)}°${fahrenheit ? 'F' : 'C'}';
}

String formatLocalClock(DateTime dateTime) =>
    '${fa(dateTime.hour).padLeft(2, '۰')}:${fa(dateTime.minute).padLeft(2, '۰')}';
