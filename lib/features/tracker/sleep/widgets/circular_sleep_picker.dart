import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';

class CircularSleepPicker extends StatefulWidget {
  final TimeOfDay initialBedtime;
  final TimeOfDay initialWakeTime;
  final bool canSave;
  final String? disabledReason;
  final DateTime selectedDate;
  final int quality;
  final String note;
  final VoidCallback onPickDate;
  final Function(TimeOfDay bedtime, TimeOfDay wakeTime) onTimeChanged;
  final Function(int) onQualityChanged;
  final Function(String) onNoteChanged;
  final VoidCallback onSave;

  const CircularSleepPicker({
    super.key,
    required this.initialBedtime,
    required this.initialWakeTime,
    required this.canSave,
    this.disabledReason,
    required this.selectedDate,
    required this.quality,
    required this.note,
    required this.onPickDate,
    required this.onTimeChanged,
    required this.onQualityChanged,
    required this.onNoteChanged,
    required this.onSave,
  });

  @override
  State<CircularSleepPicker> createState() => _CircularSleepPickerState();
}

class _CircularSleepPickerState extends State<CircularSleepPicker> {
  final GlobalKey _containerKey = GlobalKey();
  late double _startAngle;
  late double _endAngle;
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _startAngle = _timeToAngle(widget.initialBedtime);
    _endAngle = _timeToAngle(widget.initialWakeTime);
    _noteController = TextEditingController(text: widget.note);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  double _timeToAngle(TimeOfDay time) {
    final double totalMinutes = time.hour * 60.0 + time.minute;
    final double dayMinutes = 24.0 * 60.0;
    // Normalize to [0, 2*pi] range
    return ((totalMinutes / dayMinutes) * 2 * pi - (pi / 2)) % (2 * pi);
  }

  TimeOfDay _angleToTime(double angle) {
    // Convert [0, 2*pi] range back to TimeOfDay, accounting for -pi/2 offset
    double normalizedAngle = (angle + pi / 2) % (2 * pi);
    if (normalizedAngle < 0) normalizedAngle += 2 * pi;
    final double dayMinutes = 24.0 * 60.0;
    final int totalMinutes = ((normalizedAngle / (2 * pi)) * dayMinutes).round();
    return TimeOfDay(hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
  }

  String _formatTime(double angle) {
    final time = _angleToTime(angle);
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt).toLowerCase();
  }

  Future<void> _pickTime(bool isBedtime) async {
    final initialTime = isBedtime ? _angleToTime(_startAngle) : _angleToTime(_endAngle);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.crimson,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isBedtime) {
          _startAngle = _timeToAngle(picked);
        } else {
          _endAngle = _timeToAngle(picked);
        }
      });
      widget.onTimeChanged(_angleToTime(_startAngle), _angleToTime(_endAngle));
    }
  }

  void _updateAngle(Offset localPosition, bool isStart) {
    final RenderBox? box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    final center = box.size.center(Offset.zero);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    // atan2 returns [-pi, pi]. Normalize to [0, 2*pi] to match initial values.
    final angle = atan2(dy, dx) % (2 * pi);

    setState(() {
      if (isStart) {
        _startAngle = angle;
      } else {
        _endAngle = angle;
      }
    });
    widget.onTimeChanged(_angleToTime(_startAngle), _angleToTime(_endAngle));
  }

  @override
  Widget build(BuildContext context) {
    final duration = _calculateDuration();
    final double containerSize = 320.r;
    final double ringRadius = 120.r; // Slightly smaller to give room for handles
    final double centerX = containerSize / 2;
    final double centerY = containerSize / 2;

    return Column(
      children: [
        SizedBox(
          key: _containerKey,
          width: containerSize,
          height: containerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Static Ring & Arc
              CustomPaint(
                size: Size(containerSize, containerSize),
                painter: SleepPickerPainter(
                  startAngle: _startAngle,
                  endAngle: _endAngle,
                  radius: ringRadius,
                ),
              ),

              // 2. Center Content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _pickTime(true),
                    child: Column(
                      children: [
                        Text("Fall asleep", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 12.sp)),
                        Text(_formatTime(_startAngle), style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: 180.w, // Constrain width to inner circle
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: "${duration.inHours}", style: AppTextStyles.h1.copyWith(fontSize: 64.sp, color: Colors.white, fontWeight: FontWeight.w300)),
                            TextSpan(text: "hr", style: AppTextStyles.h3.copyWith(fontSize: 32.sp, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w300)),
                            if (duration.inMinutes % 60 > 0)
                              TextSpan(text: " ${duration.inMinutes % 60}m", style: AppTextStyles.h3.copyWith(fontSize: 24.sp, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w300)),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  GestureDetector(
                    onTap: () => _pickTime(false),
                    child: Column(
                      children: [
                        Text("Wake Up", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 12.sp)),
                        Text(_formatTime(_endAngle), style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),

              // 3. Draggable Handles (Positioned relative to CENTER)
              _buildDraggableHandle(
                centerX: centerX,
                centerY: centerY,
                angle: _startAngle,
                radius: ringRadius,
                icon: Icons.bedtime_rounded,
                color: const Color(0xFF4A55A2),
                isStart: true,
                isDragging: _isDraggingStart,
              ),
              _buildDraggableHandle(
                centerX: centerX,
                centerY: centerY,
                angle: _endAngle,
                radius: ringRadius,
                icon: Icons.wb_sunny_rounded,
                color: Colors.yellow,
                isStart: false,
                isDragging: _isDraggingEnd,
              ),
            ],
          ),
        ),
        SizedBox(height: 40.h),
        // Rating and Note
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SESSION QUALITY",
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary.withOpacity(0.5),
                  letterSpacing: 1.5,
                  fontSize: 10.sp,
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  final isSelected = rating <= widget.quality;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onQualityChanged(rating);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.crimson.withOpacity(0.1) : AppColors.surfaceLight.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.crimson : AppColors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: isSelected ? AppColors.crimson : AppColors.textSecondary.withOpacity(0.2),
                        size: 24.r,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 24.h),
              Text(
                "NOTES",
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary.withOpacity(0.5),
                  letterSpacing: 1.5,
                  fontSize: 10.sp,
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _noteController,
                onChanged: widget.onNoteChanged,
                style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "How did you feel today?",
                  hintStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary.withOpacity(0.3)),
                  filled: true,
                  fillColor: AppColors.surfaceLight.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide(color: AppColors.white.withOpacity(0.05)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide(color: AppColors.white.withOpacity(0.05)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: const BorderSide(color: AppColors.crimson),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 32.h),
        // Date Picker Row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: GestureDetector(
            onTap: widget.onPickDate,
            child: Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.white.withOpacity(0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM dd, yyyy').format(widget.selectedDate).toUpperCase(),
                    style: AppTextStyles.labelMedium.copyWith(color: Colors.white, letterSpacing: 1),
                  ),
                  Icon(Icons.calendar_today_rounded, color: AppColors.crimson, size: 18.r),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        GestureDetector(
          onTap: widget.canSave ? widget.onSave : null,
          child: Opacity(
            opacity: widget.canSave ? 1.0 : 0.4,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 40.w),
              height: 56.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.crimson,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  if (widget.canSave)
                    BoxShadow(color: AppColors.crimson.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.canSave ? "RECORD SLEEP" : (widget.disabledReason ?? "RECORD SLEEP"),
                style: AppTextStyles.buttonPrimary.copyWith(
                  color: Colors.white,
                  letterSpacing: 1.2,
                  fontSize: widget.canSave ? 16.sp : 12.sp,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableHandle({
    required double centerX,
    required double centerY,
    required double angle,
    required double radius,
    required IconData icon,
    required Color color,
    required bool isStart,
    required bool isDragging,
  }) {
    final x = centerX + radius * cos(angle);
    final y = centerY + radius * sin(angle);

    return Positioned(
      left: x - 28.r,
      top: y - 28.r,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) {
          HapticFeedback.mediumImpact();
          setState(() {
            if (isStart) _isDraggingStart = true;
            else _isDraggingEnd = true;
          });
        },
        onLongPressMoveUpdate: (details) {
          final RenderBox? box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
          if (box != null) {
            final localPos = box.globalToLocal(details.globalPosition);
            _updateAngle(localPos, isStart);
          }
        },
        onLongPressEnd: (_) {
          setState(() {
            _isDraggingStart = false;
            _isDraggingEnd = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 56.r,
          height: 56.r,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: isDragging ? color.withOpacity(0.4) : Colors.black.withOpacity(0.4),
                blurRadius: isDragging ? 15 : 8,
                spreadRadius: isDragging ? 2 : 0,
                offset: const Offset(0, 2),
              )
            ],
            border: Border.all(
              color: isDragging ? color : color.withOpacity(0.6),
              width: isDragging ? 3.r : 2.r,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 24.r),
        ),
      ),
    );
  }

  Duration _calculateDuration() {
    final start = _angleToTime(_startAngle);
    final end = _angleToTime(_endAngle);
    int startMin = start.hour * 60 + start.minute;
    int endMin = end.hour * 60 + end.minute;
    int diff = endMin - startMin;
    if (diff <= 0) diff += 24 * 60;
    return Duration(minutes: diff);
  }
}

class SleepPickerPainter extends CustomPainter {
  final double startAngle;
  final double endAngle;
  final double radius;

  SleepPickerPainter({required this.startAngle, required this.endAngle, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final strokeWidth = 35.r;

    final bgPaint = Paint()
      ..color = AppColors.surfaceLight.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    double sweepAngle = endAngle - startAngle;
    if (sweepAngle < 0) sweepAngle += 2 * pi;

    // Guard against SweepGradient endAngle <= startAngle crash
    final double safeSweepAngle = sweepAngle.clamp(0.001, 2 * pi);

    final activePaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: safeSweepAngle,
        colors: const [
          Color(0xFF1A237E), // Deep Night Blue (Bedtime)
          Color(0xFF673AB7), // Midnight Purple
          Color(0xFFE91E63), // Dawn Pink
          Color(0xFFFFB74D), // Sunrise Orange
          Colors.yellow,     // Morning Sun (Wake up)
        ],
        stops: const [0.0, 0.4, 0.7, 0.9, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
