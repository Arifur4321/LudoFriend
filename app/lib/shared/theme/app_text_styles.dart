import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography for Ludo Friends.
///
/// Headings use a rounded, playful face (Fredoka); body uses a highly legible
/// companion (Nunito). Using google_fonts means no font binaries are bundled.
abstract class AppTextStyles {
  static TextStyle get display => GoogleFonts.fredoka(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.2,
      );

  static TextStyle get heading => GoogleFonts.fredoka(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  static TextStyle get title => GoogleFonts.fredoka(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  static TextStyle get body => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  static TextStyle get bodyMuted => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.inkSoft,
      );

  static TextStyle get button => GoogleFonts.fredoka(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.3,
      );

  static TextStyle get label => GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.inkSoft,
        letterSpacing: 0.4,
      );
}
