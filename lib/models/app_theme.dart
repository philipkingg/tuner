import 'package:flutter/material.dart';

enum AppColorTheme { earthy, codeDark }

class AppThemeColors {
  final AppColorTheme type;
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color primary;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color inTune;
  final Color gridLineActive;

  const AppThemeColors({
    required this.type,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.primary,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.inTune,
    required this.gridLineActive,
  });

  static const earthy = AppThemeColors(
    type: AppColorTheme.earthy,
    background: Color(0xFF17120D),
    surface: Color(0xFF231A12),
    surfaceContainer: Color(0xFF2E2118),
    primary: Color(0xFFC8892F),
    onPrimary: Color(0xFF1A1208),
    textPrimary: Color(0xFFE8D5BB),
    textSecondary: Color(0xFF9E8A72),
    textMuted: Color(0xFF5C4A38),
    border: Color(0xFF3D2D1F),
    inTune: Color(0xFFD4A853),
    gridLineActive: Color(0xFFC8892F),
  );

  static const codeDark = AppThemeColors(
    type: AppColorTheme.codeDark,
    background: Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    surfaceContainer: Color(0xFF21262D),
    primary: Color(0xFF58A6FF),
    onPrimary: Color(0xFF0D1117),
    textPrimary: Color(0xFFE6EDF3),
    textSecondary: Color(0xFF8B949E),
    textMuted: Color(0xFF484F58),
    border: Color(0xFF30363D),
    inTune: Color(0xFF3FB950),
    gridLineActive: Color(0xFF58A6FF),
  );

  static AppThemeColors fromType(AppColorTheme type) {
    return type == AppColorTheme.earthy ? earthy : codeDark;
  }

  String get displayName => type == AppColorTheme.earthy ? 'Earthy' : 'Code Dark';
}
