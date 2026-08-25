import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:provider/provider.dart';
import 'model/exercise.dart';
import 'model/exercise_log.dart';
import 'model/training_cycle.dart';
import 'model/workout.dart';

class CycleExerciseDetailScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  const CycleExerciseDetailScreen({super.key, required this.exerciseId, required this.exerciseName});

  @override
  State<CycleExerciseDetailScreen> createState() =>
      _CycleExerciseDetailScreenState();
}

class _CycleExerciseDetailScreenState extends State<CycleExerciseDetailScreen> {
  final Map<String, bool> _activeIntensifiers = {
    "POSITIVE REPS": false,
    "STATIC HOLD": false,
    "NEGATIVE REPS": false,
    "FORCED REPS": false,
  };

  final _weightController = TextEditingController();
  final _posRepsController = TextEditingController();
  final _staticSecsController = TextEditingController();
  final _negRepsController = TextEditingController();
  final _forcedRepsController = TextEditingController();
  final _commentController = TextEditingController();

  Timer? _debounce;
  ExerciseLog? _currentSessionLog;
  bool _isInitialLoad = true;
  final bool _isManualEditMode = false;
  WeightUnit? _lastUnit;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _weightController.addListener(_onFieldChanged);
    _posRepsController.addListener(_onFieldChanged);
    _staticSecsController.addListener(_onFieldChanged);
    _negRepsController.addListener(_onFieldChanged);
    _forcedRepsController.addListener(_onFieldChanged);
    _commentController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_isInitialLoad) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  Future<void> _autoSave() async {
    if (!mounted) return;
    final displayWeight = double.tryParse(_weightController.text) ?? 0;
    final posReps = int.tryParse(_posRepsController.text) ?? 0;
    final staticSecs = int.tryParse(_staticSecsController.text) ?? 0;
    final negReps = int.tryParse(_negRepsController.text) ?? 0;
    final forcedReps = int.tryParse(_forcedRepsController.text) ?? 0;

    final bool hasIntensifier = posReps > 0 || staticSecs > 0 || negReps > 0 || forcedReps > 0;
    final bool isSetValid = displayWeight > 0 && hasIntensifier;
    
    if (!isSetValid) {
      if (_currentSessionLog != null) {
        debugPrint("CycleExerciseDetailScreen: Set invalid, removing log...");
        final provider = context.read<CycleProvider>();
        await provider.deleteExerciseLog(_currentSessionLog!.id);
        _currentSessionLog = null;
      }
      return;
    }

    final provider = context.read<CycleProvider>();
    final dualWeights = provider.calculateDualWeights(displayWeight);
    
    final log = ExerciseLog(
      id: _currentSessionLog?.id, 
      exerciseId: widget.exerciseId,
      weightKg: dualWeights['kg']!,
      weightLbs: dualWeights['lbs']!,
      positiveReps: posReps,
      staticHoldSeconds: staticSecs,
      negativeReps: negReps,
      forcedReps: forcedReps,
      comment: _commentController.text.trim(),
      timestamp: _currentSessionLog?.timestamp ?? DateTime.now(),
    );

    _currentSessionLog = log;
    await provider.upsertExerciseLog(log);
    debugPrint("CycleExerciseDetailScreen: Log triggered for Supabase (Weight: $displayWeight)");
  }

  void _toggleIntensifier(String key) {
    setState(() {
      _activeIntensifiers[key] = !_activeIntensifiers[key]!;
    });
    _onFieldChanged();
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _autoSave(); // Final save attempt on exit
    }
    _weightController.dispose();
    _posRepsController.dispose();
    _staticSecsController.dispose();
    _negRepsController.dispose();
    _forcedRepsController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final sessionLogs = provider.logs.where((l) => l.exerciseId == widget.exerciseId).toList();
        
        // --- REACTIVE UI REFRESH ON UNIT CHANGE ---
        if (_lastUnit != null && _lastUnit != provider.settings.weightUnit) {
          // Force re-load controllers from the raw database columns of the current log
          _isInitialLoad = true;
        }
        _lastUnit = provider.settings.weightUnit;
        
        // Discover all exercise instances of this name across cycles/workouts for logical history
        final List<Exercise> exerciseInstances = [];
        final sortedCycles = provider.cycles.where((c) => c.status != CycleStatus.template).toList()
          ..sort((a, b) {
            if (a.status == CycleStatus.finished && b.status == CycleStatus.finished) {
              return (a.completedAt ?? DateTime(0)).compareTo(b.completedAt ?? DateTime(0));
            }
            if (a.status == CycleStatus.active) return 1;
            if (b.status == CycleStatus.active) return -1;
            return 0;
          });

        for (var cycle in sortedCycles) {
          final sortedWorkouts = List<Workout>.from(cycle.workouts)..sort((a, b) => a.order.compareTo(b.order));
          for (var workout in sortedWorkouts) {
            final sortedExercises = List<Exercise>.from(workout.exercises)..sort((a, b) => a.order.compareTo(b.order));
            for (var ex in sortedExercises) {
              if (ex.name.trim().toUpperCase() == widget.exerciseName.trim().toUpperCase()) {
                exerciseInstances.add(ex);
              }
            }
          }
        }

        bool isCycleFinished = false;
        try {
          final currentEx = provider.exercises.firstWhere((e) => e.id == widget.exerciseId);
          final currentWo = provider.workouts.firstWhere((w) => w.id == currentEx.workoutId);
          final currentCy = provider.cycles.firstWhere((c) => c.id == currentWo.cycleId);
          isCycleFinished = currentCy.status == CycleStatus.finished;
        } catch (e) {
          debugPrint("CycleExerciseDetailScreen: Error checking read-only: $e");
        }

        final bool isReadOnly = isCycleFinished && !_isManualEditMode;

        if (_isInitialLoad) {
          if (isCycleFinished) {
            if (sessionLogs.isNotEmpty) {
              _currentSessionLog = sessionLogs.first;
              final displayWeight = provider.getWeightForDisplay(_currentSessionLog!);
              _weightController.text = displayWeight > 0 ? double.parse(displayWeight.toStringAsFixed(3)).toString() : "";
              _posRepsController.text = _currentSessionLog!.positiveReps > 0 ? _currentSessionLog!.positiveReps.toString() : "";
              _staticSecsController.text = _currentSessionLog!.staticHoldSeconds > 0 ? _currentSessionLog!.staticHoldSeconds.toString() : "";
              _negRepsController.text = _currentSessionLog!.negativeReps > 0 ? _currentSessionLog!.negativeReps.toString() : "";
              _forcedRepsController.text = _currentSessionLog!.forcedReps > 0 ? _currentSessionLog!.forcedReps.toString() : "";
              _commentController.text = _currentSessionLog!.comment ?? "";
              
              _activeIntensifiers["POSITIVE REPS"] = _currentSessionLog!.positiveReps > 0;
              if (_currentSessionLog!.staticHoldSeconds > 0) _activeIntensifiers["STATIC HOLD"] = true;
              if (_currentSessionLog!.negativeReps > 0) _activeIntensifiers["NEGATIVE REPS"] = true;
              if (_currentSessionLog!.forcedReps > 0) _activeIntensifiers["FORCED REPS"] = true;
            }
          } else {
            // LOAD LATEST LOG FOR ACTIVE CYCLE (RESTORE PERSISTENCE)
            if (sessionLogs.isNotEmpty) {
              sessionLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              _currentSessionLog = sessionLogs.first;
              final displayWeight = provider.getWeightForDisplay(_currentSessionLog!);
              _weightController.text = displayWeight > 0 ? double.parse(displayWeight.toStringAsFixed(3)).toString() : "";
              _posRepsController.text = _currentSessionLog!.positiveReps > 0 ? _currentSessionLog!.positiveReps.toString() : "";
              _staticSecsController.text = _currentSessionLog!.staticHoldSeconds > 0 ? _currentSessionLog!.staticHoldSeconds.toString() : "";
              _negRepsController.text = _currentSessionLog!.negativeReps > 0 ? _currentSessionLog!.negativeReps.toString() : "";
              _forcedRepsController.text = _currentSessionLog!.forcedReps > 0 ? _currentSessionLog!.forcedReps.toString() : "";
              _commentController.text = _currentSessionLog!.comment ?? "";
              
              _activeIntensifiers["POSITIVE REPS"] = _currentSessionLog!.positiveReps > 0;
              if (_currentSessionLog!.staticHoldSeconds > 0) _activeIntensifiers["STATIC HOLD"] = true;
              if (_currentSessionLog!.negativeReps > 0) _activeIntensifiers["NEGATIVE REPS"] = true;
              if (_currentSessionLog!.forcedReps > 0) _activeIntensifiers["FORCED REPS"] = true;
            }
          }
          _isInitialLoad = false;
        }

        // Determine "Previous Record" by looking back in the logical hierarchy
        final myIdx = exerciseInstances.indexWhere((e) => e.id == widget.exerciseId);
        ExerciseLog? displayLastLog;
        if (myIdx > 0) {
          for (int i = myIdx - 1; i >= 0; i--) {
            final prevExId = exerciseInstances[i].id;
            final prevLogs = provider.logs.where((l) => l.exerciseId == prevExId).toList();
            if (prevLogs.isNotEmpty) {
              prevLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              displayLastLog = prevLogs.first;
              break;
            }
          }
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: null,
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 8.w),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.exerciseName.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const Opacity(
                        opacity: 0,
                        child: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded), onPressed: null),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.r),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12.h),
                      _buildPreviousRecordCard(displayLastLog),
                      if (displayLastLog != null) _buildProgressionAnalysis(displayLastLog),

                      SizedBox(height: 16.h),
                      _buildSectionHeader("BASE LOAD"),
                      _buildWeightInput(),

                      SizedBox(height: 32.h),
                      _buildSectionHeader("INTENSIFIER SELECTION"),
                      _buildIntensifierGrid(),

                      SizedBox(height: 32.h),
                      _buildSectionHeader("ACTIVE METRICS"),
                      _buildDynamicInputs(),

                      SizedBox(height: 32.h),
                      _buildSectionHeader("OBSERVATIONS & FEEDBACK"),
                      _buildCommentBox(),

                      _buildAutoSaveIndicator(),
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Removed _buildHistoryControls as it's no longer needed

  Widget _buildAutoSaveIndicator() {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 24.h),
        child: Text(
          "DATA AUTOSAVES AS YOU TYPE",
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            letterSpacing: 1.5,
            fontWeight: FontWeight.w400,
            fontSize: 10.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildPreviousRecordCard(ExerciseLog? lastLog) {
    final provider = context.read<CycleProvider>();
    if (lastLog == null) {
      return Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.history, color: AppColors.crimson, size: 24.r),
            SizedBox(width: 16.w),
            Text(
              "NO RECORD AVAILABLE",
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.white, 
                fontStyle: FontStyle.italic,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    List<String> metrics = [];
    if (lastLog.weightKg > 0 || lastLog.weightLbs > 0) {
      final displayWeight = provider.getWeightForDisplay(lastLog);
      final unit = provider.settings.weightUnit == WeightUnit.kgs ? "KGS" : "LBS";
      final String formattedWeight = double.parse(displayWeight.toStringAsFixed(3)).toString();
      metrics.add("$formattedWeight $unit");
    }
    
    if (lastLog.positiveReps > 0) metrics.add("${lastLog.positiveReps} POS");
    if (lastLog.staticHoldSeconds > 0) metrics.add("${lastLog.staticHoldSeconds}s STATIC");
    if (lastLog.negativeReps > 0) metrics.add("${lastLog.negativeReps} NEG");
    if (lastLog.forcedReps > 0) metrics.add("${lastLog.forcedReps} FORCED");

    final double volumeValue = lastLog.weightKg * lastLog.positiveReps;

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: AppColors.crimson, size: 24.r),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PREVIOUS RECORD", 
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10.sp,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                if (metrics.isNotEmpty)
                  Text(
                    metrics.join(' • '),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.white, 
                      fontWeight: FontWeight.w500,
                      fontSize: 14.sp,
                    ),
                  ),
                if (volumeValue > 0)
                  Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Text(
                      "TONNAGE: ${volumeValue.toStringAsFixed(1)} T",
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                        fontSize: 11.sp,
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

  Widget _buildProgressionAnalysis(ExerciseLog lastLog) {
    final provider = context.read<CycleProvider>();
    double? currentWeight = double.tryParse(_weightController.text);
    int? currentReps = int.tryParse(_posRepsController.text);

    double strengthChange = 0.0;
    double volumeChange = 0.0;
    double loadDiff = 0.0;
    int repDiff = 0;
    bool hasAnalysis = false;

    if (currentWeight != null && currentWeight > 0 && currentReps != null && currentReps > 0 && (lastLog.weightKg > 0 || lastLog.weightLbs > 0) && lastLog.positiveReps > 0) {
      final dualWeights = provider.calculateDualWeights(currentWeight);
      final currentKg = dualWeights['kg']!;
      
      final double current1RM = currentKg / (1.0278 - (0.0278 * currentReps));
      final double last1RM = lastLog.weightKg / (1.0278 - (0.0278 * lastLog.positiveReps));
      strengthChange = ((current1RM / last1RM) - 1) * 100;

      final double currentVol = currentKg * currentReps;
      final double lastVol = lastLog.weightKg * lastLog.positiveReps;
      volumeChange = ((currentVol / lastVol) - 1) * 100;

      loadDiff = currentWeight - provider.getWeightForDisplay(lastLog);
      repDiff = currentReps - lastLog.positiveReps;

      hasAnalysis = true;
    }

    if (!hasAnalysis) {
      return Padding(
        padding: EdgeInsets.only(top: 24.h),
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 28.r),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  "ENTER BASE LOAD AND REPS TO ANALYZE PROGRESSION",
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.5), 
                    letterSpacing: 0.5,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("HIT PROGRESSION ANALYSIS"),
          
          Row(
            children: [
              _buildAnalysisCard(
                label: "STRENGTH GAIN",
                value: strengthChange,
                isPercentage: true,
                color: strengthChange >= 0 ? AppColors.success : AppColors.crimson,
                icon: strengthChange >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              ),
              SizedBox(width: 16.w),
              _buildAnalysisCard(
                label: "TONNAGE CHANGE",
                value: volumeChange,
                isPercentage: true,
                color: volumeChange >= 0 ? AppColors.success : AppColors.crimson,
                icon: volumeChange >= 0 ? Icons.stacked_line_chart_rounded : Icons.show_chart_rounded,
                isVolume: true,
              ),
            ],
          ),
          
          SizedBox(height: 16.h),

          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                _buildCompactMetric("LOAD DELTA", loadDiff, provider.settings.weightUnit == WeightUnit.kgs ? "KGS" : "LBS"),
                Container(width: 1, height: 32.h, color: AppColors.white.withValues(alpha: 0.1), margin: EdgeInsets.symmetric(horizontal: 20.w)),
                _buildCompactMetric("REP DELTA", repDiff.toDouble(), "REPS"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard({
    required String label,
    required double value,
    required bool isPercentage,
    required Color color,
    required IconData icon,
    bool isVolume = false,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label, 
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.white, 
                    fontSize: 9.sp, 
                    fontWeight: FontWeight.w500, 
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(icon, color: color, size: 16.r),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              "${value >= 0 ? "+" : ""}${value.toStringAsFixed(1)}${isPercentage ? "%" : ""}",
              style: AppTextStyles.h2.copyWith(
                color: color, 
                fontSize: 24.sp, 
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMetric(String label, double value, String unit) {
    // Use a small epsilon to handle floating point errors from conversion
    final bool isPositive = value > 0.01;
    final bool isNegative = value < -0.01;
    final Color color = isPositive 
        ? AppColors.success 
        : (isNegative ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.5));

    return Expanded(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.white, 
                  fontSize: 9.sp, 
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 4.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    "${isPositive ? "+" : ""}${value.abs() < 0.001 ? "0.0" : double.parse(value.abs().toStringAsFixed(3)).toString()}",
                    style: AppTextStyles.labelMedium.copyWith(
                      color: color, 
                      fontWeight: FontWeight.w900,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    unit, 
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addMetricToProgression(List<Map<String, dynamic>> list, String label, TextEditingController controller, int previousValue) {
    if (_activeIntensifiers[label] == false) return;
    int? current = int.tryParse(controller.text);
    if (previousValue > 0 && current != null && current > 0) {
      int diff = current - previousValue;
      list.add({"label": label, "value": diff.toDouble(), "unit": label == "STATIC HOLD" ? "SEC" : "REPS"});
    }
  }

  Widget _buildCommentBox() {
    return TextField(
      controller: _commentController,
      enabled: true,
      minLines: 3,
      maxLines: null,
      style: AppTextStyles.labelSmall.copyWith(color: AppColors.white),
      decoration: InputDecoration(
        hintText: "DESCRIBE MUSCLE SENSATION, FORM DEGRADATION, OR RECOVERY NOTES...",
        hintStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.crimson)),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
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

  Widget _buildWeightInput() {
    final provider = context.watch<CycleProvider>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextField(
        controller: _weightController,
        enabled: true,
        onChanged: (_) => setState(() {}),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
        ],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppTextStyles.h1.copyWith(color: AppColors.white, fontSize: 28.sp),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          suffixText: provider.settings.weightUnit == WeightUnit.kgs ? "KGS" : "LBS",
          suffixStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildIntensifierGrid() {
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: _activeIntensifiers.keys.map((String key) {
        bool isActive = _activeIntensifiers[key]!;
        return GestureDetector(
          onTap: () => _toggleIntensifier(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isActive ? AppColors.crimson : AppColors.surface,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: isActive ? AppColors.crimson : AppColors.white.withValues(alpha: 0.1)),
            ),
            child: Text(key, style: AppTextStyles.labelSmall.copyWith(color: isActive ? AppColors.white : AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDynamicInputs() {
    final bool anyActive = _activeIntensifiers.values.any((v) => v);
    if (!anyActive) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Text(
          "NO METRICS SELECTED. TOGGLE INTENSIFIERS ABOVE TO TRACK DATA.",
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Column(
      children: [
        if (_activeIntensifiers["POSITIVE REPS"]!) _buildMetricField("POSITIVE REPS", _posRepsController, "REPS"),
        if (_activeIntensifiers["STATIC HOLD"]!) _buildMetricField("STATIC HOLD", _staticSecsController, "SECONDS"),
        if (_activeIntensifiers["NEGATIVE REPS"]!) _buildMetricField("NEGATIVE REPS", _negRepsController, "REPS"),
        if (_activeIntensifiers["FORCED REPS"]!) _buildMetricField("FORCED REPS", _forcedRepsController, "REPS"),
      ],
    );
  }

  Widget _buildMetricField(String label, TextEditingController controller, String unit) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        bool hasValue = controller.text.isNotEmpty;
        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text(label, style: AppTextStyles.labelMedium.copyWith(color: hasValue ? AppColors.white : AppColors.textSecondary))),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: true,
                  onChanged: (_) => setState(() {}),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: hasValue ? AppColors.white : AppColors.white.withValues(alpha: 0.4), 
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 1.0,
                    fontSize: 22.sp,
                  ),
                  decoration: InputDecoration(
                    hintText: "0",
                    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.2)),
                    suffixIcon: Padding(
                      padding: EdgeInsets.only(left: 8.w),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(unit, style: AppTextStyles.labelSmall.copyWith(color: hasValue ? AppColors.crimson : AppColors.white.withValues(alpha: 0.3), fontWeight: FontWeight.w900, fontSize: 10.sp)),
                      ]),
                    ),
                    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: hasValue ? AppColors.white.withValues(alpha: 0.5) : Colors.white10)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.white, width: 2)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
