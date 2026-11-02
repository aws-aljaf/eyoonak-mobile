import 'package:flutter/material.dart';
import 'family_page_transitions.dart';

/// Shared Eyoonak theme with bundled Arabic typography and accessible family motion.
ThemeData buildAppTheme({String? familyGender}) {
  const seed = Color(0xFF079DB4);
  var colors = ColorScheme.fromSeed(seedColor: seed).copyWith(
    primary: const Color(0xFF087F8C),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFCCF5EF),
    onPrimaryContainer: const Color(0xFF083C57),
    secondary: const Color(0xFF307CC0),
    secondaryContainer: const Color(0xFFDCEFFC),
    onSecondaryContainer: const Color(0xFF123B61),
    tertiaryContainer: const Color(0xFFFFF0B8),
    onTertiaryContainer: const Color(0xFF614A12),
    surface: const Color(0xFFF8FDFE),
    onSurface: const Color(0xFF12384B),
    outline: const Color(0xFF769AA4),
  );

  if (familyGender == 'female') {
    colors = ColorScheme.fromSeed(seedColor: const Color(0xFFBE185D)).copyWith(
        primary: const Color(0xFFBE185D),
        surface: const Color(0xFFFFF5FA),
        primaryContainer: const Color(0xFFFCE7F3),
        secondaryContainer: const Color(0xFFFCE7F3));
  } else if (familyGender == 'male') {
    colors = ColorScheme.fromSeed(seedColor: const Color(0xFF1768B4)).copyWith(
        primary: const Color(0xFF1768B4),
        surface: const Color(0xFFF1F8FF),
        primaryContainer: const Color(0xFFDCEEFF),
        secondaryContainer: const Color(0xFFDCEEFF));
  }
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FamilyPageTransitionsBuilder(),
      TargetPlatform.iOS: FamilyPageTransitionsBuilder(),
      TargetPlatform.windows: FamilyPageTransitionsBuilder(),
      TargetPlatform.linux: FamilyPageTransitionsBuilder(),
      TargetPlatform.macOS: FamilyPageTransitionsBuilder(),
    }),
    scaffoldBackgroundColor:
        familyGender == null ? const Color(0xFFF0FBFC) : colors.surface,
    cardTheme: const CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(26)),
            side: BorderSide(color: Color(0xFFD2EAEF)))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.primary, width: 2)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC3DEE5))),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)))),
    dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)))),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white, indicatorColor: colors.primaryContainer),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: colors.primary,
        unselectedItemColor: const Color(0xFF769AA4)),
    snackBarTheme: SnackBarThemeData(
        backgroundColor:
            familyGender == null ? const Color(0xFF083C57) : colors.primary,
        contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)))),
    colorScheme: colors,
    visualDensity: VisualDensity.comfortable,
    appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor:
            familyGender == null ? const Color(0xFF083C57) : colors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        surfaceTintColor: Colors.transparent),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
