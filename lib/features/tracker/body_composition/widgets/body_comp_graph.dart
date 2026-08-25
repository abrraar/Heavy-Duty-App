import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/model/cycle_settings.dart'; // For WeightUnit

class BodyCompGraph extends StatefulWidget {
  final List<DateTime> dates;
  final Map<String, List<double?>> data;
  final Set<String> visibleMetrics;
  final Function(int) onPointSelected;

  const BodyCompGraph({
    super.key,
    required this.dates,
    required this.data,
    required this.visibleMetrics,
    required this.onPointSelected,
  });

  @override
  State<BodyCompGraph> createState() => _BodyCompGraphState();
}

class _BodyCompGraphState extends State<BodyCompGraph> {
  double _currentPos = 0;
  int get _currentIndex => _currentPos.round().clamp(0, widget.dates.isEmpty ? 0 : widget.dates.length - 1);

  @override
  void initState() {
    super.initState();
    _currentPos = widget.dates.isEmpty ? 0 : (widget.dates.length - 1).toDouble();
  }

  @override
  void didUpdateWidget(BodyCompGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dates.length != oldWidget.dates.length && widget.dates.isNotEmpty) {
       _currentPos = (widget.dates.length - 1).toDouble();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dates.isEmpty) return const SizedBox.shrink();
    final bool hasSelection = widget.visibleMetrics.isNotEmpty;

    return Column(
      children: [
        // The Chart Area
        SizedBox(
          height: 220.h,
          child: Stack(
            children: [
              // Line Chart Background
              if (hasSelection)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                  child: LineChart(_buildChartData()),
                )
              else
                Center(
                  child: Text(
                    "SELECT A METRIC TO VIEW TRENDS",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              // Invisible Gesture Area for continuous sliding
              if (hasSelection)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final double sensitivity = 0.04; 
                    setState(() {
                      _currentPos -= details.primaryDelta! * sensitivity;
                      _currentPos = _currentPos.clamp(0, (widget.dates.length - 1).toDouble());
                    });
                    widget.onPointSelected(_currentIndex);
                  },
                  onHorizontalDragEnd: (_) {
                    setState(() {
                      _currentPos = _currentIndex.toDouble();
                    });
                  },
                  child: const SizedBox.expand(),
                ),
              // Selection Indicator (Vertical Line)
              if (hasSelection)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 2.w,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.crimson.withValues(alpha: 0.0),
                            AppColors.crimson.withValues(alpha: 0.2),
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

        // Metrics Display for Current Point
        if (hasSelection)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Consumer<BodyCompProvider>(
              builder: (context, provider, _) {
                final String unit = provider.settings.weightUnit == WeightUnit.kgs ? "KG" : "LBS";
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatMini("WEIGHT", widget.data["weight"]?[_currentIndex], Colors.tealAccent, unit),
                    _buildStatMini("BODY FAT", widget.data["fat"]?[_currentIndex], Colors.redAccent, unit),
                    _buildStatMini("MUSCLE", widget.data["muscle"]?[_currentIndex], Colors.lightGreenAccent, unit),
                  ],
                );
              },
            ),
          ),
        
        SizedBox(height: hasSelection ? 32.h : 0),

        // Date Display for Current Point
        if (hasSelection) ...[
          Text(
            DateFormat('MMM dd, yyyy').format(widget.dates[_currentIndex]).toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            DateFormat('hh:mm a').format(widget.dates[_currentIndex]),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              fontSize: 10.sp,
            ),
          ),
        ],

        SizedBox(height: 24.h),

        // Slider / Positional Bar
        Opacity(
          opacity: hasSelection ? 1.0 : 0.3,
          child: IgnorePointer(
            ignoring: !hasSelection,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.w),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double trackWidth = constraints.maxWidth;
                      final double indicatorWidth = (trackWidth / (widget.dates.isEmpty ? 1 : widget.dates.length)).clamp(40.w, trackWidth);
                      final double scrollableWidth = trackWidth - indicatorWidth;
                      
                      final double leftOffset = widget.dates.length > 1 
                          ? (_currentPos / (widget.dates.length - 1)) * scrollableWidth
                          : 0;

                      return GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          final localOffset = box.globalToLocal(details.globalPosition);
                          double percent = (localOffset.dx - (indicatorWidth / 2)) / scrollableWidth;
                          percent = percent.clamp(0.0, 1.0);
                          
                          final double newPos = percent * (widget.dates.length - 1);
                          if (newPos != _currentPos) {
                            setState(() {
                              _currentPos = newPos;
                            });
                            widget.onPointSelected(_currentIndex);
                          }
                        },
                        onHorizontalDragEnd: (_) {
                          setState(() {
                            _currentPos = _currentIndex.toDouble();
                          });
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
                      Text(
                        "START",
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 8.sp,
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                      Text(
                        "LATEST",
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 8.sp,
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatMini(String label, double? value, Color color, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            fontSize: 7.sp, // Smaller label
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 6.h),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value != null ? value.toStringAsFixed(1) : "--",
              style: AppTextStyles.h3.copyWith(
                color: color,
                fontSize: 22.sp, // Larger value for impact
                fontWeight: FontWeight.w900,
              ),
            ),
            if (value != null) ...[
              SizedBox(width: 4.w),
              Text(
                unit,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color.withValues(alpha: 0.5),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  LineChartData _buildChartData() {
    final List<LineChartBarData> lineBarsData = [];
    
    final metrics = {
      "weight": Colors.tealAccent,
      "fat": Colors.redAccent,
      "muscle": Colors.lightGreenAccent,
    };

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    final double viewMinX = _currentPos - 2.0;
    final double viewMaxX = _currentPos + 2.0;

    for (var entry in metrics.entries) {
      if (!widget.visibleMetrics.contains(entry.key)) continue;
      
      final spots = <FlSpot>[];
      final rawData = widget.data[entry.key] ?? [];
      
      for (int i = 0; i < widget.dates.length; i++) {
        if (i < rawData.length && rawData[i] != null) {
          final val = rawData[i]!;
          spots.add(FlSpot(i.toDouble(), val));
          
          // Calculate Y-axis range based only on visible spots
          if (i >= viewMinX - 0.5 && i <= viewMaxX + 0.5) {
            if (val < minY) minY = val;
            if (val > maxY) maxY = val;
          }
        }
      }

      if (spots.isNotEmpty) {
        lineBarsData.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: entry.value,
          barWidth: 3.w,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              final bool isSelected = spot.x.round() == _currentIndex;
              return FlDotCirclePainter(
                radius: isSelected ? 6.r : 3.r,
                color: isSelected ? Colors.white : entry.value,
                strokeWidth: isSelected ? 3 : 0,
                strokeColor: entry.value,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [entry.value.withValues(alpha: 0.15), entry.value.withValues(alpha: 0)],
            ),
          ),
        ));
      }
    }

    if (minY == double.infinity) {
      minY = 0;
      maxY = 100;
    } else {
      double buffer = (maxY - minY).abs() * 0.3;
      if (buffer == 0) buffer = 20;
      minY = (minY - buffer).floorToDouble();
      maxY = (maxY + buffer).ceilToDouble();
      if (minY < 0) minY = 0;
    }

    return LineChartData(
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: ((maxY - minY) / 5).clamp(0.1, 1000).toDouble(),
        getDrawingHorizontalLine: (value) => FlLine(
          color: AppColors.white.withValues(alpha: 0.05),
          strokeWidth: 1,
          dashArray: [5, 5],
        ),
      ),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      minX: _currentPos - 2.0, // Shows exactly 5 plots (smooth movement)
      maxX: _currentPos + 2.0,
      minY: minY,
      maxY: maxY,
      lineBarsData: lineBarsData,
      lineTouchData: const LineTouchData(enabled: false),
    );
  }
}

class BodyCompComparisonWidget extends StatelessWidget {
  final int? idx1;
  final int? idx2;
  final List<DateTime> dates;
  final Map<String, List<double?>> data;
  final Function(int?) onPointAChanged;
  final Function(int?) onPointBChanged;

  const BodyCompComparisonWidget({
    super.key,
    required this.idx1,
    required this.idx2,
    required this.dates,
    required this.data,
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
              _buildPointPicker("POINT A", idx1, idx2, dates, onPointAChanged, context),
              SizedBox(width: 16.w),
              _buildPointPicker("POINT B", idx2, idx1, dates, onPointBChanged, context, isEnd: true),
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

  Widget _buildPointPicker(String title, int? selectedIdx, int? otherIdx, List<DateTime> dates, Function(int?) onChanged, BuildContext context, {bool isEnd = false}) {
    final labels = dates.map((d) => DateFormat('MMM dd, HH:mm').format(d).toUpperCase()).toList();
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
            onTap: () => _showPicker(context, selectedIdx, otherIdx, dates, onChanged),
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
                  Flexible(child: Text(selectedIdx != null ? labels[selectedIdx] : "SET POINT", overflow: TextOverflow.ellipsis, style: AppTextStyles.labelSmall.copyWith(fontSize: 11.sp, color: selectedIdx != null ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.4)))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context, int? current, int? other, List<DateTime> dates, Function(int?) onChanged) async {
    // 1. Group indices by Date
    final Map<String, List<int>> dateGroups = {};
    for (int i = 0; i < dates.length; i++) {
      final dateKey = DateFormat('yyyy-MM-dd').format(dates[i]);
      dateGroups.putIfAbsent(dateKey, () => []).add(i);
    }
    final sortedDateKeys = dateGroups.keys.toList()..sort((a, b) => b.compareTo(a));

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
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.event_note_rounded, color: AppColors.crimson, size: 24.r),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SELECT RECORDING", style: AppTextStyles.h3.copyWith(fontSize: 18.sp)),
                      Text("CHOOSE A DATE FROM YOUR HISTORY", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5), letterSpacing: 1)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: sortedDateKeys.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, i) {
                  final String dateKey = sortedDateKeys[i];
                  final List<int> indices = dateGroups[dateKey]!;
                  final DateTime displayDate = dates[indices.first];
                  
                  bool isPartiallySelected = indices.contains(current);
                  bool isOccupiedByOther = indices.contains(other);

                  return GestureDetector(
                    onTap: () async {
                      if (indices.length == 1) {
                        Navigator.pop(context, indices.first);
                      } else {
                        // Show Time Selection for multiple records
                        final int? timeResult = await showModalBottomSheet<int>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => Container(
                            padding: EdgeInsets.all(24.r),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("SELECT TIME", style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson, letterSpacing: 1.2)),
                                SizedBox(height: 20.h),
                                ...indices.map((idx) {
                                  final bool isCurrent = idx == current;
                                  final bool isOther = idx == other;
                                  return ListTile(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
                                    leading: Icon(
                                      isCurrent ? Icons.check_circle_rounded : (isOther ? Icons.info_outline_rounded : Icons.radio_button_off_rounded),
                                      color: isCurrent ? AppColors.crimson : (isOther ? AppColors.textSecondary.withValues(alpha: 0.5) : AppColors.textSecondary.withValues(alpha: 0.2)),
                                    ),
                                    title: Text(
                                      DateFormat('hh:mm a').format(dates[idx]),
                                      style: AppTextStyles.labelSmall.copyWith(color: isCurrent ? Colors.white : (isOther ? AppColors.textSecondary.withValues(alpha: 0.5) : AppColors.textSecondary)),
                                    ),
                                    onTap: () => Navigator.pop(ctx, idx),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                        if (timeResult != null && context.mounted) Navigator.pop(context, timeResult);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: isPartiallySelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.background.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isPartiallySelected ? AppColors.crimson : (isOccupiedByOther ? AppColors.crimson.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.05)),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPartiallySelected ? Icons.check_circle_rounded : (isOccupiedByOther ? Icons.info_outline_rounded : Icons.calendar_today_rounded),
                            color: isPartiallySelected ? AppColors.crimson : (isOccupiedByOther ? AppColors.crimson.withValues(alpha: 0.5) : AppColors.textSecondary.withValues(alpha: 0.2)),
                            size: 20.r,
                          ),
                          SizedBox(width: 16.w),
                          Text(
                            DateFormat('MMMM dd, yyyy').format(displayDate).toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isPartiallySelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isPartiallySelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13.sp,
                            ),
                          ),
                          const Spacer(),
                          if (indices.length > 1)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8.r)),
                              child: Text("${indices.length} LOGS", style: AppTextStyles.labelSmall.copyWith(fontSize: 9.sp, color: AppColors.textSecondary.withValues(alpha: 0.5))),
                            ),
                        ],
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
    final List<Widget> items = [];
    final provider = context.read<BodyCompProvider>();
    final String massUnit = provider.settings.weightUnit == WeightUnit.kgs ? "kg" : "lbs";
    
    final metrics = [
      {'label': "WEIGHT", 'key': "weight", 'color': Colors.tealAccent, 'unit': massUnit},
      {'label': "BODY FAT", 'key': "fat", 'color': Colors.redAccent, 'unit': massUnit},
      {'label': "MUSCLE", 'key': "muscle", 'color': Colors.lightGreenAccent, 'unit': massUnit},
    ];

    for (var m in metrics) {
      final v1 = data[m['key']]?[idx1!];
      final v2 = data[m['key']]?[idx2!];
      if (v1 != null && v2 != null) {
        items.add(_buildMetricComparison(m['label'] as String, v1, v2, m['unit'] as String, m['color'] as Color));
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Text(
            "NO OVERLAPPING METRICS ON THESE DATES", 
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.3), fontSize: 8.sp)
          ),
        ),
      );
    }

    return Column(children: items);
  }

  Widget _buildMetricComparison(String label, double v1, double v2, String unit, Color color) {
    final delta = v2 - v1;
    final percent = v1 != 0 ? (delta / v1.abs()) * 100 : 0.0;

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
                  Icon(delta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, size: 18.r),
                  SizedBox(width: 6.w),
                  Text("${delta >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%", style: AppTextStyles.labelSmall.copyWith(color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 14.sp)),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _valItem("Point A", v1, unit),
              _valItem("Point B", v2, unit),
              _valItem("Difference", delta, unit, isDelta: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valItem(String l, double v, String u, {bool isDelta = false}) {
    return Column(
      children: [
        Text(l, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.4), fontSize: 10.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 4.h),
        Text("${v >= 0 && isDelta ? '+' : ''}${v.toStringAsFixed(1)}$u", style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16.sp)),
      ],
    );
  }
}
