import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/exercise/model/exercise_template.dart';
import 'package:heavy_duty/features/exercise/provider/exercise_provider.dart';
import 'package:provider/provider.dart';

class ExercisePickerSheet extends StatefulWidget {
  final Function(String) onSelected;

  const ExercisePickerSheet({super.key, required this.onSelected});

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> with SingleTickerProviderStateMixin {
  String _searchQuery = "";
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("PICK EXERCISE", style: AppTextStyles.h3),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 12.r),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "SEARCH...",
                prefixIcon: const Icon(Icons.search, color: AppColors.crimson),
                filled: true,
                fillColor: AppColors.background.withOpacity(0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
          ),

          // TABS
          Container(
            width: double.infinity,
            height: 48.h,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: AppColors.white.withOpacity(0.05))),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.crimson, width: 3)),
              ),
              labelColor: AppColors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
              tabs: const [
                Tab(text: 'DEFAULT EXERCISES'),
                Tab(text: 'MY EXERCISES'),
              ],
            ),
          ),

          Expanded(
            child: Consumer<ExerciseProvider>(
              builder: (context, provider, _) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExerciseList(provider.defaultTemplates),
                    _buildExerciseList(provider.customTemplates),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList(List<ExerciseTemplate> templates) {
    final filtered = templates
        .where((t) => t.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          "NO EXERCISES FOUND",
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final t = filtered[index];
        return ListTile(
          onTap: () {
            widget.onSelected(t.name);
            Navigator.pop(context);
          },
          contentPadding: EdgeInsets.symmetric(vertical: 8.h),
          title: Text(t.name.toUpperCase(), style: AppTextStyles.labelMedium.copyWith(color: Colors.white)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.targetMuscles?.toUpperCase() ?? "GENERAL", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: t.type == ExerciseType.compound ? AppColors.crimson.withOpacity(0.2) : AppColors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  t.type.name.toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: t.type == ExerciseType.compound ? AppColors.crimson : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          trailing: Icon(Icons.add_circle_outline, color: AppColors.crimson, size: 20.r),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 16.h),
        width: 40.w,
        height: 4.h,
        decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.2), borderRadius: BorderRadius.circular(2.r)),
      ),
    );
  }
}
