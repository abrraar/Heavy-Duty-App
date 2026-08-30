import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 600;
            return Column(
              children: [
                _buildHeader(isCompact),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 24.w : 24.0, 
                      vertical: isCompact ? 20.h : 20.0
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSenderInfo(isCompact),
                        SizedBox(height: isCompact ? 32.h : 32.0),
                        Text(
                          "WORKOUT ARCHITECTURE",
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary, 
                            letterSpacing: 2,
                            fontSize: isCompact ? null : 11.0,
                          ),
                        ),
                        SizedBox(height: isCompact ? 16.h : 16.0),
                        ...workouts.asMap().entries.map((entry) => _buildWorkoutSummary(entry.key, entry.value, isCompact)),
                        SizedBox(height: isCompact ? 40.h : 40.0),
                        _buildActions(isCompact),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 24.h : 24.0, 
        horizontal: isCompact ? 24.w : 24.0
      ),
      child: Text(
        "SHARED CYCLE",
        textAlign: TextAlign.center,
        style: AppTextStyles.h2.copyWith(
          color: AppColors.white, 
          fontWeight: FontWeight.w500, 
          letterSpacing: 2,
          fontSize: isCompact ? null : 20.0,
        ),
      ),
    );
  }

  Widget _buildSenderInfo(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        border: Border.all(color: AppColors.white.withValues(alpha : 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.person_pin_rounded, color: AppColors.crimson, size: isCompact ? 40.r : 36.0),
          SizedBox(height: isCompact ? 12.h : 12.0),
          Text(
            widget.senderName.toUpperCase(),
            style: AppTextStyles.h3.copyWith(fontSize: isCompact ? 18.sp : 16.0),
          ),
          Text(
            "HAS SHARED A TRAINING ARCHITECTURE WITH YOU",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary.withValues(alpha : 0.5), 
              fontSize: isCompact ? 10.sp : 11.0
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutSummary(int index, dynamic workout, bool isCompact) {
    final List exercises = workout['exercises'] as List;
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 16.h : 16.0),
      padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "SESSION ${index + 1}: ${workout['name']}",
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.white, 
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? null : 13.0,
            ),
          ),
          SizedBox(height: isCompact ? 8.h : 8.0),
          ...exercises.map((ex) => Padding(
            padding: EdgeInsets.only(
              left: isCompact ? 12.w : 12.0, 
              top: isCompact ? 4.h : 4.0
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppColors.crimson, size: isCompact ? 12.r : 12.0),
                SizedBox(width: isCompact ? 8.w : 8.0),
                Text(
                  ex['name'].toString().toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary, 
                    fontSize: isCompact ? 11.sp : 12.0
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildActions(bool isCompact) {
    return Column(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.crimson,
            minimumSize: Size(double.infinity, isCompact ? 56.h : 50.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0)),
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
          child: Text("SAVE AS TEMPLATE", style: AppTextStyles.labelMedium.copyWith(
            color: Colors.white, 
            fontWeight: FontWeight.w500,
            fontSize: isCompact ? null : 14.0,
          )),
        ),
        SizedBox(height: isCompact ? 12.h : 12.0),
        TextButton(
          onPressed: () => context.go('${AppRoutes.cycleTracking}?tab=2'),
          child: Text("CANCEL", style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: isCompact ? null : 12.0,
          )),
        ),
      ],
    );
  }

  Widget _buildExpiredState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600;
          return Center(
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 40.r : 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isCompact ? double.infinity : 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_off_rounded, color: AppColors.textSecondary.withValues(alpha : 0.2), size: isCompact ? 80.r : 70.0),
                    SizedBox(height: isCompact ? 24.h : 24.0),
                    Text(
                      "LINK EXPIRED",
                      style: AppTextStyles.h2.copyWith(
                        letterSpacing: 4,
                        fontSize: isCompact ? null : 22.0,
                      ),
                    ),
                    SizedBox(height: isCompact ? 16.h : 16.0),
                    Text(
                      "THIS SHARED ARCHITECTURE IS NO LONGER AVAILABLE. SHARE LINKS IN HEAVY DUTY ARE VALID FOR 7 DAYS ONLY.",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary, 
                        height: 1.5,
                        fontSize: isCompact ? null : 12.0,
                      ),
                    ),
                    SizedBox(height: isCompact ? 40.h : 40.0),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface, 
                        minimumSize: Size(isCompact ? 200.w : 180.0, isCompact ? 50.h : 46.0)
                      ),
                      onPressed: () => context.go(AppRoutes.home),
                      child: Text("RETURN TO HOME", style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: isCompact ? null : 12.0,
                      )),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

}
