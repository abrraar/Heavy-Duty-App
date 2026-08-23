import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../tracker/cycle_tracker/model/exercise_log.dart';

class ExerciseAnalyticalGraph extends StatefulWidget {
  final List<ExerciseLog> logs;
  final Function(int) onPointSelected;

  const ExerciseAnalyticalGraph({
    super.key,
    required this.logs,
    required this.onPointSelected,
  });

  @override
  State<ExerciseAnalyticalGraph> createState() => _ExerciseAnalyticalGraphState();
}

class _ExerciseAnalyticalGraphState extends State<ExerciseAnalyticalGraph> {
  late PageController _pageController;
  int _currentIndex = 0;
  
  final Set<String> _visibleMetrics = {"weight", "pos", "neg", "hold", "forced"};
  int? _comparisonIdx1;
  int? _comparisonIdx2;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.logs.isEmpty ? 0 : widget.logs.length - 1;
    _pageController = PageController(
      initialPage: _currentIndex,
      viewportFraction: 0.28, // Clumped closer together for denser panoramic view
    );
  }

  @override
  void didUpdateWidget(ExerciseAnalyticalGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs.length != oldWidget.logs.length && widget.logs.isNotEmpty) {
       _currentIndex = widget.logs.length - 1;
       _pageController.jumpToPage(_currentIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.logs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // ─── THE COMMAND GRAPH (Denser Snapping Workstation) ───────────────
        SizedBox(
          height: 180.h, 
          child: Stack(
            children: [
              _buildGlobalGrid(),

              PageView.builder(
                controller: _pageController,
                itemCount: widget.logs.length,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  widget.onPointSelected(index);
                },
                itemBuilder: (context, index) {
                  final bool isFocused = index == _currentIndex;
                  final double opacity = isFocused ? 1.0 : 0.35; // Increased visibility for unfocused bars

                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: opacity,
                    child: Center(
                      child: BarChart(_buildChartDataForIndex(index, isFocused)),
                    ),
                  );
                },
              ),
              
              // Central Focus Needle
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 2.w,
                    height: 120.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.crimson.withValues(alpha: 0.0),
                          AppColors.crimson.withValues(alpha: 0.4),
                          AppColors.crimson.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 24.h),

        _buildStatsBreakdown(widget.logs[_currentIndex]),
        
        SizedBox(height: 32.h),

        Text(
          DateFormat('MMMM dd, yyyy').format(widget.logs[_currentIndex].timestamp).toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          DateFormat('hh:mm a').format(widget.logs[_currentIndex].timestamp),
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            fontSize: 10.sp,
          ),
        ),

        SizedBox(height: 24.h),

        // ─── TIMELINE SLIDER ────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final double trackWidth = constraints.maxWidth;
                  // Dynamic indicator width following Trend tab logic
                  final double indicatorWidth = (trackWidth / (widget.logs.isEmpty ? 1 : widget.logs.length)).clamp(40.w, trackWidth);
                  final double scrollableWidth = trackWidth - indicatorWidth;
                  
                  final double progress = widget.logs.length > 1 
                      ? _currentIndex / (widget.logs.length - 1)
                      : 0;
                  
                  final double leftOffset = progress * scrollableWidth;

                  return GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final RenderBox box = context.findRenderObject() as RenderBox;
                      final localOffset = box.globalToLocal(details.globalPosition);
                      double percent = (localOffset.dx - (indicatorWidth / 2)) / scrollableWidth;
                      percent = percent.clamp(0.0, 1.0);
                      
                      final int targetPage = (percent * (widget.logs.length - 1)).round();
                      if (targetPage != _currentIndex) {
                        // Real-time jump for trend-tab feel
                        _pageController.jumpToPage(targetPage);
                      }
                    },
                    child: Container(
                      width: trackWidth,
                      height: 8.h, 
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: leftOffset,
                            child: Container(
                              width: indicatorWidth,
                              height: 8.h,
                              decoration: BoxDecoration(
                                color: AppColors.crimson,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("OLDEST", style: AppTextStyles.labelSmall.copyWith(fontSize: 8.sp, color: AppColors.textSecondary.withValues(alpha: 0.2))),
                  Text("LATEST", style: AppTextStyles.labelSmall.copyWith(fontSize: 8.sp, color: AppColors.textSecondary.withValues(alpha: 0.2))),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 40.h),
        _buildSectionHeader("METRIC OVERLAY"),
        SizedBox(height: 16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: [
              _buildMetricToggle("WEIGHT", "weight", AppColors.crimson),
              _buildMetricToggle("POS REPS", "pos", Colors.blueAccent),
              _buildMetricToggle("NEG REPS", "neg", Colors.tealAccent),
              _buildMetricToggle("STATIC", "hold", Colors.orangeAccent),
              _buildMetricToggle("FORCED", "forced", Colors.purpleAccent),
            ],
          ),
        ),

        SizedBox(height: 40.h),
        _buildSectionHeader("DATA COMPARISON"),
        SizedBox(height: 16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: ExerciseComparisonWidget(
            idx1: _comparisonIdx1,
            idx2: _comparisonIdx2,
            logs: widget.logs,
            onPointAChanged: (val) => setState(() => _comparisonIdx1 = val),
            onPointBChanged: (val) => setState(() => _comparisonIdx2 = val),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 24.w),
      child: Row(
        children: [
          Container(
            width: 2.5.w,
            height: 12.h,
            decoration: BoxDecoration(
              color: AppColors.crimson,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            title,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricToggle(String label, String key, Color color) {
    final bool isActive = _visibleMetrics.contains(key);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_visibleMetrics.contains(key)) {
            if (_visibleMetrics.length > 1) _visibleMetrics.remove(key);
          } else {
            _visibleMetrics.add(key);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isActive ? color : AppColors.white.withValues(alpha: 0.05),
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
                color: isActive ? color : AppColors.textSecondary.withValues(alpha: 0.3),
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

  Widget _buildStatsBreakdown(ExerciseLog log) {
    final provider = context.read<CycleProvider>();
    final bool isKg = provider.settings.weightUnit == WeightUnit.kgs;
    final double displayWeight = isKg ? log.weightKg : log.weightLbs;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Wrap(
        spacing: 12.w,
        runSpacing: 12.h,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.end, // Align all columns by their bottom edge
        children: [
          _buildMetricItem("WEIGHT", displayWeight > 0 ? double.parse(displayWeight.toStringAsFixed(3)).toString() : "--", displayWeight > 0 ? (isKg ? "KG" : "LBS") : "", AppColors.crimson),
          _buildMetricItem("POS", log.positiveReps > 0 ? "${log.positiveReps}" : "--", "", Colors.blueAccent, valueColor: Colors.blueAccent),
          _buildMetricItem("NEG", log.negativeReps > 0 ? "${log.negativeReps}" : "--", "", Colors.tealAccent, valueColor: Colors.tealAccent),
          _buildMetricItem("HOLD", log.staticHoldSeconds > 0 ? "${log.staticHoldSeconds}" : "--", log.staticHoldSeconds > 0 ? "S" : "", Colors.orangeAccent, valueColor: Colors.orangeAccent),
          _buildMetricItem("FORCE", log.forcedReps > 0 ? "${log.forcedReps}" : "--", "", Colors.purpleAccent, valueColor: Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, String unit, Color color, {Color valueColor = Colors.white}) {
    // Determine if we should show neutral color for "--" empty state
    final bool isNoData = value == "--";
    final Color displayValueColor = isNoData ? AppColors.textSecondary.withValues(alpha: 0.3) : valueColor;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            fontSize: 7.sp,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 4.h),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTextStyles.h2.copyWith(
                color: displayValueColor,
                fontSize: 24.sp,
                fontWeight: FontWeight.w500,
                height: 1, 
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                " $unit",
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  height: 1, 
                ),
              ),
          ],
        ),
      ],
    );
  }

  BarChartData _buildChartDataForIndex(int index, bool isFocused) {
    final log = widget.logs[index];
    
    double globalMaxWeight = 0;
    for (var l in widget.logs) {
      final w = context.read<CycleProvider>().settings.weightUnit == WeightUnit.kgs ? l.weightKg : l.weightLbs;
      if (w > globalMaxWeight) globalMaxWeight = w;
    }
    if (globalMaxWeight == 0) globalMaxWeight = 100;

    return BarChartData(
      maxY: 100,
      minY: 0,
      alignment: BarChartAlignment.center,
      barTouchData: BarTouchData(enabled: false),
      titlesData: const FlTitlesData(show: false),
      gridData: const FlGridData(show: false), // Grid is now global background
      borderData: FlBorderData(show: false),
      barGroups: [
        _makeGroupData(index, log, globalMaxWeight, isFocused),
      ],
    );
  }

  Widget _buildGlobalGrid() {
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppColors.white.withValues(alpha: 0.05),
                strokeWidth: 1,
                dashArray: [5, 5],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [const FlSpot(0, 0), const FlSpot(1, 0)],
                show: false, // Transparent data, we only want the grid
              ),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, ExerciseLog log, double maxWeight, bool isFocused) {
    final bool isKg = context.read<CycleProvider>().settings.weightUnit == WeightUnit.kgs;
    final double weightValue = isKg ? log.weightKg : log.weightLbs;

    double weightH = (weightValue / maxWeight) * 100;
    double posH = (log.positiveReps / 12) * 100;
    double negH = (log.negativeReps / 12) * 100;
    double staticH = (log.staticHoldSeconds / 30) * 100;
    double forcedH = (log.forcedReps / 6) * 100;

    const double floor = 2.0; 

    final List<BarChartRodData> rods = [];
    
    if (_visibleMetrics.contains("weight")) rods.add(_makePremiumRod(weightH.clamp(floor, 100), AppColors.crimson));
    if (_visibleMetrics.contains("pos")) rods.add(_makePremiumRod(posH.clamp(floor, 100), Colors.blueAccent));
    if (_visibleMetrics.contains("neg") && log.negativeReps > 0) rods.add(_makePremiumRod(negH.clamp(floor, 100), Colors.tealAccent));
    if (_visibleMetrics.contains("hold") && log.staticHoldSeconds > 0) rods.add(_makePremiumRod(staticH.clamp(floor, 100), Colors.orangeAccent));
    if (_visibleMetrics.contains("forced") && log.forcedReps > 0) rods.add(_makePremiumRod(forcedH.clamp(floor, 100), Colors.purpleAccent));

    return BarChartGroupData(
      x: x,
      barsSpace: 4.w,
      barRods: rods,
    );
  }

  BarChartRodData _makePremiumRod(double y, Color color) {
    return BarChartRodData(
      toY: y,
      width: 14.w, // High DENSITY styling
      gradient: LinearGradient(
        colors: [color, color.withValues(alpha: 0.6)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(4.r),
      // Background "ghost" bars removed for cleaner aesthetic
      backDrawRodData: BackgroundBarChartRodData(show: false),
    );
  }
}

class ExerciseComparisonWidget extends StatelessWidget {
  final int? idx1;
  final int? idx2;
  final List<ExerciseLog> logs;
  final Function(int?) onPointAChanged;
  final Function(int?) onPointBChanged;

  const ExerciseComparisonWidget({
    super.key,
    required this.idx1,
    required this.idx2,
    required this.logs,
    required this.onPointAChanged,
    required this.onPointBChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPointPicker("POINT A", idx1, idx2, logs, onPointAChanged, context),
              SizedBox(width: 16.w),
              _buildPointPicker("POINT B", idx2, idx1, logs, onPointBChanged, context, isEnd: true),
            ],
          ),
          if (idx1 != null && idx2 != null) ...[
            SizedBox(height: 24.h),
            _buildComparisonDetails(context),
          ] else ...[
            SizedBox(height: 32.h),
            Center(
              child: Text(
                "SELECT TWO POINTS TO COMPARE",
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.2)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPointPicker(String title, int? selectedIdx, int? otherIdx, List<ExerciseLog> logs, Function(int?) onChanged, BuildContext context, {bool isEnd = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: isEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (selectedIdx != null && isEnd) ...[
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: 12.r),
                  ),
                ),
                SizedBox(width: 8.w),
              ],
              Text(title, style: AppTextStyles.labelSmall.copyWith(color: selectedIdx != null ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.4), fontSize: 11.sp, fontWeight: FontWeight.w900)),
              if (selectedIdx != null && !isEnd) ...[
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: 12.r),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: () => _showPicker(context, selectedIdx, otherIdx, logs, onChanged),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: selectedIdx != null ? AppColors.crimson.withValues(alpha: 0.05) : AppColors.surfaceLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: selectedIdx != null ? AppColors.crimson.withValues(alpha: 0.4) : AppColors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selectedIdx != null ? Icons.event_available_rounded : Icons.event_note_rounded, color: selectedIdx != null ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.3), size: 18.r),
                  SizedBox(width: 10.w),
                  Flexible(child: Text(selectedIdx != null ? DateFormat('MM/dd').format(logs[selectedIdx].timestamp) : "SET", style: AppTextStyles.labelSmall.copyWith(fontSize: 11.sp, color: selectedIdx != null ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.4)))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context, int? current, int? other, List<ExerciseLog> logs, Function(int?) onChanged) async {
    final int? result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 40.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w, height: 4.h, margin: EdgeInsets.only(bottom: 24.h),
              decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2.r)),
            ),
            Text("SELECT SESSION", style: AppTextStyles.h3),
            SizedBox(height: 24.h),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: logs.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, i) {
                  final log = logs[i];
                  final bool isSelected = i == current;
                  final bool isOther = i == other;

                  return GestureDetector(
                    onTap: isOther ? null : () => Navigator.pop(context, i),
                    child: Opacity(
                      opacity: isOther ? 0.4 : 1.0,
                      child: Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.background.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Text(DateFormat('MMMM dd, yyyy').format(log.timestamp).toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: isSelected ? Colors.white : AppColors.textSecondary)),
                            const Spacer(),
                            Text("${double.parse((context.read<CycleProvider>().settings.weightUnit == WeightUnit.kgs ? log.weightKg : log.weightLbs).toStringAsFixed(3)).toString()} KG", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  Widget _buildComparisonDetails(BuildContext context) {
    final log1 = logs[idx1!];
    final log2 = logs[idx2!];
    final bool isKg = context.read<CycleProvider>().settings.weightUnit == WeightUnit.kgs;
    
    final List<Widget> items = [];
    items.add(_buildMetricComparison("LOAD INTENSITY", isKg ? log1.weightKg : log1.weightLbs, isKg ? log2.weightKg : log2.weightLbs, "", AppColors.crimson, precision: 3));
    items.add(_buildMetricComparison("POSITIVE REPS", log1.positiveReps.toDouble(), log2.positiveReps.toDouble(), "", Colors.blueAccent));
    
    if (log1.negativeReps > 0 || log2.negativeReps > 0) {
      items.add(_buildMetricComparison("NEGATIVE REPS", log1.negativeReps.toDouble(), log2.negativeReps.toDouble(), "", Colors.tealAccent));
    }
    if (log1.staticHoldSeconds > 0 || log2.staticHoldSeconds > 0) {
      items.add(_buildMetricComparison("STATIC HOLD", log1.staticHoldSeconds.toDouble(), log2.staticHoldSeconds.toDouble(), "S", Colors.orangeAccent));
    }

    return Column(children: items);
  }

  Widget _buildMetricComparison(String label, double v1, double v2, String unit, Color color, {int precision = 1}) {
    final delta = v2 - v1;
    // We check neutrality based on the display precision to avoid -0.0 artifacts
    final double roundedDelta = double.parse(delta.toStringAsFixed(precision));
    final bool isNeutral = roundedDelta == 0;
    
    final Color trendColor = isNeutral ? AppColors.textSecondary.withValues(alpha: 0.5) : (delta > 0 ? Colors.greenAccent : Colors.redAccent);
    final IconData? trendIcon = isNeutral ? null : (delta > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded);

    final double percent = v1 != 0 ? (delta / v1.abs()) * 100 : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w900, fontSize: 13.sp, letterSpacing: 1)),
              Row(
                children: [
                  if (trendIcon != null) ...[
                    Icon(trendIcon, color: trendColor, size: 18.r),
                    SizedBox(width: 6.w),
                  ],
                  Text(
                    isNeutral ? "0%" : "${delta > 0 ? '+' : ''}${percent.toStringAsFixed(1)}%", 
                    style: AppTextStyles.labelSmall.copyWith(color: trendColor, fontWeight: FontWeight.w900, fontSize: 14.sp),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _valItem("Point A", v1, "", precision),
              _valItem("Point B", v2, "", precision),
              _valItem("Difference", delta, unit, precision, isDelta: true, isNeutral: isNeutral),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valItem(String l, double v, String u, int p, {bool isDelta = false, bool isNeutral = false}) {
    String text;
    if (isDelta && isNeutral) {
      text = "0"; // Display exactly "0" for neutral delta as requested
    } else {
      final String prefix = (isDelta && v > 0) ? "+" : "";
      text = "$prefix${double.parse(v.toStringAsFixed(3)).toString()}";
    }

    return Column(
      children: [
        Text(l, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.4), fontSize: 10.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 4.h),
        Text(
          "$text$u", 
          style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16.sp),
        ),
      ],
    );
  }
}
