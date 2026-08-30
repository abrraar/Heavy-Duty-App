import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/constants/dimensions.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';

class SleepAnalyticalGraph extends StatefulWidget {
  final List<DateTime> dates;
  final Map<String, List<double?>> data;
  final Set<String> visibleMetrics;
  final Function(int) onPointSelected;
  final bool isCompact;

  const SleepAnalyticalGraph({
    super.key,
    required this.dates,
    required this.data,
    required this.visibleMetrics,
    required this.onPointSelected,
    this.isCompact = false,
  });

  @override
  State<SleepAnalyticalGraph> createState() => _SleepAnalyticalGraphState();
}

class _SleepAnalyticalGraphState extends State<SleepAnalyticalGraph> {
  double _currentPos = 0;
  int get _currentIndex => _currentPos.round().clamp(0, widget.dates.isEmpty ? 0 : widget.dates.length - 1);

  @override
  void initState() {
    super.initState();
    _currentPos = widget.dates.isEmpty ? 0 : (widget.dates.length - 1).toDouble();
  }

  @override
  void didUpdateWidget(SleepAnalyticalGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dates.length != oldWidget.dates.length && widget.dates.isNotEmpty) {
       _currentPos = (widget.dates.length - 1).toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dates.isEmpty) return const SizedBox.shrink();

    final bool isCompact = widget.isCompact;
    final bool hasSelection = widget.visibleMetrics.isNotEmpty;

    return Column(
      children: [
        SizedBox(
          height: isCompact ? 220.h : 180.0,
          child: Stack(
            children: [
              if (hasSelection)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 40.w : 32.0),
                  child: LineChart(_buildChartData(isCompact)),
                )
              else
                Center(
                  child: Text(
                    "SELECT A METRIC TO VIEW TRENDS",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w500,
                      fontSize: isCompact ? 11.sp : 9.0,
                    ),
                  ),
                ),
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
              if (hasSelection)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: isCompact ? 2.w : 2.0,
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
        
        SizedBox(height: isCompact ? 24.h : 20.0),

        if (hasSelection)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatMini("HOURS SLEPT", widget.data["duration"]?[_currentIndex], AppColors.crimson, isCompact),
              ],
            ),
          ),
        
        SizedBox(height: hasSelection ? (isCompact ? 32.h : 24.0) : 0),

        if (hasSelection) ...[
          Text(
            DateFormat('MMM dd, yyyy').format(widget.dates[_currentIndex]).toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              fontSize: isCompact ? 13.sp : 11.0,
            ),
          ),
          SizedBox(height: isCompact ? 8.h : 4.0),
          Text(
            DateFormat('hh:mm a').format(widget.dates[_currentIndex]),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              fontSize: isCompact ? 11.sp : 9.0,
            ),
          ),
        ],

        SizedBox(height: isCompact ? 24.h : 20.0),

        Opacity(
          opacity: hasSelection ? 1.0 : 0.3,
          child: IgnorePointer(
            ignoring: !hasSelection,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 40.w : 32.0),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double trackWidth = constraints.maxWidth;
                      final double indicatorWidth = (trackWidth / (widget.dates.isEmpty ? 1 : widget.dates.length)).clamp(isCompact ? 40.w : 40.0, trackWidth);
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
                          height: isCompact ? 8.h : 6.0, 
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: AppColors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                left: leftOffset,
                                child: Container(
                                  width: indicatorWidth,
                                  height: isCompact ? 8.h : 6.0,
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
                  SizedBox(height: isCompact ? 8.h : 4.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "START",
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 8.0,
                          color: AppColors.textSecondary.withOpacity(0.2),
                        ),
                      ),
                      Text(
                        "LATEST",
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 8.0,
                          color: AppColors.textSecondary.withOpacity(0.2),
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

  Widget _buildStatMini(String label, double? value, Color color, bool isCompact) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withOpacity(0.4),
            fontSize: isCompact ? 10.sp : 8.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 4.0),
        Text(
          value != null ? value.toStringAsFixed(1) : "--",
          style: AppTextStyles.h3.copyWith(
            color: color,
            fontSize: isCompact ? 26.sp : 18.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  LineChartData _buildChartData(bool isCompact) {
    final List<LineChartBarData> lineBarsData = [];
    
    final metrics = {
      "duration": AppColors.crimson,
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
          barWidth: isCompact ? 3.w : 2.0,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              final bool isSelected = spot.x.round() == _currentIndex;
              return FlDotCirclePainter(
                radius: isSelected ? (isCompact ? 6.r : 5.0) : (isCompact ? 3.r : 2.0),
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
      maxY = 12;
    } else {
      double buffer = (maxY - minY).abs() * 0.3;
      if (buffer == 0) buffer = 2;
      minY = (minY - buffer).floorToDouble();
      maxY = (maxY + buffer).ceilToDouble();
      if (minY < 0) minY = 0;
    }

    return LineChartData(
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: ((maxY - minY) / 5).clamp(0.5, 24).toDouble(),
        getDrawingHorizontalLine: (value) => FlLine(
          color: AppColors.white.withValues(alpha: 0.05),
          strokeWidth: 1,
          dashArray: [5, 5],
        ),
      ),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      minX: _currentPos - 2.0,
      maxX: _currentPos + 2.0,
      minY: minY,
      maxY: maxY,
      lineBarsData: lineBarsData,
      lineTouchData: const LineTouchData(enabled: false),
    );
  }
}

class SleepComparisonWidget extends StatelessWidget {
  final int? idx1;
  final int? idx2;
  final List<DateTime> dates;
  final Map<String, List<double?>> data;
  final Function(int?) onPointAChanged;
  final Function(int?) onPointBChanged;
  final bool use24HourClock;
  final bool isCompact;

  const SleepComparisonWidget({
    super.key,
    required this.idx1,
    required this.idx2,
    required this.dates,
    required this.data,
    required this.onPointAChanged,
    required this.onPointBChanged,
    required this.use24HourClock,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPointPicker("POINT A", idx1, idx2, dates, onPointAChanged, context),
              SizedBox(width: isCompact ? 16.w : 12.0),
              _buildPointPicker("POINT B", idx2, idx1, dates, onPointBChanged, context, isEnd: true),
            ],
          ),
          if (idx1 != null && idx2 != null) ...[
            SizedBox(height: isCompact ? 24.h : 20.0),
            _buildComparisonDetails(),
          ] else ...[
            SizedBox(height: isCompact ? 32.h : 24.0),
            Center(
              child: Text(
                "SELECT TWO POINTS TO COMPARE",
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.2), fontSize: isCompact ? 11.sp : 9.0),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPointPicker(String title, int? selectedIdx, int? otherIdx, List<DateTime> dates, Function(int?) onChanged, BuildContext context, {bool isEnd = false}) {
    final labels = dates.map((d) {
      if (use24HourClock) {
        return DateFormat('MMM dd, HH:mm').format(d).toUpperCase();
      } else {
        return DateFormat('MMM dd, hh:mm a').format(d).toUpperCase();
      }
    }).toList();
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
                    padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: isCompact ? 12.r : 10.0),
                  ),
                ),
                SizedBox(width: isCompact ? 8.w : 6.0),
              ],
              Text(title, style: AppTextStyles.labelSmall.copyWith(color: selectedIdx != null ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.4), fontSize: isCompact ? 11.sp : 9.0, fontWeight: FontWeight.w500, letterSpacing: 2)),
              if (selectedIdx != null && !isEnd) ...[
                SizedBox(width: isCompact ? 8.w : 6.0),
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: isCompact ? 12.r : 10.0),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: isCompact ? 10.h : 8.0),
          GestureDetector(
            onTap: () => _showPicker(context, selectedIdx, otherIdx, dates, onChanged),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 14.w : 12.0, vertical: isCompact ? 12.h : 10.0),
              decoration: BoxDecoration(
                color: selectedIdx != null ? AppColors.crimson.withValues(alpha: 0.05) : AppColors.surfaceLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                border: Border.all(color: selectedIdx != null ? AppColors.crimson.withValues(alpha: 0.4) : AppColors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selectedIdx != null ? Icons.event_available_rounded : Icons.event_note_rounded, color: AppColors.crimson, size: isCompact ? 18.r : 16.0),
                  SizedBox(width: isCompact ? 10.w : 8.0),
                  Flexible(child: Text(selectedIdx != null ? labels[selectedIdx] : "SET POINT", overflow: TextOverflow.ellipsis, style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 11.sp : 10.0, color: selectedIdx != null ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.4)))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context, int? current, int? other, List<DateTime> dates, Function(int?) onChanged) async {
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
        padding: EdgeInsets.fromLTRB(isCompact ? 24.w : 20.0, isCompact ? 12.h : 10.0, isCompact ? 24.w : 20.0, isCompact ? 40.h : 32.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0)),
          border: Border.all(color: AppColors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isCompact ? 40.w : 40.0, height: isCompact ? 4.h : 4.0, margin: EdgeInsets.only(bottom: isCompact ? 24.h : 20.0),
              decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.2), borderRadius: BorderRadius.circular(2.r)),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 10.r : 8.0),
                  decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.event_note_rounded, color: AppColors.crimson, size: isCompact ? 24.r : 20.0),
                ),
                SizedBox(width: isCompact ? 16.w : 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SELECT LOG", style: AppTextStyles.h3.copyWith(fontSize: isCompact ? 20.sp : 18.0)),
                      Text("CHOOSE A DATE FROM YOUR LOGS", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5), letterSpacing: 1, fontSize: isCompact ? 11.sp : 10.0)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isCompact ? 24.h : 20.0),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: sortedDateKeys.length,
                separatorBuilder: (context, index) => SizedBox(height: isCompact ? 12.h : 10.0),
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
                        final int? timeResult = await showModalBottomSheet<int>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => Container(
                            padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0))),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("SELECT TIME", style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson, letterSpacing: 1.2, fontSize: isCompact ? 14.sp : 12.0)),
                                SizedBox(height: 20.h),
                                ...indices.map((idx) {
                                  final bool isCurrent = idx == current;
                                  final bool isOther = idx == other;
                                  return ListTile(
                                    contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 12.0),
                                    leading: Icon(
                                      isCurrent ? Icons.check_circle_rounded : (isOther ? Icons.info_outline_rounded : Icons.radio_button_off_rounded),
                                      color: isCurrent ? AppColors.crimson : (isOther ? AppColors.textSecondary.withValues(alpha: 0.5) : AppColors.textSecondary.withValues(alpha: 0.2)),
                                    ),
                                    title: Text(
                                      use24HourClock 
                                          ? DateFormat('HH:mm').format(dates[idx])
                                          : DateFormat('hh:mm a').format(dates[idx]),
                                      style: AppTextStyles.labelSmall.copyWith(color: isCurrent ? Colors.white : (isOther ? AppColors.textSecondary.withValues(alpha: 0.5) : AppColors.textSecondary), fontSize: isCompact ? 11.sp : 10.0),
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
                      padding: EdgeInsets.all(isCompact ? 16.r : 14.0),
                      decoration: BoxDecoration(
                        color: isPartiallySelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.background.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
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
                            size: isCompact ? 20.r : 18.0,
                          ),
                          SizedBox(width: isCompact ? 16.w : 12.0),
                          Text(
                            DateFormat('MMMM dd, yyyy').format(displayDate).toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isPartiallySelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: isCompact ? 12.sp : 11.0,
                            ),
                          ),
                          const Spacer(),
                          if (indices.length > 1)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.w : 6.0, vertical: isCompact ? 4.h : 2.0),
                              decoration: BoxDecoration(color: AppColors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0)),
                              child: Text("${indices.length} LOGS", style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 9.sp : 8.0, color: AppColors.textSecondary.withValues(alpha: 0.5))),
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

  Widget _buildComparisonDetails() {
    final List<Widget> items = [];
    final v1 = data["duration"]?[idx1!];
    final v2 = data["duration"]?[idx2!];
    if (v1 != null && v2 != null) {
      items.add(_buildMetricComparison("SLEEP DURATION", v1, v2, "hr", AppColors.crimson));
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 20.h : 16.0),
          child: Text(
            "NO OVERLAPPING METRICS ON THESE DATES", 
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.3), fontSize: isCompact ? 10.sp : 8.0)
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
      margin: EdgeInsets.only(bottom: isCompact ? 16.h : 12.0),
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w500, fontSize: isCompact ? 13.sp : 12.0, letterSpacing: 1)),
              Row(
                children: [
                  Icon(delta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, size: isCompact ? 18.r : 16.0),
                  SizedBox(width: isCompact ? 6.w : 4.0),
                  Text("${delta >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%", style: AppTextStyles.labelSmall.copyWith(color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w500, fontSize: isCompact ? 13.sp : 12.0)),
                ],
              ),
            ],
          ),
          SizedBox(height: isCompact ? 20.h : 16.0),
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
        Text(l, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.4), fontSize: isCompact ? 10.sp : 9.0, fontWeight: FontWeight.w500)),
        SizedBox(height: isCompact ? 4.h : 2.0),
        Text("${v >= 0 && isDelta ? '+' : ''}${v.toStringAsFixed(1)}$u", style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w500, fontSize: isCompact ? 15.sp : 14.0)),
      ],
    );
  }
}
