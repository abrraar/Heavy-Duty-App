import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';

class SleepAnalyticalGraph extends StatefulWidget {
  final List<DateTime> dates;
  final Map<String, List<double?>> data;
  final Set<String> visibleMetrics;
  final Function(int) onPointSelected;

  const SleepAnalyticalGraph({
    super.key,
    required this.dates,
    required this.data,
    required this.visibleMetrics,
    required this.onPointSelected,
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
    final bool hasSelection = widget.visibleMetrics.isNotEmpty;

    return Column(
      children: [
        SizedBox(
          height: 220.h,
          child: Stack(
            children: [
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
                      color: AppColors.textSecondary.withOpacity(0.2),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w900,
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
                      width: 2.w,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.crimson.withOpacity(0.0),
                            AppColors.crimson.withOpacity(0.2),
                            AppColors.crimson.withOpacity(0.0),
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

        if (hasSelection)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatMini("HOURS SLEPT", widget.data["duration"]?[_currentIndex], AppColors.crimson),
              ],
            ),
          ),
        
        SizedBox(height: hasSelection ? 32.h : 0),

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
              color: AppColors.textSecondary.withOpacity(0.4),
              fontSize: 10.sp,
            ),
          ),
        ],

        SizedBox(height: 24.h),

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
                            color: AppColors.white.withOpacity(0.1),
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
                          color: AppColors.textSecondary.withOpacity(0.2),
                        ),
                      ),
                      Text(
                        "LATEST",
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 8.sp,
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

  Widget _buildStatMini(String label, double? value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withOpacity(0.4),
            fontSize: 8.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          value != null ? value.toStringAsFixed(1) : "--",
          style: AppTextStyles.h3.copyWith(
            color: color,
            fontSize: 28.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  LineChartData _buildChartData() {
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
              colors: [entry.value.withOpacity(0.15), entry.value.withOpacity(0)],
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
          color: AppColors.white.withOpacity(0.05),
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
