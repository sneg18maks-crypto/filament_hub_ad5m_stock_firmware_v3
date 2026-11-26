import 'package:flutter/material.dart';

class Palette {
  static const green = Color(0xFF00AE42);
  static const orange = Color(0xFFFF9F0A);
  static const red = Color(0xFFFF453A);
  static const blue = Color(0xFF0A84FF);
  static const darkBg = Color(0xFF0F1214);
  static const darkPanel = Color(0xFF1B1F23);
  static const lightBg = Color(0xFFF2F4F6);
}

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color panelColor(BuildContext c) => isDark(c) ? Palette.darkPanel : Colors.white;
Color mutedColor(BuildContext c) => isDark(c) ? Colors.white60 : Colors.black54;
Color lineColor(BuildContext c) => isDark(c) ? Colors.white12 : Colors.black12;
Color textOn(Color c) => c.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: Palette.green, brightness: b)
      .copyWith(primary: Palette.green, onPrimary: Colors.white);
  final bg = dark ? Palette.darkBg : Palette.lightBg;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 24, fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black87),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? Palette.darkPanel : Colors.white,
      indicatorColor: Palette.green.withOpacity(0.22),
    ),
    dialogBackgroundColor: dark ? Palette.darkPanel : Colors.white,
  );
}
