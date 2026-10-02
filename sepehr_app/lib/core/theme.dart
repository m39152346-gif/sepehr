import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const night = Color(0xFF0D1338);
  static const plate = Color(0xFF172767);
  static const brass = Color(0xFFEE9B43);
  static const gold = Color(0xFFF3D567);
  static const teal = Color(0xFF19798B);
  static const red = Color(0xFFE74B47);
  static const text = Color(0xFFFBF3DC);
  static const muted = Color(0xFFC3C9EF);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.night,
    colorScheme: base.colorScheme.copyWith(primary: C.brass, secondary: C.gold, surface: C.plate),
    textTheme: GoogleFonts.vazirmatnTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.plate,
      indicatorColor: C.brass.withOpacity(.2),
      labelTextStyle: WidgetStatePropertyAll(GoogleFonts.vazirmatn(fontSize: 12)),
    ),
  );
}

String fa(num n, [int digits = 0]) {
  const d = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return n.toStringAsFixed(digits).split('').map((c) {
    final i = int.tryParse(c);
    return i == null ? (c == '.' ? '٫' : c) : d[i];
  }).join();
}
