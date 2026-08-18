import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/create_cycle_screen.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/cycle_detail_view_screen.dart';
import 'package:heavy_duty/features/main_wrapper.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/model/cycle_filter.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/widgets/performance_graph.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/workout_list_screen.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/model/exercise_log.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/widgets/cycle_analytical_widget.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'model/training_cycle.dart';
import 'model/workout.dart';

class CycleTrackingScreen extends StatefulWidget {
  final int initialTabIndex;
  const CycleTrackingScreen({super.key, this.initialTabIndex = 0});

  @override
  State<CycleTrackingScreen> createState() => _CycleTrackingScreenState();
}

class _MetricItem {
  final String label;
  final String key;
  final Color color;
  _MetricItem(this.label, this.key, this.color);
}

class _CycleTrackingScreenState extends State<CycleTrackingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isMentzerExpanded = false;
  bool _isCustomExpanded = false;
  CycleFilter _historyFilter = CycleFilter();
  final Set<String> _expandedCycleIds = {}; 
  bool _isBarChart = false;
  int? _comparisonIdx1;
  int? _comparisonIdx2;

  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "cycle";
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    activeSettingsContext.value = "";
    _tabController.dispose();
    super.dispose();
  }

  void _showSystemInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.r),
        ),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.crimson.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: AppColors.crimson,
                size: 28.r,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "CYCLE CONTROLS",
              style: AppTextStyles.h3.copyWith(
                fontSize: 16.sp,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _instructionRow(Icons.bolt_rounded, "Swipe right on library routines to activate them."),
            SizedBox(height: 16.h),
            _instructionRow(Icons.swipe_down_rounded, "Pull down on any list to sync data across devices."),
            SizedBox(height: 16.h),
            _instructionRow(Icons.delete_forever_rounded, "Swipe left on custom cycles to delete them."),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: AppColors.crimson.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.crimson.withOpacity(0.5)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "DISMISS",
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.crimson,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.crimson, size: 20.r),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Future<bool?> _showActivateCycleConfirmation(String cycleName) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.r),
        ),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.greenAccent,
                size: 28,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "ACTIVATE PROTOCOL",
              style: AppTextStyles.h3.copyWith(
                fontSize: 16.sp,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "DO YOU WANT TO INITIALIZE THE '$cycleName' TEMPLATE AS YOUR ACTIVE TRAINING CYCLE?",
              textAlign: TextAlign.center,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.white.withOpacity(0.1)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "CANCEL",
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "ACTIVATE",
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showActivateIncompleteCycleWarning(String currentName, String newName) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.r),
        ),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.crimson.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.crimson,
                size: 28,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "INCOMPLETE CYCLE",
              style: AppTextStyles.h3.copyWith(
                fontSize: 16.sp,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "YOUR CURRENT CYCLE '${currentName.toUpperCase()}' IS NOT YET COMPLETE. ACTIVATING '${newName.toUpperCase()}' WILL MOVE THE INCOMPLETE PROTOCOL TO YOUR LOGS. PROCEED?",
              textAlign: TextAlign.center,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.white.withOpacity(0.1)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "CANCEL",
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: AppColors.crimson.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.crimson.withOpacity(0.5)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "ACTIVATE",
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.crimson,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteCycleConfirmation(String cycleName) async {
    return EliteConfirmDialog.show(
      context,
      title: "DELETE CYCLE",
      message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THE '$cycleName' PROTOCOL FROM YOUR LOGS?",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: null,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.white,
                          ),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              context.go(AppRoutes.tracker);
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            'HIT TRACKER',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h2.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.textSecondary,
                            size: 24.r,
                          ),
                          onPressed: _showSystemInstructions,
                        ),
                      ],
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.crimson,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                  unselectedLabelColor: AppColors.textSecondary,
                  labelColor: AppColors.crimson,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: "LOGS"),
                    Tab(text: "TRENDS"),
                    Tab(text: "LIBRARY"),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecordsTab(),
                _buildTrendsTab(),
                _buildLibraryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsTab() {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final activeCycle = provider.activeCycle;
        final history = provider.cycleHistory;

        return RefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(24.r),
            children: [
              _buildSectionHeader("ACTIVE CYCLE"),
              SizedBox(height: 16.h),
              if (activeCycle != null)
                _buildRecordsSlidableCard(
                  cycle: activeCycle,
                  status: "IN PROGRESS",
                  progression: provider.calculateCycleProgression(activeCycle.id),
                  totalVolume: _calculateTotalCycleVolume(activeCycle, provider.logs),
                  startDate: _getCycleStartDate(activeCycle),
                  endDate: _getCycleEndDate(activeCycle),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            WorkoutListScreen(cycleId: activeCycle.id, cycleName: activeCycle.name),
                      ),
                    );
                  },
                )
              else
                _buildEmptyActiveState(),
              SizedBox(height: 32.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader("CYCLE LOGS"),
                  IconButton(
                    onPressed: _openFilterSheet,
                    icon: Icon(
                      _historyFilter.isInitial 
                          ? Icons.filter_list_rounded 
                          : Icons.filter_list_off_rounded,
                      color: _historyFilter.isInitial ? AppColors.crimson : Colors.orangeAccent,
                      size: 20.r,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: "Filter Logs",
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (history.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Center(
                    child: Text(
                      "NO COMPLETED CYCLES",
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary.withOpacity(0.4)),
                    ),
                  ),
                )
              else ...[
                ...(() {
                  final filteredHistory = history.where((cycle) {
                    if (_historyFilter.selectedCycleNames.isNotEmpty &&
                        !_historyFilter.selectedCycleNames.contains(cycle.name)) {
                      return false;
                    }
                    final startDate = _getCycleStartDate(cycle);
                    if (_historyFilter.dateRange != null) {
                      if (startDate == null) return false;
                      final start = DateTime(startDate.year, startDate.month, startDate.day);
                      final filterStart = DateTime(_historyFilter.dateRange!.start.year, _historyFilter.dateRange!.start.month, _historyFilter.dateRange!.start.day);
                      final filterEnd = DateTime(_historyFilter.dateRange!.end.year, _historyFilter.dateRange!.end.month, _historyFilter.dateRange!.end.day);
                      if (start.isBefore(filterStart) || start.isAfter(filterEnd)) return false;
                    }
                    if (_historyFilter.year != null && (startDate == null || startDate.year != _historyFilter.year)) return false;
                    if (_historyFilter.month != null && (startDate == null || startDate.month != _historyFilter.month)) return false;
                    if (_historyFilter.minStrength != null || _historyFilter.maxStrength != null ||
                        _historyFilter.minVolume != null || _historyFilter.maxVolume != null) {
                      final prog = provider.calculateCycleProgression(cycle.id);
                      final totalVol = _calculateTotalCycleVolume(cycle, provider.logs);
                      if (_historyFilter.minStrength != null && (prog['strength'] ?? 0) * 100 < _historyFilter.minStrength!) return false;
                      if (_historyFilter.maxStrength != null && (prog['strength'] ?? 0) * 100 > _historyFilter.maxStrength!) return false;
                      if (_historyFilter.minVolume != null && totalVol < _historyFilter.minVolume!) return false;
                      if (_historyFilter.maxVolume != null && totalVol > _historyFilter.maxVolume!) return false;
                    }
                    return true;
                  }).toList();

                  final sortedHistory = List<TrainingCycle>.from(filteredHistory);
                  sortedHistory.sort((a, b) {
                    final dateA = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final dateB = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return _historyFilter.isDescending ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
                  });
                  
                  if (sortedHistory.isEmpty) {
                    return [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.h),
                        child: Center(
                          child: Text("NO CYCLES MATCHING FILTERS", style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary.withOpacity(0.4))),
                        ),
                      )
                    ];
                  }

                  return sortedHistory.map((cycle) {
                    final totalWorkouts = cycle.workouts.length;
                    final completedWorkouts = cycle.workouts.where((w) => w.status == WorkoutStatus.completed).length;
                    final bool isActuallyFinished = totalWorkouts > 0 && completedWorkouts == totalWorkouts;

                    return _buildRecordsSlidableCard(
                      cycle: cycle,
                      status: isActuallyFinished ? "FINISHED" : "INCOMPLETE",
                      progression: provider.calculateCycleProgression(cycle.id),
                      totalVolume: _calculateTotalCycleVolume(cycle, provider.logs),
                      startDate: _getCycleStartDate(cycle),
                      endDate: _getCycleEndDate(cycle),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => WorkoutListScreen(cycleId: cycle.id, cycleName: cycle.name)),
                        );
                      },
                    );
                  });
                })(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyActiveState() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.radio_button_off, color: AppColors.textSecondary, size: 40.r),
          SizedBox(height: 16.h),
          Text("NO ACTIVE CYCLE DETECTED", style: AppTextStyles.labelMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.w400)),
          SizedBox(height: 8.h),
          Text("SYSTEM REQUIRES AN ACTIVE ROUTINE TO TRACK PROGRESSION.", textAlign: TextAlign.center, style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
          SizedBox(height: 20.h),
          GestureDetector(
            onTap: () => _tabController.animateTo(2),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r), border: Border.all(color: AppColors.crimson)),
              child: Text("GO TO LIBRARY", style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson, fontWeight: FontWeight.w400)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final List<TrainingCycle> cycles = provider.cycles.where((c) => c.status == CycleStatus.finished).toList();
        
        if (cycles.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.forceRefresh(),
            color: AppColors.crimson,
            backgroundColor: AppColors.surface,
            child: LayoutBuilder(
            builder: (context, constraints) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Text(
                      "COMPLETE CYCLES TO VIEW TRENDS",
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary.withOpacity(0.3),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          );
        }

        final sortedCycles = List<TrainingCycle>.from(cycles)
          ..sort((a, b) => (a.startedAt ?? DateTime.now()).compareTo(b.startedAt ?? DateTime.now()));
        
        final List<DateTime> sortedDates = sortedCycles.map((c) => _getCycleEndDate(c) ?? c.startedAt ?? DateTime.now()).toList();

        final Map<String, List<double?>> aggregatedData = {
          "strength": sortedCycles.map((c) => _calculateCycleAbsoluteStrength(c, provider.logs)).toList(),
          "volume": sortedCycles.map((c) => _calculateTotalCycleVolume(c, provider.logs)).toList(),
        };

        final Map<String, MetricMetadata> metadata = {
          "strength": MetricMetadata(label: "STRENGTH", unit: _getStrengthUnit(), color: AppColors.crimson),
          "volume": MetricMetadata(label: "VOLUME", unit: _getVolumeUnit(provider), color: Colors.orangeAccent),
        };

        return RefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.all(24.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("ANALYTICS & TRENDS"),
                SizedBox(height: 24.h),
                CycleAnalyticalGraph(
                  dates: sortedDates,
                  data: aggregatedData,
                  visibleMetrics: provider.visibleMetrics,
                  onPointSelected: (idx) {},
                ),
                if (cycles.isNotEmpty) ...[
                  SizedBox(height: 32.h),
                  _buildSectionHeader("METRIC OVERLAY"),
                  SizedBox(height: 16.h),
                  Wrap(
                    spacing: 10.w,
                    runSpacing: 10.h,
                    children: [
                      _buildMetricToggle("STRENGTH", "strength", AppColors.crimson, provider),
                      _buildMetricToggle("VOLUME", "volume", Colors.orangeAccent, provider),
                    ],
                  ),
                  SizedBox(height: 40.h),
                  _buildSectionHeader("DATA COMPARISON"),
                  SizedBox(height: 16.h),
                  _buildDataComparisonWidget(
                    sortedCycles.map((c) => c.name).toList(),
                    sortedDates,
                    aggregatedData,
                    metadata,
                    provider,
                  ),
                ],
                SizedBox(height: 40.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricToggle(String label, String key, Color color, CycleProvider provider) {
    final bool isActive = provider.visibleMetrics.contains(key);
    return GestureDetector(
      onTap: () {
        final current = Set<String>.from(provider.visibleMetrics);
        if (isActive) {
          current.remove(key);
        } else {
          current.add(key);
        }
        provider.setVisibleMetrics(current);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isActive ? color : AppColors.white.withOpacity(0.05),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8.r,
              height: 8.r,
              decoration: BoxDecoration(
                color: isActive ? color : AppColors.textSecondary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isActive ? AppColors.white : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryTab() {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final templates = provider.libraryTemplates;
        final mentzerTemplates = templates.where((t) => t.isDefault).toList();
        final customTemplates = templates.where((t) => !t.isDefault).toList();
        final visibleMentzer = _isMentzerExpanded ? mentzerTemplates : mentzerTemplates.take(2).toList();
        final visibleCustom = _isCustomExpanded ? customTemplates : customTemplates.take(2).toList();
        return RefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(24.r),
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.fastOutSlowIn,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildSectionHeader("MENTZER DEFAULTS"), if (mentzerTemplates.length > 2) _buildShowMoreToggle(isExpanded: _isMentzerExpanded, onTap: () => setState(() => _isMentzerExpanded = !_isMentzerExpanded))]),
                    SizedBox(height: 16.h),
                    ...visibleMentzer.map((t) => _buildLibrarySlidableCard(cycle: t, status: "DEFAULT", isDefaultTemplate: true, onTap: () async { final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => CycleDetailViewScreen(cycleId: t.id, cycleName: t.name, isModifiable: false))); if (result == true && mounted) _tabController.animateTo(0); })),
                  ],
                ),
              ),
              SizedBox(height: 32.h),
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.fastOutSlowIn,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildSectionHeader("CUSTOM CYCLES"), if (customTemplates.length > 2) _buildShowMoreToggle(isExpanded: _isCustomExpanded, onTap: () => setState(() => _isCustomExpanded = !_isCustomExpanded))]),
                    SizedBox(height: 16.h),
                    _buildAddCycleButton(),
                    SizedBox(height: 16.h),
                    ...visibleCustom.map((t) => _buildLibrarySlidableCard(
                          cycle: t,
                          status: "CUSTOM",
                          isDefaultTemplate: false,
                          onTap: () async {
                            final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => CycleDetailViewScreen(
                                        cycleId: t.id,
                                        cycleName: t.name,
                                        isModifiable: true)));
                            if (result == true && mounted) _tabController.animateTo(0);
                          },
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShowMoreToggle({required bool isExpanded, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isExpanded ? "SHOW LESS" : "SHOW MORE", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.4), fontWeight: FontWeight.w400, fontSize: 9.sp, letterSpacing: 1.5)),
          SizedBox(width: 4.w),
          Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary.withOpacity(0.4), size: 16.r),
        ],
      ),
    );
  }

  Widget _buildLibrarySlidableCard({required TrainingCycle cycle, required String status, required bool isDefaultTemplate, VoidCallback? onTap}) {
    return Dismissible(
      key: Key(cycle.id + status),
      direction: isDefaultTemplate ? DismissDirection.endToStart : DismissDirection.horizontal,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd && !isDefaultTemplate) return await _showDeleteCycleConfirmation(cycle.name);
        if (dir == DismissDirection.endToStart) {
          final provider = context.read<CycleProvider>();
          final active = provider.activeCycle;
          
          bool activated = false;
          if (active != null) {
            if (!active.isReadyToFinish) {
              final result = await _showActivateIncompleteCycleWarning(active.name, cycle.name);
              activated = result ?? false;
            } else {
              final result = await _showActivateCycleConfirmation(cycle.name);
              activated = result ?? false;
            }
          } else {
            final result = await _showActivateCycleConfirmation(cycle.name);
            activated = result ?? false;
          }

          if (activated) { 
            await provider.activateCycle(cycle.id); 
            if (mounted) { 
              EliteSnackbar.show(context, "Cycle '${cycle.name}' Activated"); 
              _tabController.animateTo(0); 
            } 
          }
          return false;
        }
        return false;
      },
      onDismissed: (dir) { if (dir == DismissDirection.startToEnd) context.read<CycleProvider>().deleteCycle(cycle.id); },
      background: !isDefaultTemplate ? Container(alignment: Alignment.centerLeft, padding: EdgeInsets.only(left: 24.w), margin: EdgeInsets.only(bottom: 20.h), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24.r)), child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28)) : const SizedBox.shrink(),
      secondaryBackground: Container(alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 24.w), margin: EdgeInsets.only(bottom: 20.h), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24.r)), child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28)),
      child: _buildStandardCycleCard(cycle: cycle, status: status, onTap: onTap),
    );
  }

  Widget _buildRecordsSlidableCard({required TrainingCycle cycle, required String status, Map<String, double>? progression, double? totalVolume, DateTime? startDate, DateTime? endDate, VoidCallback? onTap}) {
    return Dismissible(
      key: Key(cycle.id + status),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (dir) async => await _showDeleteCycleConfirmation(cycle.name),
      onDismissed: (dir) { context.read<CycleProvider>().deleteCycle(cycle.id); },
      background: Container(alignment: Alignment.centerLeft, padding: EdgeInsets.only(left: 24.w), margin: EdgeInsets.only(bottom: 20.h), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24.r)), child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28)),
      child: _buildStandardCycleCard(cycle: cycle, status: status, progression: progression, totalVolume: totalVolume, startDate: startDate, endDate: endDate, onTap: onTap),
    );
  }

  Widget _buildStandardCycleCard({required TrainingCycle cycle, required String status, Map<String, double>? progression, double? totalVolume, DateTime? startDate, DateTime? endDate, VoidCallback? onTap}) {
    final bool isExpanded = _expandedCycleIds.contains(cycle.id);
    final bool isActive = status == "ACTIVE" || status == "IN PROGRESS";
    final bool isFinished = status == "FINISHED";
    final bool isIncomplete = status.toUpperCase() == "INCOMPLETE";
    final double strength = progression?['strength'] ?? 0.0;
    final double volumeProg = progression?['volume'] ?? 0.0;
    final bool hasProgression = strength != 0 || volumeProg != 0;
    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24.r), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24.r),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.all(24.r),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [if (isActive) Container(width: 10.r, height: 10.r, margin: EdgeInsets.only(right: 12.w), decoration: const BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle)), Expanded(child: Text(cycle.name.toUpperCase(), style: AppTextStyles.h3.copyWith(fontSize: 18.sp, letterSpacing: 1.2, color: AppColors.white, fontWeight: FontWeight.w500)))]),
                            SizedBox(height: 8.h),
                            Text(
                              cycle.description.toUpperCase(),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary.withOpacity(0.4),
                                fontSize: 11.sp,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            if (cycle.sharedBy != null) ...[
                              SizedBox(height: 8.h),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.share_rounded, color: Colors.blueAccent, size: 12.r),
                                    SizedBox(width: 6.w),
                                    Text(
                                      "SHARED BY ${cycle.sharedBy!.toUpperCase()}",
                                      style: AppTextStyles.labelSmall.copyWith(
                                        fontSize: 9.sp,
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: (isActive ? AppColors.crimson : isFinished ? AppColors.success : isIncomplete ? Colors.orangeAccent : AppColors.surfaceLight).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(color: (isActive ? AppColors.crimson : isFinished ? AppColors.success : isIncomplete ? Colors.orangeAccent : AppColors.white.withOpacity(0.1)).withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    status,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      fontSize: 9.sp,
                                      color: isActive ? AppColors.crimson : isFinished ? AppColors.success : isIncomplete ? Colors.orangeAccent : AppColors.white,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (hasProgression && strength != 0) ...[
                        SizedBox(width: 16.w),
                        Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Text("STRENGTH", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.3), fontSize: 8.sp, fontWeight: FontWeight.w900, letterSpacing: 1)), Text("${strength > 0 ? '+' : ''}${(strength * 100).toStringAsFixed(1)}%", style: AppTextStyles.h2.copyWith(color: strength > 0 ? AppColors.success : Colors.redAccent, fontSize: 24.sp, fontWeight: FontWeight.w900))]),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasProgression || (totalVolume != null && totalVolume > 0) || startDate != null) ...[
            Padding(padding: EdgeInsets.symmetric(horizontal: 24.w), child: Divider(color: AppColors.white.withOpacity(0.05), height: 1)),
            GestureDetector(onTap: () => setState(() { if (isExpanded) {
              _expandedCycleIds.remove(cycle.id);
            } else {
              _expandedCycleIds.add(cycle.id);
            } }), child: Container(width: double.infinity, padding: EdgeInsets.symmetric(vertical: 12.h), color: Colors.transparent, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(isExpanded ? "COLLAPSE DATA" : "SHOW PERFORMANCE DATA", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.4), fontSize: 9.sp, letterSpacing: 2, fontWeight: FontWeight.w500)), SizedBox(width: 8.w), AnimatedRotation(turns: isExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 300), child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary.withOpacity(0.4), size: 16.r))]))),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              alignment: Alignment.topCenter,
              child: isExpanded ? Container(padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h), child: Container(padding: EdgeInsets.all(20.r), decoration: BoxDecoration(color: AppColors.surfaceLight.withOpacity(0.3), borderRadius: BorderRadius.circular(16.r)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (volumeProg != 0) ...[Text("TONNAGE CHANGE", style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontSize: 9.sp, fontWeight: FontWeight.w500, letterSpacing: 1)), SizedBox(height: 8.h), Text("${volumeProg > 0 ? '+' : ''}${(volumeProg * 100).toStringAsFixed(1)}%", style: AppTextStyles.labelMedium.copyWith(color: volumeProg > 0 ? AppColors.success : AppColors.crimson, fontWeight: FontWeight.w900, fontSize: 18.sp)), if (totalVolume != null && totalVolume > 0) SizedBox(height: 12.h)], if (totalVolume != null && totalVolume > 0) ...[Text("TOTAL TONNAGE", style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontSize: 9.sp, fontWeight: FontWeight.w500, letterSpacing: 1)), SizedBox(height: 4.h), Text("${totalVolume.toStringAsFixed(1)} T", style: AppTextStyles.labelMedium.copyWith(color: AppColors.white.withOpacity(0.9), fontWeight: FontWeight.w900, fontSize: 16.sp))]]) , if (startDate != null) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [_dateRow("STARTED", startDate), SizedBox(height: 8.h), _dateRow("ENDED", endDate ?? startDate)])]))) : const SizedBox(width: double.infinity, height: 0),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddCycleButton() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCycleScreen()));
        if (result == true && mounted) _tabController.animateTo(0);
      },
      child: Container(
        height: 56.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.crimson.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.crimson, width: 1.5),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: AppColors.crimson, size: 20.r),
              SizedBox(width: 8.w),
              Text(
                'CREATE CUSTOM CYCLE',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.crimson,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateRow(String label, DateTime date) { return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.4), fontSize: 7.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)), Text(DateFormat('MMM dd, yyyy').format(date).toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontSize: 10.sp, fontWeight: FontWeight.w500))]); }
  DateTime? _getCycleStartDate(TrainingCycle cycle) { final completed = cycle.workouts.where((w) => w.status == WorkoutStatus.completed && w.completedAt != null).toList(); if (completed.isEmpty) return null; completed.sort((a, b) => a.completedAt!.compareTo(b.completedAt!)); return completed.first.completedAt; }
  DateTime? _getCycleEndDate(TrainingCycle cycle) { final completed = cycle.workouts.where((w) => w.status == WorkoutStatus.completed && w.completedAt != null).toList(); if (completed.isEmpty) return null; completed.sort((a, b) => a.completedAt!.compareTo(b.completedAt!)); return completed.last.completedAt; }
  double _calculateTotalCycleVolume(TrainingCycle cycle, List<ExerciseLog> logs) { double total = 0; final exerciseIds = cycle.workouts.expand((w) => w.exercises.map((e) => e.id)).toSet(); final cycleLogs = logs.where((l) => exerciseIds.contains(l.exerciseId)).toList(); for (var log in cycleLogs) { total += log.weightKg * log.positiveReps; } return total; }

  double _calculateCycleAbsoluteStrength(TrainingCycle cycle, List<ExerciseLog> logs) {
    double totalStrength = 0;
    int count = 0;
    for (var workout in cycle.workouts) {
      for (var exercise in workout.exercises) {
        final exLogs = logs.where((l) => l.exerciseId == exercise.id).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        if (exLogs.isNotEmpty) {
          final l = exLogs.first;
          if (l.weightKg > 0 && l.positiveReps > 0) {
            totalStrength += l.weightKg / (1.0278 - (0.0278 * l.positiveReps));
            count++;
          }
        }
      }
    }
    return count > 0 ? totalStrength : 0.0;
  }

  Widget _buildSectionHeader(String title) { return Row(children: [Container(width: 2.5.w, height: 12.h, decoration: BoxDecoration(color: AppColors.crimson, borderRadius: BorderRadius.circular(2.r))), SizedBox(width: 8.w), Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 12.sp))]); }

  String _getVolumeUnit(CycleProvider provider) {
    return "TONNAGE";
  }

  String _getStrengthUnit() {
    return "%";
  }

  void _openFilterSheet() {
    final provider = context.read<CycleProvider>();
    final history = provider.cycleHistory;
    final uniqueNames = history.map((c) => c.name).toSet().toList()..sort();
    final uniqueYears = history.map((c) => _getCycleStartDate(c)?.year).whereType<int>().toSet().toList()..sort((a, b) => b.compareTo(a));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CycleFilterSheet(initialFilter: _historyFilter, uniqueNames: uniqueNames, uniqueYears: uniqueYears, onApply: (newFilter) { setState(() { _historyFilter = newFilter; }); }),
    );
  }

  Widget _buildDataComparisonWidget(
    List<String> labels,
    List<DateTime> dates,
    Map<String, List<double?>> data,
    Map<String, MetricMetadata> metadata,
    CycleProvider cycleProv,
  ) {
    if (_comparisonIdx1 != null && _comparisonIdx1! >= labels.length) _comparisonIdx1 = null;
    if (_comparisonIdx2 != null && _comparisonIdx2! >= labels.length) _comparisonIdx2 = null;
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(32.r), border: Border.all(color: AppColors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildComparisonHeader("POINT A", _comparisonIdx1, (val) => setState(() => _comparisonIdx1 = val), labels, dates),
              Padding(padding: EdgeInsets.only(top: 40.h), child: Icon(Icons.compare_arrows_rounded, color: AppColors.crimson.withOpacity(0.2), size: 24.r)),
              _buildComparisonHeader("POINT B", _comparisonIdx2, (val) => setState(() => _comparisonIdx2 = val), labels, dates),
            ],
          ),
          SizedBox(height: 24.h),
          if (_comparisonIdx1 == null && _comparisonIdx2 == null) Center(child: Text("SELECT DATA POINTS TO ANALYZE", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.3), letterSpacing: 1)))
          else if (_comparisonIdx1 != null && _comparisonIdx2 == null) _buildSinglePointView(_comparisonIdx1!, data, metadata)
          else if (_comparisonIdx1 == null && _comparisonIdx2 != null) _buildSinglePointView(_comparisonIdx2!, data, metadata)
          else _buildComparisonView(_comparisonIdx1!, _comparisonIdx2!, dates, data, metadata),
        ],
      ),
    );
  }

  Widget _buildComparisonHeader(String title, int? selectedIdx, Function(int?) onChanged, List<String> fullLabels, List<DateTime> dates) {
    final bool isPointB = title == "POINT B";
    return Expanded(
      child: Column(
        crossAxisAlignment: isPointB ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isPointB ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (selectedIdx != null && isPointB) ...[GestureDetector(onTap: () => onChanged(null), child: Container(padding: EdgeInsets.all(4.r), decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.close_rounded, color: AppColors.crimson, size: 10.r))), SizedBox(width: 8.w)],
              Text(title, style: AppTextStyles.labelSmall.copyWith(color: selectedIdx != null ? AppColors.crimson : AppColors.textSecondary.withOpacity(0.4), fontSize: 9.sp, fontWeight: FontWeight.w900, letterSpacing: 2)),
              if (selectedIdx != null && !isPointB) ...[SizedBox(width: 8.w), GestureDetector(onTap: () => onChanged(null), child: Container(padding: EdgeInsets.all(4.r), decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.close_rounded, color: AppColors.crimson, size: 10.r)))],
            ],
          ),
          SizedBox(height: 12.h),
          GestureDetector(
            onTap: fullLabels.isEmpty ? null : () => _showPointPicker(context: context, currentIndex: selectedIdx, fullLabels: fullLabels, dates: dates, onChanged: onChanged),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(color: selectedIdx != null ? AppColors.crimson.withOpacity(0.05) : AppColors.surfaceLight.withOpacity(0.3), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: selectedIdx != null ? AppColors.crimson.withOpacity(0.4) : AppColors.white.withOpacity(0.05), width: 1.5)),
              child: Opacity(
                opacity: fullLabels.isEmpty ? 0.3 : 1.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(selectedIdx != null ? Icons.event_available_rounded : Icons.event_note_rounded, color: selectedIdx != null ? AppColors.crimson : AppColors.textSecondary.withOpacity(0.3), size: 16.r),
                    SizedBox(width: 10.w),
                    Flexible(child: Text(selectedIdx != null ? fullLabels[selectedIdx] : "SET POINT", overflow: TextOverflow.ellipsis, style: AppTextStyles.labelSmall.copyWith(color: selectedIdx != null ? AppColors.white : AppColors.textSecondary.withOpacity(0.4), fontSize: 10.sp, fontWeight: selectedIdx != null ? FontWeight.bold : FontWeight.normal))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPointPicker({
    required BuildContext context,
    required int? currentIndex,
    required List<String> fullLabels,
    required List<DateTime> dates,
    required Function(int?) onChanged,
  }) async {
    final Map<DateTime, List<int>> daysMap = {};
    for (int i = 0; i < dates.length; i++) {
      final day = DateTime(dates[i].year, dates[i].month, dates[i].day);
      daysMap.putIfAbsent(day, () => []).add(i);
    }
    final DateTime? pickedDay = await showDatePicker(
      context: context,
      initialDate: currentIndex != null ? dates[currentIndex] : dates.last,
      firstDate: dates.first,
      lastDate: dates.last,
      selectableDayPredicate: (date) => daysMap.containsKey(DateTime(date.year, date.month, date.day)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(primary: AppColors.crimson, onPrimary: Colors.white, surface: AppColors.surface, onSurface: Colors.white),
            dialogBackgroundColor: AppColors.surface,
          ),
          child: child!,
        );
      },
    );
    if (pickedDay == null) return;
    if (!context.mounted) return;
    final List<int> indicesForDay = daysMap[DateTime(pickedDay.year, pickedDay.month, pickedDay.day)]!;
    if (indicesForDay.length == 1) {
      onChanged(indicesForDay.first);
    } else {
      final int? selectedIdx = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28.r))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("SELECT LOG TIME", style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson, letterSpacing: 1.2)),
              SizedBox(height: 20.h),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 300.h),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: indicesForDay.length,
                  separatorBuilder: (context, index) => Divider(color: AppColors.white.withOpacity(0.05)),
                  itemBuilder: (context, index) {
                    final idx = indicesForDay[index];
                    final bool isSelected = idx == currentIndex;
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
                      title: Text(fullLabels[idx], style: AppTextStyles.labelSmall.copyWith(color: isSelected ? AppColors.crimson : AppColors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppColors.crimson, size: 20.r) : null,
                      onTap: () => Navigator.pop(context, idx),
                    );
                  },
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      );
      if (selectedIdx != null) onChanged(selectedIdx);
    }
  }

  Widget _buildSinglePointView(int idx, Map<String, List<double?>> data, Map<String, MetricMetadata> metadata) {
    final activeMetrics = data.keys.where((k) => data[k]![idx] != null).toList();
    return Column(
      children: activeMetrics.map((k) {
        final meta = metadata[k]!;
        final val = data[k]![idx]!;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Container(width: 4.w, height: 16.h, decoration: BoxDecoration(color: meta.color, borderRadius: BorderRadius.circular(2.r))), SizedBox(width: 12.w), Text(meta.label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold))]), Text("${val.toStringAsFixed(1)} ${meta.unit}", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary))]),
        );
      }).toList(),
    );
  }

  Widget _buildComparisonView(int idx1, int idx2, List<DateTime> dates, Map<String, List<double?>> data, Map<String, MetricMetadata> metadata) {
    final commonMetrics = data.keys.where((k) => data[k]![idx1] != null && data[k]![idx2] != null).toList();
    final duration = dates[idx2].difference(dates[idx1]).abs();
    final days = duration.inDays;
    final hrs = duration.inHours % 24;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h), decoration: BoxDecoration(color: AppColors.surfaceLight.withOpacity(0.5), borderRadius: BorderRadius.circular(8.r)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.timer_outlined, color: AppColors.crimson, size: 14.r), SizedBox(width: 8.w), Text("INTERVAL: ${days > 0 ? '${days}D ' : ''}${hrs}H", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 9.sp, fontWeight: FontWeight.bold))])),
        SizedBox(height: 16.h),
        if (commonMetrics.isEmpty) Center(child: Text("NO OVERLAPPING METRICS FOUND", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)))
        else ...commonMetrics.map((k) {
            final meta = metadata[k]!;
            final v1 = data[k]![idx1]!;
            final v2 = data[k]![idx2]!;
            final delta = v2 - v1;
            final percent = v1 != 0 ? (delta / v1.abs()) * 100 : 0.0;
            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(color: AppColors.surfaceLight.withOpacity(0.3), borderRadius: BorderRadius.circular(12.r)),
              child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(meta.label, style: AppTextStyles.labelSmall.copyWith(color: meta.color, fontWeight: FontWeight.bold, letterSpacing: 1)), Row(children: [Icon(delta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: delta >= 0 ? AppColors.success : AppColors.crimson, size: 14.r), SizedBox(width: 4.w), Text("${delta >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%", style: AppTextStyles.labelSmall.copyWith(color: delta >= 0 ? Colors.greenAccent : AppColors.crimson, fontWeight: FontWeight.bold))])]), SizedBox(height: 12.h), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildCompValue("A", v1, meta.unit), Container(width: 1.w, height: 20.h, color: AppColors.white.withOpacity(0.05)), _buildCompValue("B", v2, meta.unit), Container(width: 1.w, height: 20.h, color: AppColors.white.withOpacity(0.05)), _buildCompValue("Δ", delta, meta.unit, isDelta: true)])]),
            );
        }),
      ],
    );
  }

  Widget _buildCompValue(String label, double val, String unit, {bool isDelta = false}) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.3), fontSize: 7.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 2.h),
        Text(
          "${isDelta && val > 0 ? '+' : ''}${val.toStringAsFixed(1)}",
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 11.sp),
        ),
        Text(unit.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 6.sp)),
      ],
    );
  }

  Widget _buildHandle() { return Center(child: Container(margin: EdgeInsets.symmetric(vertical: 16.h), width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.2), borderRadius: BorderRadius.circular(2.r)))); }
}

enum _DateFilterType { all, range, monthYear }

class _CycleFilterSheet extends StatefulWidget {
  final CycleFilter initialFilter;
  final List<String> uniqueNames;
  final List<int> uniqueYears;
  final Function(CycleFilter) onApply;

  const _CycleFilterSheet({required this.initialFilter, required this.uniqueNames, required this.uniqueYears, required this.onApply});
  @override
  State<_CycleFilterSheet> createState() => _CycleFilterSheetState();
}

class _CycleFilterSheetState extends State<_CycleFilterSheet> {
  late CycleFilter _currentFilter;
  _DateFilterType _dateFilterType = _DateFilterType.all;
  final TextEditingController _minStrengthController = TextEditingController();
  final TextEditingController _maxStrengthController = TextEditingController();
  final TextEditingController _minVolumeController = TextEditingController();
  final TextEditingController _maxVolumeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    if (_currentFilter.dateRange != null) { _dateFilterType = _DateFilterType.range; } 
    else if (_currentFilter.year != null) { _dateFilterType = _DateFilterType.monthYear; }
    _minStrengthController.text = _currentFilter.minStrength?.toString() ?? "";
    _maxStrengthController.text = _currentFilter.maxStrength?.toString() ?? "";
    _minVolumeController.text = _currentFilter.minVolume?.toString() ?? "";
    _maxVolumeController.text = _currentFilter.maxVolume?.toString() ?? "";
  }

  @override
  void dispose() {
    _minStrengthController.dispose();
    _maxStrengthController.dispose();
    _minVolumeController.dispose();
    _maxVolumeController.dispose();
    super.dispose();
  }

  void _updateFilter(CycleFilter newFilter) { setState(() { _currentFilter = newFilter; }); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 24.w, right: 24.w, bottom: MediaQuery.of(context).viewInsets.bottom + 24.h),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)), border: Border.all(color: AppColors.white.withOpacity(0.05))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("LOG FILTERS", style: AppTextStyles.h3.copyWith(color: AppColors.white)), TextButton(onPressed: () { setState(() { _currentFilter = CycleFilter(); _dateFilterType = _DateFilterType.all; _minStrengthController.clear(); _maxStrengthController.clear(); _minVolumeController.clear(); _maxVolumeController.clear(); }); }, child: Text("RESET", style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontWeight: FontWeight.bold)))]),
          SizedBox(height: 24.h),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel("SORT ORDER"),
                  Row(children: [_buildToggleButton(label: "NEWEST FIRST", isSelected: _currentFilter.isDescending, onTap: () => _updateFilter(_currentFilter.copyWith(isDescending: true))), SizedBox(width: 12.w), _buildToggleButton(label: "OLDEST FIRST", isSelected: !_currentFilter.isDescending, onTap: () => _updateFilter(_currentFilter.copyWith(isDescending: false)))]),
                  SizedBox(height: 24.h),
                  _buildSectionLabel("DATE FILTER"),
                  Row(children: [_buildToggleButton(label: "ALL", isSelected: _dateFilterType == _DateFilterType.all, onTap: () { setState(() => _dateFilterType = _DateFilterType.all); _updateFilter(_currentFilter.copyWith(dateRange: null, year: null, month: null)); }), SizedBox(width: 8.w), _buildToggleButton(label: "MONTH/YEAR", isSelected: _dateFilterType == _DateFilterType.monthYear, onTap: () { setState(() => _dateFilterType = _DateFilterType.monthYear); _updateFilter(_currentFilter.copyWith(dateRange: null)); }), SizedBox(width: 8.w), _buildToggleButton(label: "CUSTOM RANGE", isSelected: _dateFilterType == _DateFilterType.range, onTap: () { setState(() => _dateFilterType = _DateFilterType.range); _updateFilter(_currentFilter.copyWith(year: null, month: null)); })]),
                  if (_dateFilterType == _DateFilterType.range) ...[
                    SizedBox(height: 16.h),
                    GestureDetector(onTap: () async { final range = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDateRange: _currentFilter.dateRange, builder: (context, child) { return Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.crimson, onPrimary: Colors.white, surface: AppColors.surface, onSurface: Colors.white)), child: child!); }); if (range != null) { _updateFilter(_currentFilter.copyWith(dateRange: range)); } }, child: Container(padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h), decoration: BoxDecoration(color: AppColors.surfaceLight.withOpacity(0.3), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.white.withOpacity(0.05))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_currentFilter.dateRange == null ? "SELECT DATE RANGE" : "${DateFormat('MMM dd').format(_currentFilter.dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_currentFilter.dateRange!.end)}", style: AppTextStyles.labelSmall.copyWith(color: _currentFilter.dateRange == null ? AppColors.textMuted : AppColors.white)), Icon(Icons.calendar_today_rounded, color: AppColors.crimson, size: 16.r)]))),
                  ] else if (_dateFilterType == _DateFilterType.monthYear) ...[
                    SizedBox(height: 16.h),
                    Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildSectionLabel("YEAR"), _buildDropdown<int?>(value: _currentFilter.year, items: [const DropdownMenuItem(value: null, child: Text("ALL")), ...widget.uniqueYears.map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))], onChanged: (val) => _updateFilter(_currentFilter.copyWith(year: val, month: val == null ? null : _currentFilter.month)))])) , SizedBox(width: 16.w), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildSectionLabel("MONTH"), _buildDropdown<int?>(value: _currentFilter.month, items: [const DropdownMenuItem(value: null, child: Text("ALL")), ...List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMMM').format(DateTime(2024, i + 1)).toUpperCase())))], onChanged: _currentFilter.year == null ? null : (val) => _updateFilter(_currentFilter.copyWith(month: val)))]))]),
                  ],
                  SizedBox(height: 24.h),
                  _buildSectionLabel("CYCLE NAMES"),
                  Wrap(spacing: 8.w, runSpacing: 8.h, children: widget.uniqueNames.map((name) { final isSelected = _currentFilter.selectedCycleNames.contains(name); return GestureDetector(onTap: () { final names = Set<String>.from(_currentFilter.selectedCycleNames); if (isSelected) { names.remove(name); } else { names.add(name); } _updateFilter(_currentFilter.copyWith(selectedCycleNames: names)); }, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h), decoration: BoxDecoration(color: isSelected ? AppColors.crimson.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8.r), border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withOpacity(0.1))), child: Text(name.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: isSelected ? AppColors.crimson : AppColors.textSecondary, fontSize: 10.sp, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)))); }).toList()),
                  SizedBox(height: 24.h),
                  _buildSectionLabel("STRENGTH PROGRESSION (%)"),
                  Row(children: [Expanded(child: _buildTextField(_minStrengthController, "MIN", (val) => _updateFilter(_currentFilter.copyWith(minStrength: double.tryParse(val))))), SizedBox(width: 16.w), Expanded(child: _buildTextField(_maxStrengthController, "MAX", (val) => _updateFilter(_currentFilter.copyWith(maxStrength: double.tryParse(val)))))],),
                  SizedBox(height: 24.h),
                  _buildSectionLabel("TOTAL TONNAGE"),
                  Row(children: [Expanded(child: _buildTextField(_minVolumeController, "MIN", (val) => _updateFilter(_currentFilter.copyWith(minVolume: double.tryParse(val))))), SizedBox(width: 16.w), Expanded(child: _buildTextField(_maxVolumeController, "MAX", (val) => _updateFilter(_currentFilter.copyWith(maxVolume: double.tryParse(val)))))],),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { widget.onApply(_currentFilter); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson, padding: EdgeInsets.symmetric(vertical: 16.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))), child: Text("APPLY FILTERS", style: AppTextStyles.buttonPrimary.copyWith(color: Colors.white)))),
        ],
      ),
    );
  }

  Widget _buildHandle() { return Center(child: Container(margin: EdgeInsets.symmetric(vertical: 16.h), width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.2), borderRadius: BorderRadius.circular(2.r)))); }
  Widget _buildSectionLabel(String label) { return Padding(padding: EdgeInsets.only(bottom: 12.h), child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted, letterSpacing: 1.5, fontWeight: FontWeight.w900))); }
  Widget _buildToggleButton({required String label, required bool isSelected, required VoidCallback onTap}) { return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: EdgeInsets.symmetric(vertical: 12.h), decoration: BoxDecoration(color: isSelected ? AppColors.crimson.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withOpacity(0.1))), child: Center(child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: isSelected ? AppColors.crimson : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)))))); }
  Widget _buildDropdown<T>({required T value, required List<DropdownMenuItem<T>> items, required void Function(T?)? onChanged}) { return Container(padding: EdgeInsets.symmetric(horizontal: 16.w), decoration: BoxDecoration(color: AppColors.surfaceLight.withOpacity(0.3), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.white.withOpacity(0.05))), child: DropdownButtonHideUnderline(child: DropdownButton<T>(value: value, items: items, onChanged: onChanged, dropdownColor: AppColors.surface, icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.crimson), isExpanded: true, style: AppTextStyles.labelSmall.copyWith(color: AppColors.white)))); }
  Widget _buildTextField(TextEditingController controller, String hint, Function(String) onChanged) { return Container(decoration: BoxDecoration(color: AppColors.surfaceLight.withOpacity(0.3), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.white.withOpacity(0.05))), child: TextField(controller: controller, onChanged: onChanged, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: AppTextStyles.labelSmall.copyWith(color: AppColors.white), decoration: InputDecoration(hintText: hint, hintStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h)))); }
}
