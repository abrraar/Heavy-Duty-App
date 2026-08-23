import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/features/main_wrapper.dart';
import 'provider/affirmation_provider.dart';
import 'model/affirmation.dart';

class AffirmationScreen extends StatefulWidget {
  const AffirmationScreen({super.key});

  @override
  State<AffirmationScreen> createState() => _AffirmationScreenState();
}

class _AffirmationScreenState extends State<AffirmationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _addController = TextEditingController();
  
  final ScrollController _systemScrollController = ScrollController();
  final ScrollController _customScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "affirmation";
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    activeSettingsContext.value = "";
    _tabController.dispose();
    _addController.dispose();
    _systemScrollController.dispose();
    _customScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWheelView(isSystem: true),
                  _buildCustomWheelView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text("AFFIRMATIONS", style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w900)),
          const Opacity(opacity: 0, child: IconButton(icon: Icon(Icons.settings), onPressed: null)),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.crimson,
        labelColor: AppColors.crimson,
        unselectedLabelColor: AppColors.textSecondary,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "SYSTEM"),
          Tab(text: "CUSTOM"),
        ],
      ),
    );
  }

  Widget _buildWheelView({required bool isSystem}) {
    return Consumer<AffirmationProvider>(
      builder: (context, provider, _) {
        // Show all in the library scroller
        final items = isSystem ? provider.allSystemAffirmations : provider.allCustomAffirmations;

        if (items.isEmpty) {
          return Center(
            child: Text(
              isSystem ? "NO SYSTEM DATA" : "NO CUSTOM DATA",
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.3)),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double viewportHeight = constraints.maxHeight;
            final double itemHeight = viewportHeight * 0.55; 

            return ListWheelScrollView.useDelegate(
              itemExtent: itemHeight,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.5,
              perspective: 0.003,
              squeeze: 1.0,
              overAndUnderCenterOpacity: 0.2,
              useMagnifier: true,
              magnification: 1.15,
              onSelectedItemChanged: (index) {
                debugPrint('Active Affirmation Index: $index');
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: items.length,
                builder: (context, index) {
                  final aff = items[index];
                  return Center(
                    child: _buildItemContent(aff, provider),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomWheelView() {
    return Column(
      children: [
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: GestureDetector(
            onTap: _showAddDialog,
            child: Container(
              height: 50.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.crimson.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.crimson.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: AppColors.crimson, size: 20.r),
                  SizedBox(width: 8.w),
                  Text(
                    "ADD CUSTOM AFFIRMATION",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.crimson,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _buildWheelView(isSystem: false)),
      ],
    );
  }

  Widget _buildItemContent(Affirmation aff, AffirmationProvider provider) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // The text is placed inside a ConstrainedBox to ensure it respects the itemExtent
          // but allows for multi-line wrapping of long quotes.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 350.h),
            child: Text(
              aff.text.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTextStyles.displayMedium.copyWith(
                fontSize: 15.sp,
                height: 1.3,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (aff.isCustom)
            Positioned(
              right: -30.w,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.error.withValues(alpha: 0.4), size: 24.r),
                  onPressed: () => provider.deleteAffirmation(aff.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("ADD AFFIRMATION", style: AppTextStyles.h3),
        content: TextField(
          controller: _addController,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter custom quote...",
            hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(
              "CANCEL", 
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontWeight: FontWeight.bold)
            )
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.crimson,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            onPressed: () {
              if (_addController.text.trim().isNotEmpty) {
                context.read<AffirmationProvider>().addAffirmation(_addController.text.trim());
                _addController.clear();
                Navigator.pop(context);
              }
            },
            child: Text(
              "ADD", 
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w900)
            ),
          ),
        ],
      ),
    );
  }
}
