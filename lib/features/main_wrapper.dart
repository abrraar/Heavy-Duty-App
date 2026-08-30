import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/constants/dimensions.dart';
import 'package:heavy_duty/features/affirmation/widgets/affirmation_settings_sheet.dart';
import 'package:heavy_duty/core/utils/adaptive_utils.dart';
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
    final double height = size.height;
    
    // BREAKPOINTS
    final bool isCompact = width < kMobileBreakpoint; // < 600
    final bool isMedium = width >= kMobileBreakpoint && width < kTabletBreakpoint; // 600 - 900
    final bool isExpanded = width >= kTabletBreakpoint; // > 900

    // [LAYOUT_DEBUG] MainWrapper configuration
    debugPrint("[LAYOUT_DEBUG] MainWrapper -> Width: $width, Height: $height, isCompact: $isCompact, isMedium: $isMedium, isExpanded: $isExpanded");

    final String formattedDate = DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false, 
        bottom: true,
        child: Row(
          children: [
            // ── NAVIGATION RAIL (MEDIUM & EXPANDED) ───────────────────────────
            if (!isCompact)
              Container(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.white.withValues(alpha : 0.05), width: 1)),
                ),
                child: _AdaptiveNavigationRail(
                  currentIndex: currentIndex,
                  isExpanded: width >= 1200, // Only show full text on very wide screens
                  onTap: (index) => _onNavTap(context, index),
                ),
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
                    child: child,
                  ),
                ],
              ),
            ),
          ],
        ),
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
      case "affirmation": 
        AdaptiveUtils.showAdaptiveSheet(
          context: context, 
          sheetBuilder: (sheetContext, isSideSheet) => AffirmationSettingsSheet(isSideSheet: isSideSheet),
        );
        break;
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
        border: Border(bottom: BorderSide(color: AppColors.white.withValues(alpha : 0.05), width: 1)),
      ),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isCompact ? double.infinity : kMaxContentWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 20.w : 24.0, // Fixed padding for tablet
            vertical: 16.0,
          ).copyWith(top: MediaQuery.of(context).padding.top + 12.0),
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
                        width: 3.0,
                        height: isCompact ? 10 : 14.0,
                        decoration: BoxDecoration(color: AppColors.crimson, borderRadius: BorderRadius.circular(4.0)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5,
                          fontSize: (isCompact ? 10.sp : 11.0).clamp(9, 14),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: AppTextStyles.displayMedium.copyWith(
                      fontSize: (isCompact ? 26.sp : 32.0).clamp(24, 42),
                      letterSpacing: -0.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onSettingsTap,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha : 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white.withValues(alpha : 0.05)),
                  ),
                  child: const Icon(Icons.settings, color: AppColors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
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
    return Theme(
      data: Theme.of(context).copyWith(
        navigationRailTheme: NavigationRailThemeData(
          indicatorColor: AppColors.crimson.withValues(alpha: 0.12),
          indicatorShape: const StadiumBorder(), // Soft, faded feel without hard corners
        ),
      ),
      child: NavigationRail(
        extended: isExpanded,
        labelType: isExpanded ? NavigationRailLabelType.none : NavigationRailLabelType.selected,
        backgroundColor: AppColors.background,
        unselectedIconTheme: IconThemeData(color: AppColors.white.withValues(alpha: 0.2), size: 28),
        selectedIconTheme: const IconThemeData(color: AppColors.white, size: 32),
        unselectedLabelTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),
        selectedLabelTextStyle: AppTextStyles.labelSmall.copyWith(
          color: AppColors.white, 
          fontWeight: FontWeight.w500, 
          fontSize: 10.0, // Fixed DP for consistency
          letterSpacing: 1
        ),
        onDestinationSelected: onTap,
        selectedIndex: currentIndex,
        minWidth: 72, // Standard Material width
        minExtendedWidth: 200,
        groupAlignment: -0.8, // Match foldable alignment
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Image.asset(
            'lib/assets/images/heavy_duty_app_icon.png',
            width: 40,
            height: 40,
          ),
        ),
        destinations: [
          _buildDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_filled,
            label: 'HOME',
          ),
          _buildDestination(
            icon: Icons.fitness_center_outlined,
            selectedIcon: Icons.fitness_center_rounded,
            label: 'EXERCISES',
          ),
          _buildDestination(
            icon: Icons.edit_note_outlined,
            selectedIcon: Icons.edit_note_rounded,
            label: 'TRACKER',
          ),
          _buildDestination(
            icon: Icons.person_outline,
            selectedIcon: Icons.person_rounded,
            label: 'PROFILE',
          ),
        ],
      ),
    );
  }

  NavigationRailDestination _buildDestination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    return NavigationRailDestination(
      icon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Icon(icon),
      ),
      selectedIcon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Icon(selectedIcon),
      ),
      label: Text(label),
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
        border: Border(top: BorderSide(color: AppColors.white.withValues(alpha : 0.05), width: 1)),
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
