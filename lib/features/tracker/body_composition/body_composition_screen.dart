import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/body_composition/model/body_comp_log.dart';
import 'package:heavy_duty/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:heavy_duty/features/tracker/body_composition/widgets/body_comp_graph.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/model/cycle_settings.dart'; // For WeightUnit
import 'package:heavy_duty/core/constants/dimensions.dart';
import '../../main_wrapper.dart';

class BodyCompositionScreen extends StatefulWidget {
  const BodyCompositionScreen({super.key});

  @override
  State<BodyCompositionScreen> createState() => _BodyCompositionScreenState();
}

class _BodyCompositionScreenState extends State<BodyCompositionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  final Set<String> _visibleMetrics = {"weight", "fat", "muscle"};
  final Set<String> _entryMetrics = {"weight"};

  int? _comparisonIdx1;
  int? _comparisonIdx2;

  DateTime _selectedHistoryDate = DateTime.now();
  DateTime _displayedMonth = DateTime.now();
  bool _isCalendarExpanded = false;

  DateTime _selectedLogDate = DateTime.now();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _muscleController = TextEditingController();

  BodyMetricUnit _fatUnit = BodyMetricUnit.percentage;
  BodyMetricUnit _muscleUnit = BodyMetricUnit.kg;

  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "body_comp";
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController(
      viewportFraction: 0.2,
      initialPage: 0,
    );
    _displayedMonth = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month);
    
    // Add listener to weight controller to dynamically enable/disable other fields
    _weightController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    activeSettingsContext.value = "";
    _tabController.dispose();
    _pageController.dispose();
    _weightController.dispose();
    _fatController.dispose();
    _muscleController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedLogDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => child!,
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedLogDate),
        builder: (context, child) => child!,
      );

      if (pickedTime != null) {
        setState(() {
          _selectedLogDate = DateTime(
            pickedDate.year, pickedDate.month, pickedDate.day,
            pickedTime.hour, pickedTime.minute,
          );
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isCompact = width < kMobileBreakpoint;
        final double hPad = !isCompact
            ? (width - kMaxContentWidth).clamp(24.0, double.infinity) / 2
            : 8.w;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: isCompact ? 24.h : 20.0),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: AppColors.white,
                                size: isCompact ? 24.r : 20.0,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                'BODY COMPOSITION',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.h2.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: isCompact ? 20.sp : 18.0,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.info_outline_rounded,
                                color: Colors.transparent, // Keeping for alignment symmetry
                                size: isCompact ? 24.r : 20.0,
                              ),
                              onPressed: null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.crimson,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                        fontSize: isCompact ? 11.sp : 9.0,
                      ),
                      unselectedLabelColor: AppColors.textSecondary,
                      labelColor: AppColors.crimson,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: "TRACKER"),
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
                    _buildTrackerTab(isCompact),
                    _buildRecordsTab(isCompact),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackerTab(bool isCompact) {
    return Consumer<BodyCompProvider>(
      builder: (context, provider, _) {
        final bool hasData = provider.logs.isNotEmpty;

        final List<BodyCompLog> sortedLogs = hasData 
            ? (List.from(provider.logs)..sort((a, b) => a.timestamp.compareTo(b.timestamp)))
            : [];
        final Set<DateTime> moments = sortedLogs.map((l) => l.timestamp).toSet();
        final List<DateTime> sortedMoments = moments.toList()..sort();

        final Map<String, List<double?>> aggregatedData = {
          "weight": [],
          "fat": [],
          "muscle": [],
        };

        if (hasData) {
          double lastKnownWeight = 0;
          for (var ts in sortedMoments) {
            final momentLogs = sortedLogs.where((l) => l.timestamp.isAtSameMomentAs(ts)).toList();
            
            final weightLog = momentLogs.firstWhere((l) => l.type == BodyMetricType.weight, orElse: () => BodyCompLog(valueKg: -1, valueLbs: -1, type: BodyMetricType.weight, unit: BodyMetricUnit.kg, timestamp: DateTime.now()));
            if (weightLog.valueKg != -1) {
              lastKnownWeight = provider.getDisplayValue(weightLog);
              aggregatedData["weight"]!.add(lastKnownWeight);
            } else {
              aggregatedData["weight"]!.add(lastKnownWeight > 0 ? lastKnownWeight : null);
            }

            for (var typeKey in ["fat", "muscle"]) {
              final log = momentLogs.firstWhere((l) => l.type.name == typeKey, orElse: () => BodyCompLog(valueKg: -1, valueLbs: -1, type: BodyMetricType.weight, unit: BodyMetricUnit.kg, timestamp: DateTime.now()));
              if (log.valueKg != -1) {
                 if (log.unit != BodyMetricUnit.percentage) {
                   aggregatedData[typeKey]!.add(provider.getDisplayValue(log));
                 } else {
                   aggregatedData[typeKey]!.add(lastKnownWeight > 0 ? (log.valueKg / 100) * lastKnownWeight : null);
                 }
              } else {
                aggregatedData[typeKey]!.add(null);
              }
            }
          }
        }

        return RefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 700;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- LEFT COLUMN: TRENDS & OVERLAY ---
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader("PROGRESS TREND", isCompact),
                            SizedBox(height: isCompact ? 24.h : 20.0),
                            if (hasData)
                              BodyCompGraph(
                                dates: sortedMoments,
                                data: aggregatedData,
                                visibleMetrics: _visibleMetrics,
                                onPointSelected: (idx) {},
                                isCompact: isCompact,
                              )
                            else
                              _buildEmptyTrendState(isCompact),
                            SizedBox(height: isCompact ? 32.h : 24.0),
                            _buildSectionHeader("METRIC OVERLAY", isCompact),
                            SizedBox(height: isCompact ? 16.h : 12.0),
                            Wrap(
                              spacing: isCompact ? 10.w : 10.0,
                              runSpacing: isCompact ? 10.h : 10.0,
                              children: [
                                _buildMetricToggle("WEIGHT", "weight", Colors.tealAccent, isCompact, enabled: hasData),
                                _buildMetricToggle("FAT", "fat", Colors.redAccent, isCompact, enabled: hasData),
                                _buildMetricToggle("MUSCLE", "muscle", Colors.lightGreenAccent, isCompact, enabled: hasData),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    VerticalDivider(color: AppColors.white.withValues(alpha : 0.05), width: 1),
                    // --- RIGHT COLUMN: COMPARISON & ENTRY ---
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader("DATA COMPARISON", isCompact),
                            SizedBox(height: isCompact ? 16.h : 12.0),
                            if (hasData)
                              BodyCompComparisonWidget(
                                idx1: _comparisonIdx1,
                                idx2: _comparisonIdx2,
                                dates: sortedMoments,
                                data: aggregatedData,
                                isCompact: isCompact,
                                onPointAChanged: (val) => setState(() => _comparisonIdx1 = val),
                                onPointBChanged: (val) => setState(() => _comparisonIdx2 = val),
                              )
                            else
                              _buildEmptyComparisonState(isCompact),
                            SizedBox(height: isCompact ? 40.h : 32.0),
                            _buildSectionHeader('LOG NEW DATA', isCompact),
                            SizedBox(height: isCompact ? 16.h : 12.0),
                            _buildEntryCard(provider, isCompact),
                            SizedBox(height: 40.h),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              // --- MOBILE: SINGLE COLUMN ---
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.r : 20.0, vertical: isCompact ? 12.h : 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("PROGRESS TREND", isCompact),
                    SizedBox(height: isCompact ? 24.h : 20.0),
                    if (hasData)
                      BodyCompGraph(
                        dates: sortedMoments,
                        data: aggregatedData,
                        visibleMetrics: _visibleMetrics,
                        onPointSelected: (idx) {},
                        isCompact: isCompact,
                      )
                    else
                      _buildEmptyTrendState(isCompact),
                    SizedBox(height: isCompact ? 32.h : 24.0),
                    _buildSectionHeader("METRIC OVERLAY", isCompact),
                    SizedBox(height: isCompact ? 16.h : 12.0),
                    Wrap(
                      spacing: isCompact ? 10.w : 10.0,
                      runSpacing: isCompact ? 10.h : 10.0,
                      children: [
                        _buildMetricToggle("WEIGHT", "weight", Colors.tealAccent, isCompact, enabled: hasData),
                        _buildMetricToggle("FAT", "fat", Colors.redAccent, isCompact, enabled: hasData),
                        _buildMetricToggle("MUSCLE", "muscle", Colors.lightGreenAccent, isCompact, enabled: hasData),
                      ],
                    ),
                    SizedBox(height: isCompact ? 40.h : 32.0),
                    _buildSectionHeader("DATA COMPARISON", isCompact),
                    SizedBox(height: isCompact ? 16.h : 12.0),
                    if (hasData)
                      BodyCompComparisonWidget(
                        idx1: _comparisonIdx1,
                        idx2: _comparisonIdx2,
                        dates: sortedMoments,
                        data: aggregatedData,
                        isCompact: isCompact,
                        onPointAChanged: (val) => setState(() => _comparisonIdx1 = val),
                        onPointBChanged: (val) => setState(() => _comparisonIdx2 = val),
                      )
                    else
                      _buildEmptyComparisonState(isCompact),
                    SizedBox(height: isCompact ? 40.h : 32.0),
                    _buildSectionHeader('LOG NEW DATA', isCompact),
                    SizedBox(height: isCompact ? 16.h : 12.0),
                    _buildEntryCard(provider, isCompact),
                    SizedBox(height: 40.h),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyTrendState(bool isCompact) {
    return SizedBox(
      height: isCompact ? 240.h : 200.0,
      width: double.infinity,
      child: Center(
        child: Text(
          "LOG DATA TO SEE TRENDS",
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.3),
            letterSpacing: 1.5,
            fontSize: isCompact ? 10.sp : 12.0,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyComparisonState(bool isCompact) {
    return Container(
      height: isCompact ? 100.h : 80.0,
      width: double.infinity,
      alignment: Alignment.center,
      child: Text(
        "NO POINTS TO COMPARE YET",
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.2),
          letterSpacing: 1.0,
          fontSize: isCompact ? 10.sp : 12.0,
        ),
      ),
    );
  }

  Widget _buildMetricToggle(String label, String key, Color color, bool isCompact, {bool enabled = true}) {
    final bool isActive = _visibleMetrics.contains(key);
    return GestureDetector(
      onTap: !enabled ? null : () {
        setState(() {
          if (_visibleMetrics.contains(key)) {
            _visibleMetrics.remove(key);
          } else {
            _visibleMetrics.add(key);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 12.0, vertical: isCompact ? 10.h : 8.0),
        decoration: BoxDecoration(
          color: isActive && enabled ? color.withValues(alpha : 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          border: Border.all(
            color: isActive && enabled ? color : AppColors.white.withValues(alpha : 0.05),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isCompact ? 8.r : 6.0,
              height: isCompact ? 8.r : 6.0,
              decoration: BoxDecoration(
                color: isActive && enabled ? color : AppColors.textSecondary.withValues(alpha : 0.3),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: isCompact ? 10.w : 8.0),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: enabled ? (isActive ? AppColors.white : AppColors.textSecondary) : AppColors.textSecondary.withValues(alpha : 0.2),
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
                fontSize: isCompact ? 10.sp : 12.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isCompact) {
    return Row(
      children: [
        Container(
          width: 2.5,
          height: isCompact ? 12.h : 10.0,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: isCompact ? 8.w : 6.0),
        Text(
          title,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontSize: isCompact ? 11.sp : 12.0,
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(BodyCompProvider provider, bool isCompact) {
    String formattedTime = DateFormat('MMM dd, hh:mm a').format(_selectedLogDate);
    return Container(
      padding: EdgeInsets.all(isCompact ? 18.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickDateTime,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date & Time', style: AppTextStyles.labelMedium.copyWith(fontSize: isCompact ? 12.sp : 10.0)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 10.w : 8.0, vertical: isCompact ? 5.h : 4.0),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    children: [
                      Text(formattedTime, style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontSize: isCompact ? 10.sp : 8.0)),
                      SizedBox(width: 6.w),
                      Icon(Icons.calendar_month_rounded, size: isCompact ? 12.r : 10.0, color: AppColors.crimson),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.white.withValues(alpha: 0.03), height: isCompact ? 24.h : 20.0),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEntryMetricToggle("WEIGHT", "weight", isCompact),
              _buildEntryMetricToggle("BODY FAT", "fat", isCompact),
              _buildEntryMetricToggle("MUSCLE", "muscle", isCompact),
            ],
          ),
          
          if (_entryMetrics.isNotEmpty) ...[
            SizedBox(height: isCompact ? 12.h : 10.0),
            Divider(color: AppColors.white.withValues(alpha: 0.03), height: isCompact ? 24.h : 20.0),
            if (_entryMetrics.contains("weight")) _buildInputRow('Weight', provider.settings.weightUnit == WeightUnit.kgs ? 'kg' : 'lbs', _weightController, isCompact),
            if (_entryMetrics.contains("weight") && (_entryMetrics.contains("fat") || _entryMetrics.contains("muscle")))
              Divider(color: AppColors.white.withValues(alpha: 0.03), height: isCompact ? 24.h : 20.0),
            
            if (_entryMetrics.contains("fat")) 
              _buildInputRow(
                'Body Fat', 
                _fatUnit == BodyMetricUnit.percentage ? '%' : (provider.settings.weightUnit == WeightUnit.kgs ? 'kg' : 'lbs'), 
                _fatController, 
                isCompact,
                enabled: _weightController.text.trim().isNotEmpty,
                onUnitToggle: () {
                  setState(() => _fatUnit = _fatUnit == BodyMetricUnit.kg ? BodyMetricUnit.percentage : BodyMetricUnit.kg);
                }
              ),
              
            if (_entryMetrics.contains("fat") && _entryMetrics.contains("muscle"))
              Divider(color: AppColors.white.withValues(alpha: 0.03), height: isCompact ? 24.h : 20.0),
              
            if (_entryMetrics.contains("muscle")) 
              _buildInputRow(
                'Muscle Mass', 
                _muscleUnit == BodyMetricUnit.percentage ? '%' : (provider.settings.weightUnit == WeightUnit.kgs ? 'kg' : 'lbs'), 
                _muscleController, 
                isCompact,
                enabled: _weightController.text.trim().isNotEmpty,
                onUnitToggle: () {
                  setState(() => _muscleUnit = _muscleUnit == BodyMetricUnit.kg ? BodyMetricUnit.percentage : BodyMetricUnit.kg);
                }
              ),
          ] else ...[
             Padding(
               padding: EdgeInsets.symmetric(vertical: isCompact ? 24.h : 20.0),
               child: Text(
                 "SELECT METRICS TO RECORD",
                 style: AppTextStyles.labelSmall.copyWith(
                   color: AppColors.textSecondary.withValues(alpha : 0.3),
                   letterSpacing: 1,
                   fontSize: isCompact ? 10.sp : 9.0,
                 ),
               ),
             ),
          ],

          SizedBox(height: isCompact ? 20.h : 16.0),
          GestureDetector(
            onTap: (_entryMetrics.isEmpty || _weightController.text.trim().isEmpty) ? null : () async {
              final w = _entryMetrics.contains("weight") ? (double.tryParse(_weightController.text) ?? 0.0) : 0.0;
              final f = _entryMetrics.contains("fat") ? (double.tryParse(_fatController.text) ?? 0.0) : 0.0;
              final m = _entryMetrics.contains("muscle") ? (double.tryParse(_muscleController.text) ?? 0.0) : 0.0;
              
              if (w == 0 && f == 0 && m == 0) {
                if (mounted) {
                  EliteSnackbar.show(context, "Please enter a value for the selected metrics", isError: true);
                }
                return;
              }

              // Handle Replacement Logic: Check if a log with same minute exists
              final existingLogs = provider.logs.where((l) {
                return l.timestamp.year == _selectedLogDate.year &&
                       l.timestamp.month == _selectedLogDate.month &&
                       l.timestamp.day == _selectedLogDate.day &&
                       l.timestamp.hour == _selectedLogDate.hour &&
                       l.timestamp.minute == _selectedLogDate.minute;
              }).toList();
              
              if (_entryMetrics.contains("weight") && w > 0) {
                final existing = existingLogs.cast<BodyCompLog?>().firstWhere((l) => l?.type == BodyMetricType.weight, orElse: () => null);
                if (existing != null) await provider.deleteLog(existing.id, existing.type);
                final dual = provider.calculateDualValues(w, BodyMetricUnit.kg);
                await provider.addLog(BodyCompLog(valueKg: dual['kg']!, valueLbs: dual['lbs']!, type: BodyMetricType.weight, unit: BodyMetricUnit.kg, timestamp: _selectedLogDate));
              }
              if (_entryMetrics.contains("fat") && f > 0) {
                final existing = existingLogs.cast<BodyCompLog?>().firstWhere((l) => l?.type == BodyMetricType.fat, orElse: () => null);
                if (existing != null) await provider.deleteLog(existing.id, existing.type);
                final dual = provider.calculateDualValues(f, _fatUnit);
                await provider.addLog(BodyCompLog(valueKg: dual['kg']!, valueLbs: dual['lbs']!, type: BodyMetricType.fat, unit: _fatUnit, timestamp: _selectedLogDate));
              }
              if (_entryMetrics.contains("muscle") && m > 0) {
                final existing = existingLogs.cast<BodyCompLog?>().firstWhere((l) => l?.type == BodyMetricType.muscle, orElse: () => null);
                if (existing != null) await provider.deleteLog(existing.id, existing.type);
                final dual = provider.calculateDualValues(m, _muscleUnit);
                await provider.addLog(BodyCompLog(valueKg: dual['kg']!, valueLbs: dual['lbs']!, type: BodyMetricType.muscle, unit: _muscleUnit, timestamp: _selectedLogDate));
              }

              _weightController.clear();
              _fatController.clear();
              _muscleController.clear();
              if (mounted) {
                EliteSnackbar.show(context, "Body composition recorded!");
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: isCompact ? 48.h : 44.0,
              width: double.infinity,
              decoration: BoxDecoration(
                color: (_entryMetrics.isEmpty || _weightController.text.trim().isEmpty) 
                    ? AppColors.white.withValues(alpha : 0.05) 
                    : AppColors.crimson, 
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
              ),
              alignment: Alignment.center,
              child: Text(
                _weightController.text.trim().isEmpty 
                    ? 'ADD WEIGHT TO SAVE ENTRY'
                    : (_entryMetrics.isEmpty ? 'SELECT A METRIC' : 'SAVE ENTRY'), 
                style: AppTextStyles.buttonPrimary.copyWith(
                  fontSize: isCompact ? 12.sp : 11.0,
                  color: (_entryMetrics.isEmpty || _weightController.text.trim().isEmpty) 
                      ? AppColors.textSecondary.withValues(alpha : 0.3) 
                      : Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryMetricToggle(String label, String key, bool isCompact) {
    final bool isSelected = _entryMetrics.contains(key);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _entryMetrics.remove(key);
          } else {
            _entryMetrics.add(key);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 12.w : 10.0, vertical: isCompact ? 8.h : 6.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson.withValues(alpha : 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0),
          border: Border.all(
            color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha : 0.05),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isSelected ? AppColors.white : AppColors.textSecondary.withValues(alpha : 0.4),
            fontSize: isCompact ? 9.sp : 8.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow(String label, String currentUnit, TextEditingController controller, bool isCompact, {VoidCallback? onUnitToggle, bool enabled = true}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1.0 : 0.3,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isCompact ? 4.h : 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.labelMedium.copyWith(fontSize: isCompact ? 13.sp : 11.0, color: AppColors.white.withValues(alpha : 0.9))),
            Row(
              children: [
                SizedBox(
                  width: isCompact ? 70.w : 50.0,
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                    ],
                    textAlign: TextAlign.end,
                    style: AppTextStyles.h3.copyWith(fontSize: isCompact ? 18.sp : 14.0, color: AppColors.white),
                    decoration: InputDecoration(
                      hintText: enabled ? ' ' : '---',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 4.h : 4.0),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      disabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.crimson)),
                    ),
                  ),
                ),
                SizedBox(width: isCompact ? 16.w : 12.0),
                if (onUnitToggle != null)
                  IgnorePointer(
                    ignoring: !enabled,
                    child: _buildUnitToggle(currentUnit, onUnitToggle, isCompact),
                  )
                else
                  Container(
                    width: isCompact ? 40.w : 36.0,
                    alignment: Alignment.center,
                    child: Text(
                      currentUnit,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: isCompact ? 10.sp : 8.0),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitToggle(String currentUnit, VoidCallback onToggle, bool isCompact) {
    final bool isPercentage = currentUnit == "%";
    final provider = context.read<BodyCompProvider>();
    final String massUnit = provider.settings.weightUnit == WeightUnit.kgs ? "kg" : "lbs";

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.white.withValues(alpha : 0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildUnitChip(massUnit, !isPercentage, isCompact),
            _buildUnitChip("%", isPercentage, isCompact),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitChip(String label, bool isSelected, bool isCompact) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.w : 6.0, vertical: isCompact ? 4.h : 4.0),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.crimson : Colors.transparent,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontSize: isCompact ? 10.sp : 8.0,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRecordsTab(bool isCompact) {
    return Consumer<BodyCompProvider>(
      builder: (context, provider, _) {
        final Set<DateTime> dateSet = provider.logs.map((l) => 
          DateTime(l.timestamp.year, l.timestamp.month, l.timestamp.day)
        ).toSet();
        
        final now = DateTime.now();
        dateSet.add(DateTime(now.year, now.month, now.day));
        
        final historyLogs = provider.logs.where((l) {
          return l.timestamp.year == _selectedHistoryDate.year &&
              l.timestamp.month == _selectedHistoryDate.month &&
              l.timestamp.day == _selectedHistoryDate.day;
        }).toList();

        historyLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth > 700;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT COLUMN: CALENDAR (TAKES WHOLE SPACE) ---
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: AppColors.background,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 20.0),
                              child: _buildCustomExpandedCalendar(dateSet, isCompact),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  VerticalDivider(color: AppColors.white.withValues(alpha : 0.05), width: 1),
                  // --- RIGHT COLUMN: SLIDER + LOGS ---
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildHorizontalCalendar(dateSet, isCompact),
                        const Divider(color: Colors.white10, height: 1),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(20.0),
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            children: [
                              if (historyLogs.isNotEmpty) ...[
                                _buildSectionHeader("LOGGED METRICS", isCompact),
                                SizedBox(height: 20.0),
                                Column(
                                  children: historyLogs.map((log) => _buildRecordCard(log, provider, isCompact)).toList(),
                                ),
                              ] else
                                SizedBox(
                                  height: 400,
                                  child: Center(
                                    child: Text(
                                      "No logs for this date.",
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: isCompact ? 13.sp : 11.0,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // --- MOBILE: SINGLE COLUMN ---
            if (_isCalendarExpanded) {
              return Container(
                color: AppColors.background,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildCustomExpandedCalendar(dateSet, isCompact),
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
                _buildHorizontalCalendar(dateSet, isCompact),
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
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    children: [
                      if (historyLogs.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                          child: _buildSectionHeader("LOGGED METRICS", isCompact),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Column(
                            children: historyLogs.map((log) => _buildRecordCard(log, provider, isCompact)).toList(),
                          ),
                        ),
                      ] else
                        SizedBox(
                          height: 300.h,
                          child: Center(
                            child: Text(
                              "No logs for this date.",
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 12.sp),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRecordCard(BodyCompLog log, BodyCompProvider provider, bool isCompact) {
    Color metricColor;
    IconData metricIcon;
    String label;
    String unit = provider.getDisplayUnit(log);

    switch (log.type) {
      case BodyMetricType.weight:
        metricColor = Colors.tealAccent;
        metricIcon = Icons.monitor_weight_outlined;
        label = "WEIGHT";
        break;
      case BodyMetricType.fat:
        metricColor = Colors.redAccent;
        metricIcon = Icons.percent_rounded;
        label = "BODY FAT";
        break;
      case BodyMetricType.muscle:
        metricColor = Colors.lightGreenAccent;
        metricIcon = Icons.fitness_center_rounded;
        label = "MUSCLE MASS";
        break;
    }

    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await EliteConfirmDialog.show(
          context,
          title: "DELETE LOG",
          message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THIS $label ENTRY FROM YOUR LOGS?",
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: isCompact ? 24.w : 20.0),
        margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        ),
        child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: isCompact ? 28.r : 24.0),
      ),
      onDismissed: (_) => provider.deleteLog(log.id, log.type),
      child: Container(
        margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
        padding: EdgeInsets.all(isCompact ? 16.r : 14.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.03)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 10.r : 8.0),
                  decoration: BoxDecoration(
                    color: metricColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(metricIcon, color: metricColor, size: isCompact ? 20.r : 18.0),
                ),
                SizedBox(width: isCompact ? 16.w : 12.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                        fontSize: isCompact ? 11.sp : 9.0,
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(log.timestamp),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                        fontSize: isCompact ? 10.sp : 8.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  double.parse(provider.getDisplayValue(log).toStringAsFixed(3)).toString(),
                  style: AppTextStyles.h3.copyWith(fontSize: isCompact ? 20.sp : 15.0, color: Colors.white),
                ),
                SizedBox(width: 4.w),
                Text(
                  unit,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: isCompact ? 11.sp : 8.0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomExpandedCalendar(Set<DateTime> dateSet, bool isCompact) {
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    final isCurrentMonth = _displayedMonth.year == DateTime.now().year && _displayedMonth.month == DateTime.now().month;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 16.0, vertical: isCompact ? 10.h : 8.0),
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
                      _selectedHistoryDate = picked;
                      _displayedMonth = DateTime(picked.year, picked.month);
                    });
                  }
                },
                child: Text(
                  DateFormat('MMMM yyyy').format(_displayedMonth).toUpperCase(),
                  style: AppTextStyles.labelMedium.copyWith(color: Colors.white, letterSpacing: 1.5, fontSize: isCompact ? 14.sp : 12.0),
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
          SizedBox(height: isCompact ? 10.h : 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["M", "T", "W", "T", "F", "S", "S"].map((d) => Expanded(
              child: Text(d, textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: isCompact ? 11.sp : 10.0)),
            )).toList(),
          ),
          SizedBox(height: isCompact ? 10.h : 8.0),
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
                    color: isSelected ? AppColors.crimson : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected 
                        ? Border.all(color: AppColors.crimson.withValues(alpha: 0.5))
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
                              : (isFuture ? Colors.white.withValues(alpha: 0.05) : (hasData ? Colors.white : Colors.white.withValues(alpha: 0.2))),
                          fontWeight: FontWeight.w500,
                          fontSize: isCompact ? 12.sp : 12.0,
                        ),
                      ),
                      if (hasData && !isSelected)
                        Positioned(
                          bottom: isCompact ? 4.h : 4.0,
                          child: Container(
                            width: isCompact ? 3.r : 3.0,
                            height: isCompact ? 3.r : 3.0,
                            decoration: const BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle),
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

  Widget _buildHorizontalCalendar(Set<DateTime> dateSet, bool isCompact) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      height: isCompact ? 90.h : 80.0,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 10.h : 8.0),
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
              margin: EdgeInsets.symmetric(horizontal: isCompact ? 6.w : 6.0),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.crimson : Colors.transparent,
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                border: isToday && !isSelected 
                    ? Border.all(color: AppColors.crimson.withValues(alpha: 0.5))
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(dateOnly).toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: isCompact ? 10.sp : 10.0,
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.2)),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isCompact ? 4.h : 4.0),
                  Text(
                    dateOnly.day.toString(),
                    style: AppTextStyles.h3.copyWith(
                      fontSize: isCompact ? 18.sp : 16.0,
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.white : AppColors.white.withValues(alpha: 0.15)),
                    ),
                  ),
                  if (hasData && !isSelected)
                    Container(
                      margin: EdgeInsets.only(top: isCompact ? 4.h : 4.0),
                      width: isCompact ? 4.r : 4.0,
                      height: isCompact ? 4.r : 4.0,
                      decoration: const BoxDecoration(
                        color: AppColors.crimson,
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
}
