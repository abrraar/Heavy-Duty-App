import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';

class ImportMealScreen extends StatefulWidget {
  final String shareId;
  final String senderName;

  const ImportMealScreen({super.key, required this.shareId, required this.senderName});

  @override
  State<ImportMealScreen> createState() => _ImportMealScreenState();
}

class _ImportMealScreenState extends State<ImportMealScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _mealData;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final provider = context.read<CalorieProvider>();
    final data = await provider.fetchSharedMeal(widget.shareId);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null && data.containsKey('expired')) {
          _isExpired = true;
        } else {
          _mealData = data;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.crimson)),
      );
    }

    if (_isExpired || _mealData == null) {
      return _buildExpiredState();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSenderInfo(),
                    SizedBox(height: 32.h),
                    Text(
                      "MEAL COMPOSITION",
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 2),
                    ),
                    SizedBox(height: 16.h),
                    _buildMealSummary(),
                    SizedBox(height: 40.h),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 8.w),
      child: Center(
        child: Text(
          "SHARED MEAL",
          style: AppTextStyles.h2.copyWith(color: AppColors.white, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
      ),
    );
  }

  Widget _buildSenderInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu_rounded, color: AppColors.crimson, size: 40.r),
          SizedBox(height: 12.h),
          Text(
            widget.senderName.toUpperCase(),
            style: AppTextStyles.h3.copyWith(fontSize: 18.sp),
          ),
          Text(
            "HAS SHARED A MEAL TEMPLATE WITH YOU",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildMealSummary() {
    final name = _mealData!['name'] as String;
    final foodItems = _mealData!['foodItems'] as String;
    final calories = (_mealData!['calories'] as num).toDouble();
    final protein = (_mealData!['protein'] as num?)?.toDouble();
    final carbs = (_mealData!['carbs'] as num?)?.toDouble();
    final fats = (_mealData!['fats'] as num?)?.toDouble();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.toUpperCase(), style: AppTextStyles.h3.copyWith(color: Colors.white, fontSize: 20.sp)),
          if (foodItems.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(foodItems, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 12.sp)),
          ],
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric("CALORIES", calories.toInt().toString(), "KCAL"),
              if (protein != null) _buildMetric("PROTEIN", protein.toInt().toString(), "G"),
              if (carbs != null) _buildMetric("CARBS", carbs.toInt().toString(), "G"),
              if (fats != null) _buildMetric("FATS", fats.toInt().toString(), "G"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 8.sp, fontWeight: FontWeight.bold)),
        Text(value, style: AppTextStyles.h3.copyWith(color: AppColors.crimson, fontSize: 18.sp)),
        Text(unit, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.3), fontSize: 7.sp)),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.crimson,
            minimumSize: Size(double.infinity, 56.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
          onPressed: () async {
            await context.read<CalorieProvider>().importSharedMeal(_mealData!);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("MEAL SAVED TO LIBRARY")),
              );
              context.go('/tracker/calorie?tab=2'); 
            }
          },
          child: Text("SAVE TO LIBRARY", style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
        SizedBox(height: 12.h),
        TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: Text("CANCEL", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildExpiredState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(40.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_off_rounded, color: AppColors.textSecondary.withOpacity(0.2), size: 80.r),
              SizedBox(height: 24.h),
              Text("LINK EXPIRED", style: AppTextStyles.h2.copyWith(letterSpacing: 4)),
              SizedBox(height: 16.h),
              Text(
                "THIS SHARED MEAL IS NO LONGER AVAILABLE. SHARE LINKS IN HEAVY DUTY ARE VALID FOR 7 DAYS ONLY.",
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
              SizedBox(height: 40.h),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface, minimumSize: Size(200.w, 50.h)),
                onPressed: () => context.go(AppRoutes.home),
                child: Text("RETURN TO HOME", style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
