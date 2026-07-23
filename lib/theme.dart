import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette de couleurs de MémoTack, reprise à l'identique de l'aperçu.
class AppColors {
  static const ink = Color(0xFF1E1B22);
  static const inkLight = Color(0xFF2A2631);
  static const paper = Color(0xFFF5EFE1);
  static const paperMuted = Color(0xFFB9AE9A);
  static const soot = Color(0xFF2A2318);
  static const corail = Color(0xFFC1440E);
  static const ambre = Color(0xFFC99A2E);
  static const sauge = Color(0xFF4C6B4F);
  static const inkBlue = Color(0xFF3A5A68);

  static Color forTagColor(String tagColor) {
    switch (tagColor) {
      case 'corail':
        return corail;
      case 'ambre':
        return ambre;
      case 'sauge':
        return sauge;
      case 'bleuEncre':
        return inkBlue;
      default:
        return corail;
    }
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ink,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.inkBlue,
      secondary: AppColors.corail,
      surface: AppColors.inkLight,
    ),
    textTheme: GoogleFonts.ibmPlexSansTextTheme(base.textTheme).copyWith(
      headlineSmall: GoogleFonts.fraunces(
        textStyle: base.textTheme.headlineSmall,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.fraunces(
        textStyle: base.textTheme.titleLarge,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Style "tampon" utilisé pour les petites étiquettes (niveau, échéance).
TextStyle stampStyle({double size = 10, Color? color}) {
  return GoogleFonts.ibmPlexMono(
    fontSize: size,
    letterSpacing: 0.8,
    color: color ?? AppColors.paperMuted,
  );
}
