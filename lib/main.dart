import 'package:flutter/material.dart';
import 'models/app_theme.dart';
import 'ui/screens/tuner_home.dart';

final ValueNotifier<AppColorTheme> appThemeNotifier =
    ValueNotifier(AppColorTheme.earthy);

void main() => runApp(const TunerApp());

class TunerApp extends StatelessWidget {
  const TunerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppColorTheme>(
      valueListenable: appThemeNotifier,
      builder: (context, themeType, _) {
        final tc = AppThemeColors.fromType(themeType);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: tc.background,
            colorScheme: ColorScheme.dark(
              surface: tc.surface,
              primary: tc.primary,
              onPrimary: tc.onPrimary,
              onSurface: tc.textPrimary,
              outline: tc.border,
            ),
          ),
          home: const TunerHome(),
        );
      },
    );
  }
}
