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

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedLogDate),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8.w, 16.h, 8.w, 8.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IntrinsicHeight(
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
                          'BODY COMPOSITION',
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
                          icon: Icon(Icons.history_rounded),
                          onPressed: null,
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.crimson,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                  unselectedLabelColor: AppColors.textSecondary,
                  labelColor: AppColors.crimson,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: "TRACKER"),
                    Tab(text: "RECORDS"),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTrackerTab(),
                _buildRecordsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerTab() {
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
            
            final weightLog = momentLogs.firstWhere((l) => l.type == BodyMetricType.weight, orElse: () => BodyCompLog(value: -1, type: BodyMetricType.weight));
            if (weightLog.value != -1) {
              lastKnownWeight = weightLog.value;
              aggregatedData["weight"]!.add(lastKnownWeight);
            } else {
              aggregatedData["weight"]!.add(lastKnownWeight > 0 ? lastKnownWeight : null);
            }

            for (var typeKey in ["fat", "muscle"]) {
              final log = momentLogs.firstWhere((l) => l.type.name == typeKey, orElse: () => BodyCompLog(value: -1, type: BodyMetricType.weight));
              if (log.value != -1) {
                 if (log.unit == BodyMetricUnit.kg) {
                   aggregatedData[typeKey]!.add(log.value);
                 } else {
                   aggregatedData[typeKey]!.add(lastKnownWeight > 0 ? (log.value / 100) * lastKnownWeight : null);
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 24.r, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("PROGRESS TREND"),
                SizedBox(height: 24.h),
                if (hasData)
                  BodyCompGraph(
                    dates: sortedMoments,
                    data: aggregatedData,
                    visibleMetrics: _visibleMetrics,
                    onPointSelected: (idx) {},
                  )
                else
                  SizedBox(
                    height: 240.h,
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        "RECORD DATA TO SEE TRENDS",
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                
                SizedBox(height: 32.h),
                _buildSectionHeader("METRIC OVERLAY"),
                SizedBox(height: 16.h),
                Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  children: [
                    _buildMetricToggle("WEIGHT", "weight", Colors.tealAccent, enabled: hasData),
                    _buildMetricToggle("FAT", "fat", Colors.redAccent, enabled: hasData),
                    _buildMetricToggle("MUSCLE", "muscle", Colors.lightGreenAccent, enabled: hasData),
                  ],
                ),
                
                SizedBox(height: 40.h),
                _buildSectionHeader("DATA COMPARISON"),
                SizedBox(height: 16.h),
                if (hasData)
                  BodyCompComparisonWidget(
                    idx1: _comparisonIdx1,
                    idx2: _comparisonIdx2,
                    dates: sortedMoments,
                    data: aggregatedData,
                    onPointAChanged: (val) => setState(() => _comparisonIdx1 = val),
                    onPointBChanged: (val) => setState(() => _comparisonIdx2 = val),
                  )
                else
                  Container(
                    height: 100.h,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Text(
                      "NO POINTS TO COMPARE YET",
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary.withValues(alpha: 0.2),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  
                SizedBox(height: 40.h),
                _buildSectionHeader('LOG NEW DATA'),
                SizedBox(height: 16.h),
                _buildEntryCard(provider),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricToggle(String label, String key, Color color, {bool enabled = true}) {
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
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isActive && enabled ? color.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isActive && enabled ? color : AppColors.white.withOpacity(0.05),
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
                color: isActive && enabled ? color : AppColors.textSecondary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: enabled ? (isActive ? AppColors.white : AppColors.textSecondary) : AppColors.textSecondary.withOpacity(0.2),
                fontWeight: isActive && enabled ? FontWeight.w900 : FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
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
    );
  }

  Widget _buildEntryCard(BodyCompProvider provider) {
    String formattedTime = DateFormat('MMM dd, hh:mm a').format(_selectedLogDate);
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickDateTime,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date & Time', style: AppTextStyles.labelMedium.copyWith(fontSize: 12.sp)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    children: [
                      Text(formattedTime, style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontSize: 10.sp)),
                      SizedBox(width: 6.w),
                      Icon(Icons.calendar_month_rounded, size: 12.r, color: AppColors.crimson),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.white.withValues(alpha: 0.03), height: 24.h),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEntryMetricToggle("WEIGHT", "weight"),
              _buildEntryMetricToggle("BODY FAT", "fat"),
              _buildEntryMetricToggle("MUSCLE", "muscle"),
            ],
          ),
          
          if (_entryMetrics.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Divider(color: AppColors.white.withValues(alpha: 0.03), height: 24.h),
            if (_entryMetrics.contains("weight")) _buildInputRow('Weight', 'kg', _weightController),
            if (_entryMetrics.contains("weight") && (_entryMetrics.contains("fat") || _entryMetrics.contains("muscle")))
              Divider(color: AppColors.white.withValues(alpha: 0.03), height: 24.h),
            if (_entryMetrics.contains("fat")) _buildInputRow('Body Fat', _fatUnit == BodyMetricUnit.kg ? 'kg' : '%', _fatController, onUnitToggle: () {
              setState(() => _fatUnit = _fatUnit == BodyMetricUnit.kg ? BodyMetricUnit.percentage : BodyMetricUnit.kg);
            }),
            if (_entryMetrics.contains("fat") && _entryMetrics.contains("muscle"))
              Divider(color: AppColors.white.withValues(alpha: 0.03), height: 24.h),
            if (_entryMetrics.contains("muscle")) _buildInputRow('Muscle Mass', _muscleUnit == BodyMetricUnit.kg ? 'kg' : '%', _muscleController, onUnitToggle: () {
              setState(() => _muscleUnit = _muscleUnit == BodyMetricUnit.kg ? BodyMetricUnit.percentage : BodyMetricUnit.kg);
            }),
          ] else ...[
             Padding(
               padding: EdgeInsets.symmetric(vertical: 24.h),
               child: Text(
                 "SELECT METRICS TO RECORD",
                 style: AppTextStyles.labelSmall.copyWith(
                   color: AppColors.textSecondary.withOpacity(0.3),
                   letterSpacing: 1,
                 ),
               ),
             ),
          ],

          SizedBox(height: 20.h),
          GestureDetector(
            onTap: _entryMetrics.isEmpty ? null : () async {
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
                await provider.addLog(BodyCompLog(value: w, type: BodyMetricType.weight, unit: BodyMetricUnit.kg, timestamp: _selectedLogDate));
              }
              if (_entryMetrics.contains("fat") && f > 0) {
                final existing = existingLogs.cast<BodyCompLog?>().firstWhere((l) => l?.type == BodyMetricType.fat, orElse: () => null);
                if (existing != null) await provider.deleteLog(existing.id, existing.type);
                await provider.addLog(BodyCompLog(value: f, type: BodyMetricType.fat, unit: _fatUnit, timestamp: _selectedLogDate));
              }
              if (_entryMetrics.contains("muscle") && m > 0) {
                final existing = existingLogs.cast<BodyCompLog?>().firstWhere((l) => l?.type == BodyMetricType.muscle, orElse: () => null);
                if (existing != null) await provider.deleteLog(existing.id, existing.type);
                await provider.addLog(BodyCompLog(value: m, type: BodyMetricType.muscle, unit: _muscleUnit, timestamp: _selectedLogDate));
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
              height: 48.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _entryMetrics.isEmpty ? AppColors.white.withOpacity(0.05) : AppColors.crimson, 
                borderRadius: BorderRadius.circular(12.r),
              ),
              alignment: Alignment.center,
              child: Text(
                _entryMetrics.isEmpty ? 'SELECT A METRIC' : 'SAVE ENTRY', 
                style: AppTextStyles.buttonPrimary.copyWith(
                  fontSize: 12.sp,
                  color: _entryMetrics.isEmpty ? AppColors.textSecondary.withOpacity(0.3) : Colors.white,
                  fontWeight: _entryMetrics.isEmpty ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryMetricToggle(String label, String key) {
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
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? AppColors.crimson : AppColors.white.withOpacity(0.05),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isSelected ? AppColors.white : AppColors.textSecondary.withOpacity(0.4),
            fontSize: 9.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow(String label, String currentUnit, TextEditingController controller, {VoidCallback? onUnitToggle}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.labelMedium.copyWith(fontSize: 13.sp, color: AppColors.white.withOpacity(0.9))),
          Row(
            children: [
              SizedBox(
                width: 70.w,
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final text = newValue.text;
                      if (text.isEmpty) return newValue;
                      if (RegExp(r'^\d{0,3}(\.\d{0,3})?$').hasMatch(text)) {
                        return newValue;
                      }
                      return oldValue;
                    }),
                  ],
                  textAlign: TextAlign.end,
                  style: AppTextStyles.h3.copyWith(fontSize: 18.sp, color: AppColors.white),
                  decoration: InputDecoration(
                    hintText: ' ',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.crimson)),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              if (onUnitToggle != null)
                _buildUnitToggle(currentUnit, onUnitToggle)
              else
                Container(
                  width: 40.w,
                  alignment: Alignment.center,
                  child: Text(
                    currentUnit,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitToggle(String currentUnit, VoidCallback onToggle) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildUnitChip("kg", currentUnit == "kg"),
            _buildUnitChip("%", currentUnit == "%"),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitChip(String label, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.crimson : Colors.transparent,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontSize: 10.sp,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildRecordsTab() {
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
              child: LayoutBuilder(
                  builder: (context, constraints) => ListView(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    children: [
                      if (historyLogs.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                          child: _buildSectionHeader("LOGGED METRICS"),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Column(
                            children: historyLogs.map((log) => _buildRecordCard(log, provider)).toList(),
                          ),
                        ),
                      ] else
                        Container(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Text(
                              "No records for this date.",
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecordCard(BodyCompLog log, BodyCompProvider provider) {
    Color metricColor;
    IconData metricIcon;
    String label;
    String unit = log.unit == BodyMetricUnit.kg ? "kg" : "%";

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
          title: "DELETE RECORD",
          message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THIS $label ENTRY FROM YOUR RECORDS?",
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24.w),
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
      ),
      onDismissed: (_) => provider.deleteLog(log.id, log.type),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.03)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: metricColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(metricIcon, color: metricColor, size: 20.r),
                ),
                SizedBox(width: 16.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(log.timestamp),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                        fontSize: 9.sp,
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
                  log.value.toStringAsFixed(1),
                  style: AppTextStyles.h3.copyWith(fontSize: 18.sp, color: Colors.white),
                ),
                SizedBox(width: 4.w),
                Text(
                  unit,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp),
                ),
              ],
            ),
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
              child: Text(d, textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 10.sp)),
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
                          fontWeight: (isSelected || hasData) ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (hasData && !isSelected)
                        Positioned(
                          bottom: 4.h,
                          child: Container(
                            width: 3.r,
                            height: 3.r,
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
                color: isSelected ? AppColors.crimson : Colors.transparent,
                borderRadius: BorderRadius.circular(12.r),
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
                      fontSize: 10.sp,
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.2)),
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
                          : (hasData ? AppColors.white : AppColors.white.withValues(alpha: 0.15)),
                    ),
                  ),
                  if (hasData && !isSelected)
                    Container(
                      margin: EdgeInsets.only(top: 4.h),
                      width: 4.r,
                      height: 4.r,
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
