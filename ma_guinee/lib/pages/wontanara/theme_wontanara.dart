// lib/pages/wontanara/theme_wontanara.dart
import 'package:flutter/material.dart';

class ThemeWontanara {
  static const Color vertPetrole = Color(0xFF0E5A51);
  static const Color vertPetroleFonce = Color(0xFF0B4740);
  static const Color menthe = Color(0xFFD6F2EC);
  static const Color chip = Color(0xFFE8F3F1);
  static const Color texte = Color(0xFF0D0F12);
  static const Color texte2 = Color(0xFF5E6A6A);

  static ThemeData get data {
    return ThemeData(
      useMaterial3: true,

      primaryColor: vertPetrole,

      colorScheme: ColorScheme.fromSeed(
        seedColor: vertPetrole,
        primary: vertPetrole,
        onPrimary: Colors.white,
        secondary: menthe,
        onSecondary: texte,
        surface: Colors.white,
        onSurface: texte,
        background: Colors.white,
      ),

      scaffoldBackgroundColor: Colors.white,

      appBarTheme: const AppBarTheme(
        backgroundColor: vertPetrole,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: vertPetrole,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      chipTheme: const ChipThemeData(
        backgroundColor: chip,
        labelStyle: TextStyle(
          color: texte,
          fontWeight: FontWeight.w600,
        ),
        shape: StadiumBorder(),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // 👇 volontairement PAS de cardTheme ici pour éviter ton bug

      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: texte,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: texte,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: texte2,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: vertPetrole,
        unselectedItemColor: texte2,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
