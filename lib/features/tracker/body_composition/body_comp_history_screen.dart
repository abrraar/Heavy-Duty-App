import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';
import 'model/body_comp_log.dart';

class BodyCompHistoryScreen extends StatefulWidget {
  const BodyCompHistoryScreen({super.key});

  @override
  State<BodyCompHistoryScreen> createState() => _BodyCompHistoryScreenState();
}

class _BodyCompHistoryScreenState extends State<BodyCompHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 8.w),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'HISTORY',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Opacity(
                    opacity: 0,
                    child: IconButton(
                      icon: Icon(Icons.info_outline_rounded),
                      onPressed: null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Consumer<BodyCompProvider>(
              builder: (context, provider, _) {
                if (provider.logs.isEmpty) return _buildEmptyState();

                // Group logs by timestamp (to the minute) to show as single "entries" if they happened together
                final Map<String, List<BodyCompLog>> groupedLogs = {};
                for (var log in provider.logs) {
                  final key = DateFormat('yyyy-MM-dd HH:mm').format(log.timestamp);
                  groupedLogs.putIfAbsent(key, () => []).add(log);
                }

                final sortedKeys = groupedLogs.keys.toList()..sort((a, b) => b.compareTo(a));

                return RefreshIndicator(
                  onRefresh: () => provider.forceRefresh(),
                  color: AppColors.crimson,
                  backgroundColor: AppColors.surface,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      final key = sortedKeys[index];
                      final logs = groupedLogs[key]!;
                      return _buildHistoryCard(context, logs, provider);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No entries found.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, List<BodyCompLog> logs, BodyCompProvider provider) {
    final firstLog = logs.first;
    String formattedDate = DateFormat('MMM dd, yyyy').format(firstLog.timestamp);
    final String groupKey = DateFormat('yyyy-MM-dd HH:mm').format(firstLog.timestamp);

    final weightLog = logs.where((l) => l.type == BodyMetricType.weight).firstOrNull;
    final fatLog = logs.where((l) => l.type == BodyMetricType.fat).firstOrNull;
    final muscleLog = logs.where((l) => l.type == BodyMetricType.muscle).firstOrNull;

    return Dismissible(
      key: Key(groupKey),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
            title: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.delete_forever_rounded, color: AppColors.crimson, size: 28.r),
                ),
                SizedBox(height: 16.h),
                Text("DELETE RECORD", style: AppTextStyles.h3.copyWith(fontSize: 16.sp, letterSpacing: 1.2)),
              ],
            ),
            content: Text(
              "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE ALL METRICS FOR THIS ENTRY?",
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.white.withOpacity(0.1)),
                          ),
                          alignment: Alignment.center,
                          child: Text("CANCEL", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.crimson.withOpacity(0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text("DELETE", style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        for (var log in logs) {
          await provider.deleteLog(log.id, log.type);
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24.w),
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: AppColors.crimson,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28.r),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3.w,
                      height: 12.h,
                      decoration: BoxDecoration(
                        color: AppColors.crimson,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(formattedDate, style: AppTextStyles.labelSmall),
                  ],
                ),
                Icon(
                  Icons.monitor_weight_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 18.r,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Weight', weightLog != null ? '${weightLog.value}kg' : '--', weightLog, provider),
                _buildStatItem('Body Fat', fatLog != null ? '${fatLog.value}%' : '--', fatLog, provider),
                _buildStatItem('Muscle', muscleLog != null ? '${muscleLog.value}kg' : '--', muscleLog, provider),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, BodyCompLog? log, BodyCompProvider provider) {
    return GestureDetector(
      onLongPress: log == null ? null : () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text("Delete Entry?", style: AppTextStyles.h3),
            content: Text("Remove this $label record?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("DELETE", style: TextStyle(color: AppColors.crimson))),
            ],
          ),
        );
        if (confirm == true) {
          await provider.deleteLog(log.id, log.type);
        }
      },
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}
