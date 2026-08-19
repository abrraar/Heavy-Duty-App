import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/constants/dimensions.dart';
import 'package:heavy_duty/features/settings/body_comp_settings_screen.dart';
import 'package:heavy_duty/features/settings/calorie_settings_screen.dart';
import 'package:heavy_duty/features/settings/cycle_tracking_settings_screen.dart';
import 'package:heavy_duty/features/settings/hydration_settings_screen.dart';
import 'package:heavy_duty/features/settings/settings_screen.dart';
import 'package:heavy_duty/features/settings/sleep_settings_screen.dart';
import 'package:heavy_duty/features/settings/supplement_settings_screen.dart';
import 'package:heavy_duty/features/affirmation/widgets/affirmation_settings_sheet.dart';
import 'package:intl/intl.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/app_bottom_navbar.dart';

final ValueNotifier<String> activeSettingsContext = ValueNotifier<String>("");

class MainWrapper extends StatelessWidget {
  final Widget child;
  final int currentIndex;

  const MainWrapper({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double width = size.width;
    final bool isCompact = width < kCompactBreakpoint;
    final bool isExpanded = width >= kExpandedBreakpoint;

    final String formattedDate = DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // ── NAVIGATION RAIL (MEDIUM & EXPANDED) ───────────────────────────
          if (!isCompact)
            _AdaptiveNavigationRail(
              currentIndex: currentIndex,
              isExpanded: isExpanded,
              onTap: (index) => _onNavTap(context, index),
            ),

          // ── MAIN CONTENT AREA ───────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _AdaptiveTopAppBar(
                  formattedDate: formattedDate,
                  title: _getTitle(currentIndex),
                  isCompact: isCompact,
                  onSettingsTap: () => _openSettings(context),
                ),
                Expanded(
                  // Full-width child to prevent gesture dead zones in margins
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),

      // ── BOTTOM NAVIGATION (COMPACT ONLY) ─────────────────────────────
      bottomNavigationBar: isCompact
          ? _CompactBottomNav(
              currentIndex: currentIndex,
              onTap: (index) => _onNavTap(context, index),
            )
          : null,
    );
  }

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go(AppRoutes.home); break;
      case 1: context.go(AppRoutes.exercises); break;
      case 2: context.go(AppRoutes.tracker); break;
      case 3: context.go(AppRoutes.profile); break;
    }
  }

  void _openSettings(BuildContext context) {
    final String currentContext = activeSettingsContext.value;
    switch (currentContext) {
      case "hydration": context.push(AppRoutes.settingsHydration); break;
      case "body_comp": context.push(AppRoutes.settingsBodyComp); break;
      case "cycle": context.push(AppRoutes.settingsCycle); break;
      case "sleep": context.push(AppRoutes.settingsSleep); break;
      case "calorie": context.push(AppRoutes.settingsCalorie); break;
      case "supplement": context.push(AppRoutes.settingsSupplement); break;
      case "affirmation": AffirmationSettingsSheet.show(context); break;
      default: context.push(AppRoutes.settings);
    }
  }

  String _getTitle(int index) {
    switch (index) {
      case 0: return 'HOME';
      case 1: return 'EXERCISES';
      case 2: return 'TRACKER';
      case 3: return 'PROFILE';
      default: return 'HOME';
    }
  }
}

class _AdaptiveTopAppBar extends StatelessWidget {
  final String formattedDate;
  final String title;
  final bool isCompact;
  final VoidCallback onSettingsTap;

  const _AdaptiveTopAppBar({
    required this.formattedDate,
    required this.title,
    required this.isCompact,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.white.withOpacity(0.05), width: 1)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 20.w : 40.r,
        vertical: 16.r,
      ).copyWith(top: MediaQuery.of(context).padding.top + 12.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3.r,
                    height: isCompact ? 10 : 14.r,
                    decoration: BoxDecoration(color: AppColors.crimson, borderRadius: BorderRadius.circular(4.r)),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    formattedDate,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                      fontSize: (isCompact ? 10.sp : 12.sp).clamp(9, 14),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.r),
              Text(
                title,
                style: AppTextStyles.displayMedium.copyWith(
                  fontSize: (isCompact ? 26.sp : 36.sp).clamp(24, 42),
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: onSettingsTap,
            child: Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white.withOpacity(0.05)),
              ),
              child: Icon(Icons.settings, color: AppColors.white, size: 22.r),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveNavigationRail extends StatelessWidget {
  final int currentIndex;
  final bool isExpanded;
  final Function(int) onTap;

  const _AdaptiveNavigationRail({
    required this.currentIndex,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: isExpanded,
      backgroundColor: AppColors.background,
      unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
      selectedIconTheme: const IconThemeData(color: AppColors.white),
      unselectedLabelTextStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
      selectedLabelTextStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
      onDestinationSelected: onTap,
      selectedIndex: currentIndex,
      leading: Padding(
        padding: EdgeInsets.symmetric(vertical: 24.r),
        child: Icon(Icons.bolt_rounded, color: AppColors.crimson, size: isExpanded ? 40.r : 32.r),
      ),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.home_filled), label: Text('Home')),
        NavigationRailDestination(icon: Icon(Icons.fitness_center_rounded), label: Text('Exercises')),
        NavigationRailDestination(icon: Icon(Icons.edit_note_rounded), label: Text('Tracker')),
        NavigationRailDestination(icon: Icon(Icons.person_rounded), label: Text('Profile')),
      ],
    );
  }
}

class _CompactBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _CompactBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.white.withOpacity(0.05), width: 1)),
      ),
      child: SafeArea(
        child: AppBottomNavbar(
          currentIndex: currentIndex,
          onTap: onTap,
        ),
      ),
    );
  }
}
