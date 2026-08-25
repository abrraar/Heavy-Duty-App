// lib/features/settings/supplement_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';

class SupplementSettingsScreen extends StatefulWidget {
  const SupplementSettingsScreen({super.key});

  @override
  State<SupplementSettingsScreen> createState() => _SupplementSettingsScreenState();
}

class _SupplementSettingsScreenState extends State<SupplementSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SupplementProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;
        
        final pinnedSupps = provider.library
            .where((s) => s.isActive && s.isPinnedToHome)
            .toList();
        final pinnedStacks = provider.supplementStacks
            .where((s) => s.isPinnedToHome)
            .toList();

        // Sort both independently
        pinnedSupps.sort((a, b) {
          final idxA = settings.pinnedOrder.indexOf(a.id);
          final idxB = settings.pinnedOrder.indexOf(b.id);
          if (idxA == -1 && idxB == -1) return 0;
          if (idxA == -1) return 1;
          if (idxB == -1) return -1;
          return idxA.compareTo(idxB);
        });

        pinnedStacks.sort((a, b) {
          final idxA = settings.pinnedOrder.indexOf(a.id);
          final idxB = settings.pinnedOrder.indexOf(b.id);
          if (idxA == -1 && idxB == -1) return 0;
          if (idxA == -1) return 1;
          if (idxB == -1) return -1;
          return idxA.compareTo(idxB);
        });

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                const EliteSettingsAppBar(title: "SUPPLEMENT SETTINGS"),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16.h),
                        _buildSectionHeader("GLOBAL PREFERENCES"),
                        _buildToggleCard(
                          title: "SHOW EXPIRED ITEMS",
                          subtitle: "DISPLAY SUPPLEMENTS PAST EXPIRY DATE",
                          value: settings.showExpired,
                          onChanged: (val) {
                            provider.updateSettings(settings.copyWith(showExpired: val));
                          },
                        ),
                        _buildToggleCard(
                          title: "HIDE EMPTY STOCK",
                          subtitle: "REMOVE ITEMS WITH 0 REMAINING FROM LOGS",
                          value: settings.hideEmptyStock,
                          onChanged: (val) {
                            provider.updateSettings(settings.copyWith(hideEmptyStock: val));
                          },
                        ),
                        
                        SizedBox(height: 32.h),
                        _buildSectionHeader("PINNED SUPPLEMENTS"),
                        Text(
                          "REORDER INDIVIDUAL SUPPLEMENT SHORTCUTS",
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp),
                        ),
                        SizedBox(height: 16.h),
                        if (pinnedSupps.isEmpty)
                          _buildEmptyPlaceholder("NO SUPPLEMENTS PINNED")
                        else
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pinnedSupps.length,
                            proxyDecorator: (child, index, animation) => Material(
                              type: MaterialType.transparency,
                              child: child,
                            ),
                            onReorder: (oldIdx, newIdx) {
                              if (newIdx > oldIdx) newIdx--;
                              final item = pinnedSupps.removeAt(oldIdx);
                              pinnedSupps.insert(newIdx, item);
                              
                              final List<String> newOrder = [
                                ...pinnedSupps.map((e) => e.id),
                                ...pinnedStacks.map((e) => e.id),
                              ];
                              provider.updatePinnedOrder(newOrder);
                            },
                            itemBuilder: (context, index) {
                              final item = pinnedSupps[index];
                              return _buildPinnedItemCard(
                                key: ValueKey(item.id),
                                name: item.name,
                                isStack: false,
                              );
                            },
                          ),

                        SizedBox(height: 32.h),
                        _buildSectionHeader("PINNED STACKS"),
                        Text(
                          "REORDER SUPPLEMENT STACK SHORTCUTS",
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp),
                        ),
                        SizedBox(height: 16.h),
                        if (pinnedStacks.isEmpty)
                          _buildEmptyPlaceholder("NO STACKS PINNED")
                        else
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pinnedStacks.length,
                            proxyDecorator: (child, index, animation) => Material(
                              type: MaterialType.transparency,
                              child: child,
                            ),
                            onReorder: (oldIdx, newIdx) {
                              if (newIdx > oldIdx) newIdx--;
                              final item = pinnedStacks.removeAt(oldIdx);
                              pinnedStacks.insert(newIdx, item);
                              
                              final List<String> newOrder = [
                                ...pinnedSupps.map((e) => e.id),
                                ...pinnedStacks.map((e) => e.id),
                              ];
                              provider.updatePinnedOrder(newOrder);
                            },
                            itemBuilder: (context, index) {
                              final item = pinnedStacks[index];
                              return _buildPinnedItemCard(
                                key: ValueKey(item.id),
                                name: item.name,
                                isStack: true,
                              );
                            },
                          ),
                        
                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Text(
          message,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.3)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
      child: Text(
        title,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.crimson,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp, letterSpacing: 0)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.crimson,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedItemCard({
    required Key key,
    required String name,
    required bool isStack,
  }) {
    return Container(
      key: key,
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(
            isStack ? Icons.layers_rounded : Icons.medication_rounded,
            color: isStack ? Colors.blueAccent : AppColors.crimson,
            size: 20.r,
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          Icon(Icons.drag_handle_rounded, color: AppColors.textSecondary.withOpacity(0.3), size: 20.r),
        ],
      ),
    );
  }
}
