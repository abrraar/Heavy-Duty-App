import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._(); // prevents instantiation

  static const String _font = 'Impact';

  // ── Display / Hero ────────────────────────────────────
  // Used for: splash screen title, big stat numbers
  static TextStyle get displayLarge => TextStyle(
        fontFamily: _font,
        fontSize: 48.sp,
        color: AppColors.textPrimary,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get displayMedium => TextStyle(
        fontFamily: _font,
        fontSize: 36.sp,
        color: AppColors.textPrimary,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w500,
      );

  // ── Headings ──────────────────────────────────────────
  // Used for: screen titles like "Sign in", "Dashboard"
  static TextStyle get h1 => TextStyle(
        fontFamily: _font,
        fontSize: 32.sp,
        color: AppColors.textPrimary,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get h2 => TextStyle(
        fontFamily: _font,
        fontSize: 26.sp,
        color: AppColors.textPrimary,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get h3 => TextStyle(
        fontFamily: _font,
        fontSize: 22.sp,
        color: AppColors.textPrimary,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w500,
      );

  // ── Section Labels ────────────────────────────────────
  // Used for: "Username", "Email", card titles
  static TextStyle get labelLarge => TextStyle(
        fontFamily: _font,
        fontSize: 16.sp,
        color: AppColors.textPrimary,
        letterSpacing: 0.3,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get labelMedium => TextStyle(
        fontFamily: _font,
        fontSize: 14.sp,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get labelSmall => TextStyle(
        fontFamily: _font,
        fontSize: 12.sp,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      );

  // ── Body ──────────────────────────────────────────────
  // Used for: descriptions, longer text blocks
  // Impact isn't ideal for body — using it at smaller size with normal spacing
  static TextStyle get bodyLarge => TextStyle(
        fontFamily: _font,
        fontSize: 16.sp,
        color: AppColors.textSecondary,
        letterSpacing: 0.1,
        height: 1.5,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontFamily: _font,
        fontSize: 14.sp,
        color: AppColors.textSecondary,
        letterSpacing: 0.1,
        height: 1.5,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get bodySmall => TextStyle(
        fontFamily: _font,
        fontSize: 12.sp,
        color: AppColors.textMuted,
        letterSpacing: 0.1,
        height: 1.5,
        fontWeight: FontWeight.w500,
      );

  // ── Buttons ───────────────────────────────────────────
  // Used for: primary button, social buttons
  static TextStyle get buttonPrimary => TextStyle(
        fontFamily: _font,
        fontSize: 18.sp,
        color: AppColors.textPrimary,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get buttonSecondary => TextStyle(
        fontFamily: _font,
        fontSize: 16.sp,
        color: AppColors.textPrimary,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get buttonDark => TextStyle(
        fontFamily: _font,
        fontSize: 16.sp,
        color: Colors.black87,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w500,
      );

  // ── Input Fields ──────────────────────────────────────
  static TextStyle get inputText => TextStyle(
        fontFamily: _font,
        fontSize: 14.sp,
        color: Colors.black87,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get inputHint => TextStyle(
        fontFamily: _font,
        fontSize: 14.sp,
        color: AppColors.inputHint,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      );

  // ── Captions & Links ──────────────────────────────────
  // Used for: "Already have an account?", divider text
  static TextStyle get caption => TextStyle(
        fontFamily: _font,
        fontSize: 13.sp,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get link => TextStyle(
        fontFamily: _font,
        fontSize: 13.sp,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get dividerLabel => TextStyle(
        fontFamily: _font,
        fontSize: 13.sp,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
        fontWeight: FontWeight.w500,
      );

  // ── Workout / Stats specific ───────────────────────────
  // Used for: rep counts, weights, timers — big bold numbers
  static TextStyle get statNumber => TextStyle(
        fontFamily: _font,
        fontSize: 42.sp,
        color: AppColors.crimson,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get statLabel => TextStyle(
        fontFamily: _font,
        fontSize: 11.sp,
        color: AppColors.textMuted,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get timerDisplay => TextStyle(
        fontFamily: _font,
        fontSize: 64.sp,
        color: AppColors.textPrimary,
        letterSpacing: 3.0,
        fontWeight: FontWeight.w500,
      );
}
