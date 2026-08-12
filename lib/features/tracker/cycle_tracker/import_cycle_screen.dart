import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/cycle_tracking_screen.dart';

class ImportCycleScreen extends StatefulWidget {
  final String shareId;
  final String senderName;

  const ImportCycleScreen({super.key, required this.shareId, required this.senderName});

  @override
  State<ImportCycleScreen> createState() => _ImportCycleScreenState();
}

class _ImportCycleScreenState extends State<ImportCycleScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _cycleData;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final provider = context.read<CycleProvider>();
    final data = await provider.fetchSharedCycle(widget.shareId);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null && data.containsKey('expired')) {
          _isExpired = true;
        } else {
          _cycleData = data;
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

    if (_isExpired || _cycleData == null) {
      return _buildExpiredState();
    }

    final String name = _cycleData!['name'];
    final List workouts = _cycleData!['workouts'] as List;

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
                      "WORKOUT ARCHITECTURE",
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 2),
                    ),
                    SizedBox(height: 16.h),
                    ...workouts.asMap().entries.map((entry) => _buildWorkoutSummary(entry.key, entry.value)),
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
          "SHARED CYCLE",
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
          Icon(Icons.person_pin_rounded, color: AppColors.crimson, size: 40.r),
          SizedBox(height: 12.h),
          Text(
            widget.senderName.toUpperCase(),
            style: AppTextStyles.h3.copyWith(fontSize: 18.sp),
          ),
          Text(
            "HAS SHARED A TRAINING ARCHITECTURE WITH YOU",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutSummary(int index, dynamic workout) {
    final List exercises = workout['exercises'] as List;
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "SESSION ${index + 1}: ${workout['name']}",
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          ...exercises.map((ex) => Padding(
            padding: EdgeInsets.only(left: 12.w, top: 4.h),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppColors.crimson, size: 12.r),
                SizedBox(width: 8.w),
                Text(
                  ex['name'].toString().toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 11.sp),
                ),
              ],
            ),
          )),
        ],
      ),
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
            await context.read<CycleProvider>().importSharedCycle(_cycleData!);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("TEMPLATE SAVED TO LIBRARY")),
              );
              // Navigate to the Library tab in the Cycle Tracking screen within the Shell
              context.go('${AppRoutes.cycleTracking}?tab=2');
            }
          },
          child: Text("SAVE AS TEMPLATE", style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
        SizedBox(height: 12.h),
        TextButton(
          onPressed: () => context.go('${AppRoutes.cycleTracking}?tab=2'),
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
              Text(
                "LINK EXPIRED",
                style: AppTextStyles.h2.copyWith(letterSpacing: 4),
              ),
              SizedBox(height: 16.h),
              Text(
                "THIS SHARED ARCHITECTURE IS NO LONGER AVAILABLE. SHARE LINKS IN HEAVY DUTY ARE VALID FOR 7 DAYS ONLY.",
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
