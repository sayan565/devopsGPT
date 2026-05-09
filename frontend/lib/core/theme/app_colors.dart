import 'package:flutter/material.dart';

class AppColors {
  // ── These are FIXED colors (same in both modes) ──
  static const accent       = Color(0xFF00D4FF);
  static const accentGlow   = Color(0x4000D4FF);
  static const purple       = Color(0xFF7C3AED);
  static const purpleGlow   = Color(0x407C3AED);
  static const pink         = Color(0xFFEC4899);
  static const success      = Color(0xFF10B981);
  static const successGlow  = Color(0x4010B981);
  static const warning      = Color(0xFFF59E0B);
  static const warningGlow  = Color(0x40F59E0B);
  static const critical     = Color(0xFFEF4444);
  static const criticalGlow = Color(0x40EF4444);
  static const info         = Color(0xFF3B82F6);

  static const List<Color> primaryGradient = [
    Color(0xFF00D4FF),
    Color(0xFF7C3AED),
  ];

  // ── These CHANGE based on theme ──────────────────
  // Use AppTheme.of(context) to get these

  // Dark mode values
  static const darkBackground  = Color(0xFF060B18);
  static const darkSurface     = Color(0xFF0D1424);
  static const darkCard        = Color(0xFF0D1424);
  static const darkCardBorder  = Color(0xFF1E2D45);
  static const darkGlassWhite  = Color(0x0FFFFFFF);
  static const darkGlassBorder = Color(0x1AFFFFFF);
  static const darkTextPrimary   = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkTextMuted     = Color(0xFF64748B);

  // Light mode values
  static const lightBackground  = Color(0xFFF0F4FF);
  static const lightSurface     = Color(0xFFFFFFFF);
  static const lightCard        = Color(0xFFFFFFFF);
  static const lightCardBorder  = Color(0xFFE2E8F0);
  static const lightGlassWhite  = Color(0x15000000);
  static const lightGlassBorder = Color(0x25000000);
  static const lightTextPrimary   = Color(0xFF111827);
  static const lightTextSecondary = Color(0xFF64748B);
  static const lightTextMuted     = Color(0xFF94A3B8);

  // ── Backward compatibility (dark mode defaults) ──
  static const background   = darkBackground;
  static const surface      = darkSurface;
  static const card         = darkCard;
  static const cardBorder   = darkCardBorder;
  static const glassWhite   = darkGlassWhite;
  static const glassBorder  = darkGlassBorder;
  static const textPrimary   = darkTextPrimary;
  static const textSecondary = darkTextSecondary;
  static const textMuted     = darkTextMuted;
}

// Helper class to get theme-aware colors
class AppTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) => isDark(context)
      ? AppColors.darkBackground
      : AppColors.lightBackground;

  static Color card(BuildContext context) => isDark(context)
      ? AppColors.darkCard
      : AppColors.lightCard;

  static Color cardBorder(BuildContext context) =>
      isDark(context)
          ? AppColors.darkCardBorder
          : AppColors.lightCardBorder;

  static Color glassWhite(BuildContext context) =>
      isDark(context)
          ? AppColors.darkGlassWhite
          : AppColors.lightGlassWhite;

  static Color glassBorder(BuildContext context) =>
      isDark(context)
          ? AppColors.darkGlassBorder
          : AppColors.lightGlassBorder;

  static Color textPrimary(BuildContext context) =>
      isDark(context)
          ? AppColors.darkTextPrimary
          : AppColors.lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      isDark(context)
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary;

  static Color textMuted(BuildContext context) =>
      isDark(context)
          ? AppColors.darkTextMuted
          : AppColors.lightTextMuted;
}