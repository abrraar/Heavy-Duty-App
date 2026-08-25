// lib/features/tracker/hydration/hydration_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/hydration/widgets/hydration_analytical_widget.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'model/hydration_log.dart';
import 'provider/hydration_provider.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:heavy_duty/features/main_wrapper.dart';
import 'widgets/water_glass_widget.dart';

class _HydrationFilter {
  bool isDescending;
  DateTimeRange? dateRange;
  int? year;
  int? month;
  double? minAmount;
  double? maxAmount;

  _HydrationFilter({
    this.isDescending = true,
    this.dateRange,
    this.year,
    this.month,
    this.minAmount,
    this.maxAmount,
  });

  bool get isInitial =>
      isDescending &&
      dateRange == null &&
      year == null &&
      month == null &&
      minAmount == null &&
      maxAmount == null;

  _HydrationFilter copyWith({
    bool? isDescending,
    DateTimeRange? dateRange,
    int? year,
    int? month,
    double? minAmount,
    double? maxAmount,
  }) {
    return _HydrationFilter(
      isDescending: isDescending ?? this.isDescending,
      dateRange: dateRange,
      year: year,
      month: month,
      minAmount: minAmount,
      maxAmount: maxAmount,
    );
  }
}

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  final _HydrationFilter _recordsFilter = _HydrationFilter();

  DateTime _selectedHistoryDate = DateTime.now();
  DateTime _displayedMonth = DateTime.now();
  bool _isCalendarExpanded = false;

  // Trends Tab State
  final Set<String> _visibleTrendsMetrics = {"water"};
  int? _comparisonIdx1;
  int? _comparisonIdx2;

  // Manual Entry State
  DateTime _manualDate = DateTime.now();
  TimeOfDay _manualTime = TimeOfDay.now();
  final TextEditingController _amountController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "hydration";
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _pageController = PageController(
      viewportFraction: 0.2,
      initialPage: 0,
    );
    _displayedMonth = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month);
  }

  @override
  void dispose() {
    activeSettingsContext.value = "";
    _tabController.dispose();
    _pageController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickManualDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _manualDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _manualDate = picked);
    }
  }

  Future<void> _pickManualTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _manualTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
            timePickerTheme: Theme.of(context).timePickerTheme.copyWith(
              dayPeriodColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.blueAccent;
                }
                return Colors.white.withOpacity(0.05);
              }),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _manualTime = picked);
    }
  }

  Future<bool?> _showDeleteLogConfirmation(String amount) async {
    return EliteConfirmDialog.show(
      context,
      title: "DELETE LOG",
      message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THE '$amount' ENTRY?",
      icon: Icons.delete_forever_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HydrationProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;
        final isPinned = settings.isPinnedToHome;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(left: 8.w, right: 8.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 80.w,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: AppColors.white,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'HYDRATION',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.h2.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80.w,
                              child: const Opacity(
                                opacity: 0,
                                child: IconButton(
                                  icon: Icon(Icons.arrow_back_ios_new_rounded),
                                  onPressed: null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.blueAccent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold),
                      unselectedLabelColor: AppColors.textSecondary.withOpacity(0.5),
                      labelColor: Colors.blueAccent,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: "TRACKER"),
                        Tab(text: "TRENDS"),
                        Tab(text: "LOGS"),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTrackerTab(provider),
                    _buildTrendsTab(provider),
                    _buildRecordsTab(provider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackerTab(HydrationProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.forceRefresh(),
      color: Colors.blueAccent,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10.h),
            _buildCurrentIntakeCard(provider),
            SizedBox(height: 24.h),
            _buildManualEntryCard(provider),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsTab(HydrationProvider provider) {
    if (provider.logs.isEmpty) {
      return Center(
        child: Text(
          "LOG INTAKE TO VIEW TRENDS",
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withOpacity(0.3),
            letterSpacing: 1,
          ),
        ),
      );
    }

    // Aggregate logs by identical timestamp (ignoring seconds/milliseconds)
    final Map<DateTime, double> aggregatedMap = {};
    for (var log in provider.logs) {
      final ts = log.timestamp;
      final normalized = DateTime(ts.year, ts.month, ts.day, ts.hour, ts.minute);
      aggregatedMap[normalized] = (aggregatedMap[normalized] ?? 0.0) + log.amountMl.toDouble();
    }

    final sortedEntries = aggregatedMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final List<DateTime> sortedDates = sortedEntries.map((e) => e.key).toList();
    final Map<String, List<double?>> aggregatedData = {
      "water": sortedEntries.map((e) => e.value).toList(),
    };

    return RefreshIndicator(
      onRefresh: () => provider.forceRefresh(),
      color: Colors.blueAccent,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.all(24.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("INTAKE TRENDS (ML)"),
            SizedBox(height: 24.h),
            HydrationAnalyticalGraph(
              dates: sortedDates,
              data: aggregatedData,
              visibleMetrics: _visibleTrendsMetrics,
              onPointSelected: (idx) {},
            ),
            SizedBox(height: 40.h),
            _buildSectionHeader("DATA COMPARISON"),
            SizedBox(height: 16.h),
            HydrationComparisonWidget(
              idx1: _comparisonIdx1,
              idx2: _comparisonIdx2,
              dates: sortedDates,
              data: aggregatedData,
              onPointAChanged: (val) => setState(() => _comparisonIdx1 = val),
              onPointBChanged: (val) => setState(() => _comparisonIdx2 = val),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 2.5.w,
          height: 12.h,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withOpacity(0.8),
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsTab(HydrationProvider provider) {
    final Set<DateTime> dateSet = provider.logs.map((l) => 
      DateTime(l.timestamp.year, l.timestamp.month, l.timestamp.day)
    ).toSet();
    
    final now = DateTime.now();
    dateSet.add(DateTime(now.year, now.month, now.day));

    final List<HydrationLog> filteredLogs = provider.logs.where((log) {
      if (_recordsFilter.isInitial) {
        return log.timestamp.year == _selectedHistoryDate.year &&
               log.timestamp.month == _selectedHistoryDate.month &&
               log.timestamp.day == _selectedHistoryDate.day;
      }
      if (_recordsFilter.dateRange != null) {
        final start = DateTime(_recordsFilter.dateRange!.start.year, _recordsFilter.dateRange!.start.month, _recordsFilter.dateRange!.start.day);
        final end = DateTime(_recordsFilter.dateRange!.end.year, _recordsFilter.dateRange!.end.month, _recordsFilter.dateRange!.end.day, 23, 59, 59);
        if (log.timestamp.isBefore(start) || log.timestamp.isAfter(end)) return false;
      }
      if (_recordsFilter.year != null && log.timestamp.year != _recordsFilter.year) return false;
      if (_recordsFilter.month != null && log.timestamp.month != _recordsFilter.month) return false;
      final double amount = log.amountMl.toDouble();
      if (_recordsFilter.minAmount != null && amount < _recordsFilter.minAmount!) return false;
      if (_recordsFilter.maxAmount != null && amount > _recordsFilter.maxAmount!) return false;
      return true;
    }).toList();

    filteredLogs.sort((a, b) {
      return _recordsFilter.isDescending 
          ? b.timestamp.compareTo(a.timestamp) 
          : a.timestamp.compareTo(b.timestamp);
    });
    
    if (_isCalendarExpanded) {
      return Container(
        color: AppColors.background,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildCustomExpandedCalendar(dateSet),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _isCalendarExpanded = false);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final target = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month, _selectedHistoryDate.day);
                  final int dayDiff = today.difference(target).inDays;
                  if (dayDiff >= 0 && dayDiff < 365) {
                    if (_pageController.hasClients) {
                      _pageController.animateToPage(
                        dayDiff, 
                        duration: const Duration(milliseconds: 300), 
                        curve: Curves.easeInOut
                      );
                    }
                  }
                });
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                color: Colors.transparent,
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  size: 24.r,
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHorizontalCalendar(dateSet),
        GestureDetector(
          onTap: () {
            setState(() {
              _isCalendarExpanded = true;
              _displayedMonth = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month);
            });
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 4.h),
            color: Colors.transparent,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              size: 24.r,
            ),
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.forceRefresh(),
            color: Colors.blueAccent,
            backgroundColor: AppColors.surface,
            child: filteredLogs.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Container(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Text(
                              _recordsFilter.isInitial ? "NO LOGS FOR THIS DATE" : "NO MATCHING LOGS",
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(20.r),
                    itemCount: filteredLogs.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      return Dismissible(
                        key: Key(log.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 24.w),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
                        ),
                        confirmDismiss: (direction) async {
                          return await _showDeleteLogConfirmation(provider.formatAmount(log.amountMl));
                        },
                        onDismissed: (direction) {
                          provider.deleteLog(log.id);
                        },
                        child: Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: AppColors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.formatAmount(log.amountMl),
                                    style: AppTextStyles.h3.copyWith(fontSize: 18.sp, color: Colors.blueAccent),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    DateFormat('MMM dd, yyyy - hh:mm a').format(log.timestamp),
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp),
                                  ),
                                ],
                              ),
                              Icon(Icons.water_drop_outlined, color: Colors.blueAccent.withOpacity(0.5), size: 20.r),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentIntakeCard(HydrationProvider provider) {
    int currentIntakeMl = provider.todayIntake;
    int goalIntakeMl = provider.settings.dailyGoal;
    int remainingMl = goalIntakeMl - currentIntakeMl;
    double progress = (currentIntakeMl / goalIntakeMl).clamp(0.0, 1.0);
    
    bool useMetric = provider.settings.useMetric;
    String unit = useMetric ? "ML" : "OZ";
    
    String displayIntake = useMetric ? currentIntakeMl.toString() : provider.mlToOz(currentIntakeMl).toStringAsFixed(1);
    String displayGoal = useMetric ? goalIntakeMl.toString() : provider.mlToOz(goalIntakeMl).toStringAsFixed(1);
    String displayRemaining = useMetric ? remainingMl.abs().toString() : provider.mlToOz(remainingMl.abs()).toStringAsFixed(1);
    
    int quickAddMl = provider.settings.addValue;
    int quickRemoveMl = provider.settings.minusValue;
    
    String displayQuickAdd = useMetric ? "$quickAddMl$unit" : "${provider.mlToOz(quickAddMl).toStringAsFixed(1)}$unit";
    String displayQuickRemove = useMetric ? "$quickRemoveMl$unit" : "${provider.mlToOz(quickRemoveMl).toStringAsFixed(1)}$unit";

    final settings = provider.settings;
    final isPinned = settings.isPinnedToHome;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "DAILY INTAKE",
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayIntake,
                    style: AppTextStyles.h1.copyWith(
                      fontSize: 32.sp,
                      color: AppColors.white,
                    ),
                  ),
                  Text(
                    "/ $displayGoal $unit",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    remainingMl <= 0 ? "GOAL REACHED" : "REMAINING: $displayRemaining $unit",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: remainingMl <= 0 ? Colors.greenAccent : Colors.blueAccent,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 100.r,
                width: 90.r,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WaterGlassWidget(
                      progress: progress,
                      size: 60,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      "${(progress * 100).toInt()}%",
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(child: _buildAdjustmentButton('- $displayQuickRemove', -quickRemoveMl, provider, isSubtract: true)),
              SizedBox(width: 12.w),
              Expanded(child: _buildAdjustmentButton('+ $displayQuickAdd', quickAddMl, provider)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAdjustmentButton(String label, int amountMl, HydrationProvider provider, {bool isSubtract = false}) {
    final color = isSubtract ? AppColors.error : Colors.blueAccent;
    return GestureDetector(
      onTap: () {
        provider.addWater(amountMl);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Text(label, style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontSize: 11.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        )),
      ),
    );
  }

  Widget _buildManualEntryCard(HydrationProvider provider) {
    bool useMetric = provider.settings.useMetric;
    String unit = useMetric ? "ml" : "oz";

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MANUAL LOG', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2)),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildManualEntryField(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('MMM dd, yyyy').format(_manualDate),
                  onTap: _pickManualDate,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildManualEntryField(
                  icon: Icons.access_time_rounded,
                  label: _manualTime.format(context),
                  onTap: _pickManualTime,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              style: AppTextStyles.labelMedium,
              decoration: InputDecoration(
                hintText: 'Enter amount ($unit)',
                hintStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                border: InputBorder.none,
                suffixText: unit,
                suffixStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: () async {
              double? amount = double.tryParse(_amountController.text);
              if (amount == null || amount <= 0) return;
              
              int amountInMl = useMetric ? amount.round() : provider.ozToMl(amount);
              
              DateTime finalTimestamp = DateTime(
                _manualDate.year, _manualDate.month, _manualDate.day,
                _manualTime.hour, _manualTime.minute,
              );
              
              final existing = provider.logs.where((l) => l.timestamp.isAtSameMomentAs(finalTimestamp)).toList();
              if (existing.isNotEmpty) {
                for (var log in existing) {
                  await provider.deleteLog(log.id);
                }
              }

              provider.addWater(amountInMl, timestamp: finalTimestamp);
              _amountController.clear();
              if (mounted) {
                EliteSnackbar.show(context, 'Water intake recorded!');
              }
            },
            child: Container(
              height: 48.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(12.r),
              ),
              alignment: Alignment.center,
              child: Text('LOG INTAKE', style: AppTextStyles.buttonPrimary.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntryField({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16.r, color: Colors.blueAccent),
            SizedBox(width: 8.w),
            Text(label, style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomExpandedCalendar(Set<DateTime> dateSet) {
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    final isCurrentMonth = _displayedMonth.year == DateTime.now().year && _displayedMonth.month == DateTime.now().month;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
                }),
              ),
              GestureDetector(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedHistoryDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.blueAccent,
                            onPrimary: Colors.white,
                            surface: AppColors.surface,
                            onSurface: Colors.white,
                          ),
                          textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedHistoryDate = picked;
                      _displayedMonth = DateTime(picked.year, picked.month);
                    });
                  }
                },
                child: Text(
                  DateFormat('MMMM yyyy').format(_displayedMonth).toUpperCase(),
                  style: AppTextStyles.labelMedium.copyWith(color: Colors.white, letterSpacing: 1.5),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: isCurrentMonth ? Colors.white.withValues(alpha: 0.1) : Colors.white),
                onPressed: isCurrentMonth ? null : () => setState(() {
                  _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
                }),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["M", "T", "W", "T", "F", "S", "S"].map((d) => SizedBox(
              width: 40.w,
              child: Text(d, textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 10.sp)),
            )).toList(),
          ),
          SizedBox(height: 10.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: daysInMonth + (firstDayOfMonth - 1),
            itemBuilder: (context, index) {
              if (index < firstDayOfMonth - 1) return const SizedBox.shrink();
              
              final day = index - (firstDayOfMonth - 1) + 1;
              final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
              final isSelected = date.year == _selectedHistoryDate.year &&
                  date.month == _selectedHistoryDate.month &&
                  date.day == _selectedHistoryDate.day;
              final hasData = dateSet.contains(date);
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;
              final isFuture = date.isAfter(DateTime.now());

              return GestureDetector(
                onTap: isFuture ? null : () {
                  setState(() {
                    _selectedHistoryDate = date;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blueAccent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected 
                        ? Border.all(color: Colors.blueAccent.withOpacity(0.5))
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        day.toString(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isSelected 
                              ? Colors.white 
                              : (isFuture ? Colors.white.withOpacity(0.05) : (hasData ? Colors.white : Colors.white.withOpacity(0.2))),
                          fontWeight: (isSelected || hasData) ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (hasData && !isSelected)
                        Positioned(
                          bottom: 4.h,
                          child: Container(
                            width: 3.r,
                            height: 3.r,
                            decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCalendar(Set<DateTime> dateSet) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      height: 90.h,
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: PageView.builder(
        controller: _pageController,
        padEnds: false,
        physics: const PageScrollPhysics(),
        itemCount: 365,
        itemBuilder: (context, index) {
          final dateOnly = today.subtract(Duration(days: index));
          
          final isSelected = dateOnly.year == _selectedHistoryDate.year &&
              dateOnly.month == _selectedHistoryDate.month &&
              dateOnly.day == _selectedHistoryDate.day;
          
          final isToday = dateOnly.day == today.day && 
                          dateOnly.month == today.month && 
                          dateOnly.year == today.year;
          
          final hasData = dateSet.contains(dateOnly);

          return GestureDetector(
            onTap: () {
              setState(() => _selectedHistoryDate = dateOnly);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 6.w),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blueAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(12.r),
                border: isToday && !isSelected 
                    ? Border.all(color: Colors.blueAccent.withOpacity(0.5))
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(dateOnly).toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 10.sp,
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.textSecondary : AppColors.textSecondary.withOpacity(0.2)),
                      fontWeight: (isSelected || hasData) ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    dateOnly.day.toString(),
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 16.sp,
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.white : AppColors.white.withOpacity(0.15)),
                    ),
                  ),
                  if (hasData && !isSelected)
                    Container(
                      margin: EdgeInsets.only(top: 4.h),
                      width: 4.r,
                      height: 4.r,
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 16.h),
        width: 40.w,
        height: 4.h,
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : AppColors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? color : AppColors.textSecondary,
          size: 18.r,
        ),
      ),
    );
  }
}