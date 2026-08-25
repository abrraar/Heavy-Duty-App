// lib/core/theme/app_picker_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';

class AppPickerTheme {
  AppPickerTheme._();

  static ThemeData get themeData {
    const TextStyle brandFontBase = TextStyle(
      fontFamily: 'Impact',
      fontWeight: FontWeight.w200,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Impact',

      colorScheme: const ColorScheme.dark(
        primary: AppColors.crimson,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        onSurface: Colors.white,
        secondary: AppColors.crimson,
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        headerHeadlineStyle: brandFontBase.copyWith(fontSize: 24.sp, color: Colors.white),
        headerHelpStyle: brandFontBase.copyWith(fontSize: 12.sp, color: Colors.white70),
        weekdayStyle: brandFontBase.copyWith(
          fontSize: 12.sp,
          color: Colors.white70,
        ),
        dayStyle: brandFontBase.copyWith(fontSize: 14.sp),
        yearStyle: brandFontBase.copyWith(fontSize: 14.sp),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return Colors.white.withOpacity(0.3);
          return Colors.white;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return Colors.white.withOpacity(0.3);
          return Colors.white;
        }),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        hourMinuteTextStyle: brandFontBase.copyWith(fontSize: 48.sp),
        dayPeriodTextStyle: brandFontBase.copyWith(fontSize: 16.sp),
        helpTextStyle: brandFontBase.copyWith(fontSize: 12.sp),
        dialTextStyle: brandFontBase.copyWith(fontSize: 14.sp),

        hourMinuteTextColor: WidgetStateColor.resolveWith((states) => Colors.white),
        dialTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return Colors.white.withOpacity(0.3);
          return Colors.white;
        }),

        // ADDED: dayPeriodColor to fix AM/PM background
        dayPeriodColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.crimson; // Selection background
          }
          return Colors.white.withOpacity(0.05); // Inactive background
        }),

        // FIXED: Using WidgetStateColor.resolveWith to cleanly change text states
        dayPeriodTextColor: WidgetStateColor.resolveWith((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return Colors
                .white; // Active (AM or PM) selection turns crisp white
          }
          return Colors.white.withOpacity(
            0.38,
          ); // Inactive option dims to grey/low-opacity
        }),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: brandFontBase.copyWith(
            fontSize: 14.sp,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
          foregroundColor: AppColors.crimson,
        ),
      ),

      textTheme: TextTheme(
        labelLarge: brandFontBase.copyWith(fontSize: 14.sp),
        bodyLarge: brandFontBase,
        bodySmall: brandFontBase,
        titleLarge: brandFontBase.copyWith(fontSize: 22.sp),
        titleMedium: brandFontBase,
        titleSmall: brandFontBase,
      ), dialogTheme: DialogThemeData(backgroundColor: AppColors.surface),
    );
  }
}
