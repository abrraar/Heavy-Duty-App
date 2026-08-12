import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/main_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/features/tracker/calorie/widgets/sheets/calorie_notification_sheet.dart';
import 'package:heavy_duty/features/tracker/calorie/widgets/calorie_analytical_widget.dart';
import 'model/saved_meal.dart';
import 'package:heavy_duty/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:heavy_duty/features/tracker/calorie/widgets/add_meal_sheet.dart';
import 'package:heavy_duty/features/tracker/calorie/model/calorie_log.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class CalorieScreen extends StatefulWidget {
  final int initialTabIndex;
  const CalorieScreen({super.key, this.initialTabIndex = 0});

  @override
  State<CalorieScreen> createState() => _CalorieScreenState();
}

class _CalorieScreenState extends State<CalorieScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  DateTime _selectedHistoryDate = DateTime.now();
  DateTime _displayedMonth = DateTime.now();
  bool _isCalendarExpanded = false;
  final Set<String> _expandedSupplementIds = {};

  // Analytical Tab State
  final Set<String> _visibleAnalyticalMetrics = {"calories", "protein", "carbs", "fats"};
  int? _comparisonIdx1;
  int? _comparisonIdx2;

  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "calorie";
    _tabController = TabController(
      length: 4, 
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
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
    super.dispose();
  }

  void _openAddMealSheet(BuildContext context) {
    final provider = context.read<CalorieProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMealSheet(
        savedMeals: provider.savedMeals,
        onSave: (log, saveTemplate, servings, multiplySupps) {
          provider.addLog(log);
          if (saveTemplate) {
            provider.saveMealTemplate(SavedMeal(
              id: Uuid().v4(),
              name: log.mealName,
              foodItems: log.foodItems,
              calories: log.calories,
              protein: log.protein,
              carbs: log.carbs,
              fats: log.fats,
              addedSupplementsJson: log.addedSupplementsJson,
              addedStacksJson: log.addedStacksJson,
              servings: servings,
              multiplySupps: multiplySupps,
            ));
          }
        },
      ),
    );
  }

  Future<void> _showLogPrompt(SavedMeal meal, CalorieProvider provider) async {
    double tempServings = meal.servings;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
            title: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_task_rounded, color: Colors.greenAccent, size: 28),
                ),
                SizedBox(height: 16.h),
                Text(
                  "LOG MEAL",
                  style: AppTextStyles.h3.copyWith(fontSize: 16.sp, letterSpacing: 1.2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "ADJUST SERVINGS FOR '${meal.name.toUpperCase()}'",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                ),
                SizedBox(height: 24.h),
                Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (tempServings > 0.5) {
                            setDialogState(() => tempServings -= 0.5);
                          }
                        },
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white24),
                      ),
                      Text(
                        "${tempServings % 1 == 0 ? tempServings.toInt() : tempServings.toStringAsFixed(1)}X",
                        style: AppTextStyles.h2.copyWith(color: AppColors.crimson),
                      ),
                      IconButton(
                        onPressed: () {
                          if (tempServings < 99) {
                            setDialogState(() => tempServings += 0.5);
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white24),
                      ),
                    ],
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
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.white.withValues(alpha: 0.1)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "CANCEL",
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, {'servings': tempServings}),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "CONFIRM",
                            style: AppTextStyles.labelMedium.copyWith(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && mounted) {
      final double finalServings = result['servings'];
      final double ratio = finalServings / (meal.servings > 0 ? meal.servings : 1.0);
      final mealId = const Uuid().v4();
      final supplementProvider = context.read<SupplementProvider>();

      List<Map<String, dynamic>> suppsPayload = [];
      if (meal.addedSupplementsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(meal.addedSupplementsJson!);
          for (var item in decoded) {
            if (item is Map) {
              final String id = item['id'];
              double baseAmount = (item['amount'] as num).toDouble();
              if (meal.multiplySupps) {
                 baseAmount = baseAmount / (meal.servings > 0 ? meal.servings : 1.0);
              }
              
              final double newAmount = meal.multiplySupps ? (baseAmount * finalServings) : baseAmount;
              final supp = supplementProvider.library.firstWhere((s) => s.id == id);
              
              await supplementProvider.recordEntry(
                supplement: supp,
                isIntake: true,
                isRestock: false,
                weightAdjustment: -(newAmount * supp.weightPerServing),
                historyDetails: "MEAL LOG: ${meal.name.toUpperCase()} | SUPPLEMENT | $newAmount ${supp.servingUnit.toUpperCase()}",
                timestamp: DateTime.now(),
                sourceId: mealId,
              );
              suppsPayload.add({'id': id, 'amount': newAmount});
            }
          }
        } catch (e) {
          debugPrint("LogPrompt: Supplement Error: $e");
        }
      }

      List<Map<String, dynamic>> stacksPayload = [];
      if (meal.addedStacksJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(meal.addedStacksJson!);
          for (var item in decoded) {
            if (item is Map) {
              final String id = item['id'];
              final Map<String, dynamic> rawAmounts = item['itemAmounts'];
              final Map<String, double> newAmounts = {};

              final stack = supplementProvider.supplementStacks.firstWhere((s) => s.id == id);
              for (var supplement in stack.items) {
                if (!rawAmounts.containsKey(supplement.id)) continue;
                
                double baseAmount = (rawAmounts[supplement.id] as num).toDouble();
                if (meal.multiplySupps) {
                  baseAmount = baseAmount / (meal.servings > 0 ? meal.servings : 1.0);
                }

                final double newAmount = meal.multiplySupps ? (baseAmount * finalServings) : baseAmount;
                await supplementProvider.recordEntry(
                  supplement: supplement,
                  isIntake: true,
                  isRestock: false,
                  weightAdjustment: -(newAmount * supplement.weightPerServing),
                  historyDetails: "MEAL LOG: ${meal.name.toUpperCase()} | STACK: ${stack.name.toUpperCase()} | $newAmount ${supplement.servingUnit.toUpperCase()}",
                  timestamp: DateTime.now(),
                  sourceId: mealId,
                );
                newAmounts[supplement.id] = newAmount;
              }
              stacksPayload.add({'id': id, 'itemAmounts': newAmounts});
            }
          }
        } catch (e) {
          debugPrint("LogPrompt: Stack Error: $e");
        }
      }

      provider.addLog(CalorieLog(
        id: mealId,
        mealName: meal.name,
        foodItems: meal.foodItems,
        calories: (meal.calories * ratio),
        protein: meal.protein != null ? meal.protein! * ratio : null,
        carbs: meal.carbs != null ? meal.carbs! * ratio : null,
        fats: meal.fats != null ? meal.fats! * ratio : null,
        addedSupplementsJson: suppsPayload.isNotEmpty ? jsonEncode(suppsPayload) : null,
        addedStacksJson: stacksPayload.isNotEmpty ? jsonEncode(stacksPayload) : null,
        servings: finalServings,
        timestamp: DateTime.now(),
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${meal.name} logged!")),
      );
    }
  }

  Future<bool?> _showActionConfirmation({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
  }) async {
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
                color: confirmColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: confirmColor,
                size: 28.r,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
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
              message,
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
                        color: confirmColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: confirmColor.withValues(alpha: 0.5)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        confirmText,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: confirmColor,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 8.w),
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
                          'CALORIE TRACKER',
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
                          icon: Icon(Icons.info_outline_rounded),
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
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                  unselectedLabelColor: AppColors.textSecondary,
                  labelColor: AppColors.crimson,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: "TRACKER"),
                    Tab(text: "TRENDS"),
                    Tab(text: "LIBRARY"),
                    Tab(text: "HISTORY"),
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
                _buildTrendsTab(),
                _buildLibraryTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        if (provider.logs.isEmpty) {
          return Center(
            child: Text(
              "LOG MEALS TO VIEW TRENDS",
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary.withOpacity(0.3),
                letterSpacing: 1,
              ),
            ),
          );
        }

        // Sort logs by timestamp
        final sortedLogs = List<CalorieLog>.from(provider.logs)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        final List<DateTime> sortedDates = sortedLogs.map((l) => l.timestamp).toList();

        final Map<String, List<double?>> aggregatedData = {
          "calories": sortedLogs.map((l) => l.calories.toDouble()).toList(),
          "protein": sortedLogs.map((l) => l.protein != null ? l.protein! * 4 : null).toList(),
          "carbs": sortedLogs.map((l) => l.carbs != null ? l.carbs! * 4 : null).toList(),
          "fats": sortedLogs.map((l) => l.fats != null ? l.fats! * 9 : null).toList(),
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
                _buildSectionHeader("ENERGY TRENDS (KCAL)"),
                SizedBox(height: 24.h),
                CalorieAnalyticalGraph(
                  dates: sortedDates,
                  data: aggregatedData,
                  visibleMetrics: _visibleAnalyticalMetrics,
                  onPointSelected: (idx) {},
                ),
                SizedBox(height: 32.h),
                _buildSectionHeader("METRIC OVERLAY"),
                SizedBox(height: 16.h),
                Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  children: [
                    _buildAnalyticalMetricToggle("CALORIES", "calories", AppColors.crimson),
                    _buildAnalyticalMetricToggle("PROTEIN (kcal)", "protein", Colors.blueAccent),
                    _buildAnalyticalMetricToggle("CARBS (kcal)", "carbs", Colors.greenAccent),
                    _buildAnalyticalMetricToggle("FATS (kcal)", "fats", Colors.orangeAccent),
                  ],
                ),
                SizedBox(height: 40.h),
                _buildSectionHeader("DATA COMPARISON"),
                SizedBox(height: 16.h),
                CalorieComparisonWidget(
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
      },
    );
  }

  Widget _buildAnalyticalMetricToggle(String label, String key, Color color) {
    final bool isActive = _visibleAnalyticalMetrics.contains(key);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isActive) {
            _visibleAnalyticalMetrics.remove(key);
          } else {
            _visibleAnalyticalMetrics.add(key);
          }
        });
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

  Widget _buildTrackerTab() {
    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;
        final consumed = provider.consumedCalories;

        return RefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            child: Column(
              children: [
                _buildEnergySummary(
                  consumed, 
                  settings.dailyCalorieGoal,
                  provider.proteinTotal,
                  provider.carbsTotal,
                  provider.fatsTotal,
                ),
                if (settings.trackMacros) ...[
                  SizedBox(height: 24.h),
                  _buildMacroSection(
                    provider.proteinTotal,
                    provider.carbsTotal,
                    provider.fatsTotal,
                  ),
                ],
                SizedBox(height: 24.h),
                _buildMealLogSection(provider),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLibraryTab() {
    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        final savedMeals = provider.savedMeals;

        return RefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddMealSheet(
                        isLibraryOnly: true,
                        savedMeals: provider.savedMeals,
                        onSave: (log, _, servings, multiplySupps) {
                          provider.saveMealTemplate(SavedMeal(
                            id: Uuid().v4(),
                            name: log.mealName,
                            foodItems: log.foodItems,
                            calories: log.calories,
                            protein: log.protein,
                            carbs: log.carbs,
                            fats: log.fats,
                            addedSupplementsJson: log.addedSupplementsJson,
                            addedStacksJson: log.addedStacksJson,
                            servings: servings,
                            multiplySupps: multiplySupps,
                          ));
                        },
                      ),
                    );
                  },
                  child: Container(
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: AppColors.crimson.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.crimson.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          color: AppColors.crimson,
                          size: 20.r,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          "ADD A MEAL",
                          style: AppTextStyles.buttonPrimary.copyWith(
                            color: AppColors.crimson,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: savedMeals.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => ListView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          children: [
                            Container(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Center(
                                child: Text(
                                  "No saved meals in your library.",
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        itemCount: savedMeals.length,
                        itemBuilder: (context, index) {
                          final meal = savedMeals[index];
                          final supplementProvider = context.read<SupplementProvider>();
                          
                          List<Map<String, dynamic>> additions = [];

                          if (meal.addedSupplementsJson != null) {
                            try {
                              final List<dynamic> decoded = jsonDecode(meal.addedSupplementsJson!);
                              for (var item in decoded) {
                                final String id = (item is Map) ? item['id'] : item as String;
                                final double amount = (item is Map) ? (item['amount'] as num).toDouble() : 1.0;
                                
                                final s = supplementProvider.library.firstWhere((s) => s.id == id);
                                additions.add({
                                  'name': s.name,
                                  'cals': ((s.caloriesPerUnit ?? 0.0) * amount),
                                  'pro': (s.proteinPerUnit ?? 0.0) * amount,
                                  'cho': (s.carbsPerUnit ?? 0.0) * amount,
                                  'fat': (s.fatsPerUnit ?? 0.0) * amount,
                                });
                              }
                            } catch (_) {}
                          }
                          if (meal.addedStacksJson != null) {
                            try {
                              final List<dynamic> decoded = jsonDecode(meal.addedStacksJson!);
                              for (var item in decoded) {
                                final String id = (item is Map) ? item['id'] : item as String;
                                final Map<String, double>? itemAmounts = (item is Map) 
                                    ? (item['itemAmounts'] as Map).cast<String, dynamic>().map((k, v) => MapEntry(k, (v as num).toDouble()))
                                    : null;

                                final s = supplementProvider.supplementStacks.firstWhere((s) => s.id == id);
                                double stPro = 0, stCho = 0, stFat = 0;
                                double stCals = 0;
                                
                                for (var supplement in s.items) {
                                  double amount = itemAmounts?[supplement.id] ?? 1.0;
                                  stCals += ((supplement.caloriesPerUnit ?? 0.0) * amount);
                                  stPro += (supplement.proteinPerUnit ?? 0.0) * amount;
                                  stCho += (supplement.carbsPerUnit ?? 0.0) * amount;
                                  stFat += (supplement.fatsPerUnit ?? 0.0) * amount;
                                }

                                additions.add({
                                  'name': s.name,
                                  'cals': stCals,
                                  'pro': stPro,
                                  'cho': stCho,
                                  'fat': stFat,
                                });
                              }
                            } catch (_) {}
                          }

                          return Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: Dismissible(
                              key: Key("library_${meal.id}"),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  await _showLogPrompt(meal, provider);
                                  return false;
                                } else {
                                  final confirm = await _showActionConfirmation(
                                    title: "DELETE SAVED MEAL",
                                    message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE '${meal.name.toUpperCase()}' FROM YOUR LIBRARY?",
                                    confirmText: "DELETE",
                                    confirmColor: AppColors.crimson,
                                    icon: Icons.delete_forever_rounded,
                                  );
                                  if (confirm == true) {
                                    await provider.deleteSavedMeal(meal.id);
                                    return true;
                                  }
                                  return false;
                                }
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.only(left: 20.w),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: const Icon(Icons.add_circle_outline_rounded, color: Colors.greenAccent),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.only(right: 20.w),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                              ),
                              child: Container(
                                padding: EdgeInsets.all(18.r),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(24.r),
                                  border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                meal.name.toUpperCase(), 
                                                style: AppTextStyles.h3.copyWith(
                                                  fontSize: 16.sp, 
                                                  color: Colors.white,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              if (meal.sharedBy != null)
                                                Padding(
                                                  padding: EdgeInsets.only(top: 4.h),
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blueAccent.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6.r),
                                                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.share_rounded, color: Colors.blueAccent, size: 10.r),
                                                        SizedBox(width: 4.w),
                                                        Text(
                                                          "SHARED BY ${meal.sharedBy!.toUpperCase()}",
                                                          style: AppTextStyles.labelSmall.copyWith(
                                                            color: Colors.blueAccent,
                                                            fontSize: 8.sp,
                                                            fontWeight: FontWeight.w900,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              if (meal.foodItems.isNotEmpty)
                                                Padding(
                                                  padding: EdgeInsets.only(top: 4.h),
                                                  child: Text(
                                                    meal.foodItems,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: AppTextStyles.labelSmall.copyWith(
                                                      color: AppColors.textSecondary,
                                                      fontSize: 11.sp,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 12.w),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildQuickActionButton(
                                              icon: Icons.ios_share_rounded,
                                              isActive: false,
                                              onTap: () async {
                                                final authProvider = context.read<AuthProvider>();
                                                final userName = authProvider.displayName;
                                                
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("GENERATING SHAREABLE LINK..."), duration: Duration(seconds: 1)),
                                                );

                                                final link = await provider.generateShareableLink(meal, userName);
                                                
                                                if (link != null) {
                                                  await Share.share(
                                                    "CHECK OUT THIS MEAL SHARED BY $userName IN HEAVY DUTY:\n\n$link",
                                                    subject: "MEAL SHARED BY $userName",
                                                  );
                                                }
                                              },
                                            ),
                                            SizedBox(width: 8.w),
                                            _buildQuickActionButton(
                                              icon: Icons.edit_rounded,
                                              isActive: false,
                                              onTap: () {
                                                showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor: Colors.transparent,
                                                  builder: (context) => AddMealSheet(
                                                    isLibraryOnly: true,
                                                    existingMeal: meal,
                                                    savedMeals: provider.savedMeals,
                                                    onSave: (log, _, servings, multiplySupps) {
                                                      provider.saveMealTemplate(SavedMeal(
                                                        id: log.id,
                                                        name: log.mealName,
                                                        foodItems: log.foodItems,
                                                        calories: log.calories,
                                                        protein: log.protein,
                                                        carbs: log.carbs,
                                                        fats: log.fats,
                                                        addedSupplementsJson: log.addedSupplementsJson,
                                                        addedStacksJson: log.addedStacksJson,
                                                        isPinnedToHome: meal.isPinnedToHome,
                                                        notificationsEnabled: meal.notificationsEnabled,
                                                        reminders: meal.reminders,
                                                        servings: servings,
                                                        multiplySupps: multiplySupps,
                                                      ));
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                            SizedBox(width: 8.w),
                                            _buildQuickActionButton(
                                              icon: Icons.push_pin_rounded,
                                              isActive: meal.isPinnedToHome,
                                              onTap: () => provider.updateSavedMeal(meal.copyWith(isPinnedToHome: !meal.isPinnedToHome)),
                                            ),
                                            SizedBox(width: 8.w),
                                            _buildQuickActionButton(
                                              icon: Icons.notifications_active_outlined,
                                              isActive: meal.notificationsEnabled,
                                              onTap: () {
                                                showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor: Colors.transparent,
                                                  builder: (context) => CalorieNotificationSheet(meal: meal),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    
                                    if (additions.isNotEmpty) ...[
                                      Padding(
                                        padding: EdgeInsets.only(top: 16.h),
                                        child: Divider(color: AppColors.white.withValues(alpha: 0.05), height: 1),
                                      ),
                                      ...(() {
                                        final bool isExpanded = _expandedSupplementIds.contains(meal.id);
                                        final List<Map<String, dynamic>> visibleAdditions = 
                                            isExpanded ? additions : additions.take(1).toList();
                                        final int totalAdditionsCals = additions.fold(0, (sum, item) => sum + (item['cals'] as num).round());
                                        
                                        return [
                                          ...visibleAdditions.map((item) => Padding(
                                            padding: EdgeInsets.only(top: 14.h),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        item['name'].toUpperCase(),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: AppTextStyles.labelSmall.copyWith(
                                                          color: Colors.white,
                                                          fontSize: 11.sp,
                                                          fontWeight: FontWeight.w900,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.local_fire_department_rounded, color: AppColors.crimson, size: 12.r),
                                                        SizedBox(width: 4.w),
                                                        Text(
                                                          "+${item['cals']}",
                                                          style: AppTextStyles.h3.copyWith(
                                                            color: Colors.white,
                                                            fontSize: 14.sp,
                                                            fontWeight: FontWeight.w900,
                                                          ),
                                                        ),
                                                        SizedBox(width: 2.w),
                                                        Text(
                                                          "kcal",
                                                          style: AppTextStyles.labelSmall.copyWith(
                                                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                                                            fontSize: 8.sp,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.only(top: 4.h),
                                                  child: Row(
                                                    children: [
                                                      _buildSpecMacro(item['pro'].toDouble(), "PRO", Colors.blueAccent),
                                                      _buildSpecDivider(),
                                                      _buildSpecMacro(item['cho'].toDouble(), "CHO", Colors.greenAccent),
                                                      _buildSpecDivider(),
                                                      _buildSpecMacro(item['fat'].toDouble(), "FAT", Colors.orangeAccent),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )),
                                          if (additions.length > 1)
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  if (isExpanded) {
                                                    _expandedSupplementIds.remove(meal.id);
                                                  } else {
                                                    _expandedSupplementIds.add(meal.id);
                                                  }
                                                });
                                              },
                                              child: Container(
                                                padding: EdgeInsets.only(top: 16.h),
                                                color: Colors.transparent,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      isExpanded 
                                                          ? "SHOW FEWER INGREDIENTS" 
                                                          : "SHOW ${additions.length - 1} MORE ADDITIONS",
                                                      style: AppTextStyles.labelSmall.copyWith(
                                                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                                                        fontSize: 9.sp,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 1.5,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Icon(
                                                      isExpanded 
                                                          ? Icons.keyboard_arrow_up_rounded 
                                                          : Icons.keyboard_arrow_down_rounded,
                                                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                                                      size: 16.r,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if (additions.length > 1)
                                            Padding(
                                              padding: EdgeInsets.only(top: 16.h),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    "TOTAL ADDITIONS:",
                                                    style: AppTextStyles.labelSmall.copyWith(
                                                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                                                      fontSize: 9.sp,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.local_fire_department_rounded, color: AppColors.crimson, size: 12.r),
                                                      SizedBox(width: 4.w),
                                                      Text(
                                                        "+$totalAdditionsCals",
                                                        style: AppTextStyles.h3.copyWith(
                                                          color: Colors.white,
                                                          fontSize: 14.sp,
                                                          fontWeight: FontWeight.w900,
                                                        ),
                                                      ),
                                                      SizedBox(width: 2.w),
                                                      Text(
                                                        "kcal",
                                                        style: AppTextStyles.labelSmall.copyWith(
                                                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                                                          fontSize: 8.sp,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ];
                                      })(),
                                    ],

                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16.h),
                                      child: Divider(color: AppColors.white.withValues(alpha: 0.05), height: 1),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.local_fire_department_rounded, color: AppColors.crimson, size: 16.r),
                                            SizedBox(width: 6.w),
                                            Text(
                                              meal.calories % 1 == 0 ? meal.calories.toInt().toString() : meal.calories.toStringAsFixed(1),
                                              style: AppTextStyles.h3.copyWith(
                                                color: Colors.white,
                                                fontSize: 18.sp,
                                              ),
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              "kcal",
                                              style: AppTextStyles.labelSmall.copyWith(
                                                color: AppColors.textSecondary,
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Wrap(
                                          spacing: 8.w,
                                          children: [
                                            if (meal.protein != null) _buildSmallMacroPill("${meal.protein!.toInt()}g Protein", Colors.blueAccent),
                                            if (meal.carbs != null) _buildSmallMacroPill("${meal.carbs!.toInt()}g Carbs", Colors.greenAccent),
                                            if (meal.fats != null) _buildSmallMacroPill("${meal.fats!.toInt()}g Fats", Colors.orangeAccent),
                                          ],
                                        ),
                                      ],
                                    ),
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
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return Consumer<CalorieProvider>(
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

        final consumed = historyLogs.fold(0.0, (sum, l) => sum + l.calories).round();
        final protein = historyLogs.any((l) => l.protein != null) 
            ? historyLogs.fold(0.0, (sum, l) => sum + (l.protein ?? 0.0)) 
            : null;
        final carbs = historyLogs.any((l) => l.carbs != null) 
            ? historyLogs.fold(0.0, (sum, l) => sum + (l.carbs ?? 0.0)) 
            : null;
        final fats = historyLogs.any((l) => l.fats != null) 
            ? historyLogs.fold(0.0, (sum, l) => sum + (l.fats ?? 0.0)) 
            : null;

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
                        SizedBox(height: 20.h),
                        _buildEnergySummary(
                          consumed, 
                          provider.settings.dailyCalorieGoal,
                          protein,
                          carbs,
                          fats,
                        ),
                        if (provider.settings.trackMacros) ...[
                          SizedBox(height: 24.h),
                          _buildMacroSection(protein, carbs, fats),
                        ],
                        SizedBox(height: 24.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: _buildSectionHeader("LOGGED MEALS"),
                        ),
                        SizedBox(height: 12.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Column(
                            children: historyLogs.map((log) => _buildMealCard(log, provider)).toList(),
                          ),
                        ),
                        SizedBox(height: 40.h),
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

  Widget _buildEnergySummary(int consumed, int goal, double? protein, double? carbs, double? fats) {
    final int remaining = goal - consumed;
    final bool isOver = remaining < 0;

    final double totalMacros = (protein ?? 0) + (carbs ?? 0) + (fats ?? 0);
    final bool hasMacros = totalMacros > 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "CONSUMED",
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                "$consumed",
                style: AppTextStyles.h1.copyWith(
                  fontSize: 32.sp,
                  color: AppColors.white,
                ),
              ),
              Text(
                "/ $goal kcal",
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                isOver ? "OVER: ${remaining.abs()} kcal" : "REMAINING: $remaining kcal",
                style: AppTextStyles.labelSmall.copyWith(
                  color: isOver ? AppColors.crimson : Colors.greenAccent,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 90.r,
            width: 90.r,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 32.r,
                    startDegreeOffset: -90,
                    sections: [
                      PieChartSectionData(
                        color: AppColors.crimson,
                        value: consumed.toDouble(),
                        radius: 6.r,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        color: AppColors.white.withValues(alpha: 0.05),
                        value: remaining < 0 ? 0 : remaining.toDouble(),
                        radius: 6.r,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                if (hasMacros)
                  SizedBox(
                    height: 56.r,
                    width: 56.r,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 20.r,
                        startDegreeOffset: -90,
                        sections: [
                          PieChartSectionData(
                            color: Colors.blueAccent,
                            value: protein ?? 0,
                            radius: 6.r,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            color: Colors.greenAccent,
                            value: carbs ?? 0,
                            radius: 6.r,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            color: Colors.orangeAccent,
                            value: fats ?? 0,
                            radius: 6.r,
                            showTitle: false,
                          ),
                        ],
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

  Widget _buildMacroSection(double? protein, double? carbs, double? fats) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          _buildMacroTile("Protein", protein != null ? "${protein.toInt()}g" : "-", Colors.blueAccent),
          SizedBox(width: 10.w),
          _buildMacroTile("Carbs", carbs != null ? "${carbs.toInt()}g" : "-", Colors.greenAccent),
          SizedBox(width: 10.w),
          _buildMacroTile("Fats", fats != null ? "${fats.toInt()}g" : "-", Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildMacroTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.white),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10.sp,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealLogSection(CalorieProvider provider) {
    final todayLogs = provider.logs.where((l) {
      final now = DateTime.now();
      return l.timestamp.year == now.year &&
          l.timestamp.month == now.month &&
          l.timestamp.day == now.day;
    }).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openAddMealSheet(context),
            child: Container(
              height: 50.h,
              decoration: BoxDecoration(
                color: AppColors.crimson.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.crimson.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.crimson,
                    size: 20.r,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    "ADD MEAL ENTRY",
                    style: AppTextStyles.buttonPrimary.copyWith(
                      color: AppColors.crimson,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),
          _buildSectionHeader("DAILY MEALS"),
          SizedBox(height: 12.h),
          if (todayLogs.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Text(
                  "No meals logged today.",
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...todayLogs.map((log) => _buildMealCard(log, provider)),
        ],
      ),
    );
  }

  Widget _buildMealCard(CalorieLog log, CalorieProvider provider) {
    final supplementProvider = context.read<SupplementProvider>();
    List<Map<String, dynamic>> additions = [];
    double totalSuppCals = 0;

    // 1. Calculate Supplement & Stack Breakdown
    if (log.addedSupplementsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(log.addedSupplementsJson!);
        for (var item in decoded) {
          final String id = (item is Map) ? item['id'] : item as String;
          final double amount = (item is Map) ? (item['amount'] as num).toDouble() : 1.0;
          final s = supplementProvider.library.firstWhere((s) => s.id == id);
          final double itemCals = ((s.caloriesPerUnit ?? 0.0) * amount);
          totalSuppCals += itemCals;
          additions.add({
            'name': s.name,
            'cals': itemCals,
            'pro': (s.proteinPerUnit ?? 0.0) * amount,
            'cho': (s.carbsPerUnit ?? 0.0) * amount,
            'fat': (s.fatsPerUnit ?? 0.0) * amount,
          });
        }
      } catch (_) {}
    }

    if (log.addedStacksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(log.addedStacksJson!);
        for (var item in decoded) {
          final String id = (item is Map) ? item['id'] : item as String;
          final Map<String, double>? itemAmounts = (item is Map) 
              ? (item['itemAmounts'] as Map).cast<String, dynamic>().map((k, v) => MapEntry(k, (v as num).toDouble()))
              : null;

          final stack = supplementProvider.supplementStacks.firstWhere((s) => s.id == id);
          double stCals = 0;
          double stPro = 0, stCho = 0, stFat = 0;
          
          for (var supplement in stack.items) {
            if (itemAmounts != null && !itemAmounts.containsKey(supplement.id)) continue;
            double amount = itemAmounts?[supplement.id] ?? 1.0;
            stCals += ((supplement.caloriesPerUnit ?? 0.0) * amount);
            stPro += (supplement.proteinPerUnit ?? 0.0) * amount;
            stCho += (supplement.carbsPerUnit ?? 0.0) * amount;
            stFat += (supplement.fatsPerUnit ?? 0.0) * amount;
          }
          
          totalSuppCals += stCals;
          additions.add({
            'name': stack.name,
            'isStack': true,
            'cals': stCals,
            'pro': stPro,
            'cho': stCho,
            'fat': stFat,
          });
        }
      } catch (_) {}
    }

    // 2. Nutrition Ledger Calculations
    final double portion = log.servings;
    final double finalTotalCals = log.calories;
    final double mealCalsIncludingPortion = finalTotalCals - totalSuppCals;
    final double baseMealOriginalCals = (mealCalsIncludingPortion / (portion > 0 ? portion : 1.0));

    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24.w),
        margin: EdgeInsets.only(bottom: 20.h),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(28.r),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
      ),
      confirmDismiss: (direction) async => await _showActionConfirmation(
        title: "DELETE MEAL ENTRY",
        message: "REMOVE THIS MEAL FROM YOUR LOG?",
        confirmText: "DELETE",
        confirmColor: AppColors.crimson,
        icon: Icons.delete_forever_rounded,
      ),
      onDismissed: (_) {
        final logsToRollback = supplementProvider.history.where((h) => h.sourceId == log.id).toList();
        for (var entry in logsToRollback) {
          supplementProvider.removeSupplementItem(entry.id);
        }
        provider.deleteLog(log.id);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 20.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            // --- HEADER: Name & Summary ---
            Padding(
              padding: EdgeInsets.fromLTRB(24.r, 24.r, 24.r, 12.r),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.mealName.toUpperCase(), 
                          style: AppTextStyles.h2.copyWith(fontSize: 20.sp, color: Colors.white, fontWeight: FontWeight.w900)),
                        if (log.foodItems.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 4.h),
                            child: Text(log.foodItems, 
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 12.sp)),
                          ),
                      ],
                    ),
                  ),
                  _buildTotalBadge(finalTotalCals),
                ],
              ),
            ),

            // --- VIVID BIG MACROS (Center Aligned) ---
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: _buildBigVividMacro(
                    log.protein != null ? "${log.protein!.toStringAsFixed(log.protein! % 1 == 0 ? 0 : 1)}G" : "-", 
                    "PROTEIN", 
                    Colors.blueAccent
                  )),
                  SizedBox(width: 8.w),
                  Expanded(child: _buildBigVividMacro(
                    log.carbs != null ? "${log.carbs!.toStringAsFixed(log.carbs! % 1 == 0 ? 0 : 1)}G" : "-", 
                    "CARBS", 
                    Colors.greenAccent
                  )),
                  SizedBox(width: 8.w),
                  Expanded(child: _buildBigVividMacro(
                    log.fats != null ? "${log.fats!.toStringAsFixed(log.fats! % 1 == 0 ? 0 : 1)}G" : "-", 
                    "FAT", 
                    Colors.orangeAccent
                  )),
                ],
              ),
            ),

            // --- TOGGLE BUTTON ---
            GestureDetector(
              onTap: () => setState(() {
                if (_expandedSupplementIds.contains(log.id)) _expandedSupplementIds.remove(log.id);
                else _expandedSupplementIds.add(log.id);
              }),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _expandedSupplementIds.contains(log.id) ? "HIDE DETAILS" : "SHOW MORE DETAILS",
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.crimson,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      _expandedSupplementIds.contains(log.id) ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.crimson,
                      size: 18.r,
                    ),
                  ],
                ),
              ),
            ),

            // --- COLLAPSIBLE DETAILS (Ledger & Ingredients) ---
            if (_expandedSupplementIds.contains(log.id)) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: const Divider(color: Colors.white10, height: 1),
              ),
              
              // NUTRITION LEDGER
              Container(
                margin: EdgeInsets.all(20.r),
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(
                  children: [
                    _buildLedgerRow("ORIGINAL MEAL", "$baseMealOriginalCals kcal"),
                    _buildLedgerRow("PORTION SCALE", "× ${portion % 1 == 0 ? portion.toInt() : portion.toStringAsFixed(1)}", isAccent: true),
                    
                    // --- INTEGRATED SUPPLEMENTS ---
                    if (additions.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      ...additions.map((item) => _buildIngredientDetail(item)),
                    ],

                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      child: Divider(color: AppColors.white.withValues(alpha: 0.05), height: 1),
                    ),
                    _buildLedgerRow("TOTAL INTAKE", "$finalTotalCals kcal", isBold: true),
                  ],
                ),
              ),
            ],
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBadge(double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          total % 1 == 0 ? total.toInt().toString() : total.toStringAsFixed(1),
          style: AppTextStyles.h1.copyWith(
            fontSize: 28.sp,
            color: Colors.white,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          "KCAL",
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 10.sp,
            fontWeight: FontWeight.w900,
            color: AppColors.crimson,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildBigVividMacro(String value, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 0),
        ],
      ),
      child: Column(
        children: [
          Text(value, 
            style: AppTextStyles.h2.copyWith(fontSize: 22.sp, color: Colors.white, fontWeight: FontWeight.w900)),
          SizedBox(height: 2.h),
          Text(label, 
            style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: 11.sp, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        ],
      ),
    );
  }

  Widget _buildLedgerRow(String label, String value, {bool isAccent = false, bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, 
            style: AppTextStyles.labelSmall.copyWith(
              color: isAccent ? AppColors.crimson.withValues(alpha: 0.9) : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              fontSize: 11.sp,
              letterSpacing: 1,
            )),
          Text(value, 
            style: AppTextStyles.labelMedium.copyWith(
              color: isBold ? Colors.white : Colors.white.withValues(alpha: 0.7),
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              fontSize: isBold ? 15.sp : 13.sp,
            )),
        ],
      ),
    );
  }

  Widget _buildPremiumMacroPill(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(text, 
        style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w900, fontSize: 10.sp)),
    );
  }

  Widget _buildIngredientDetail(Map<String, dynamic> item) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(
            item['isStack'] == true ? Icons.layers_rounded : Icons.medication_rounded, 
            color: AppColors.crimson.withValues(alpha: 0.6), 
            size: 14.r
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              item['name'].toString().toUpperCase(), 
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.8), 
                fontWeight: FontWeight.bold, 
                fontSize: 11.sp,
                letterSpacing: 0.5,
              )
            ),
          ),
          Text(
            "+${item['cals']} kcal", 
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.6), 
              fontWeight: FontWeight.w900, 
              fontSize: 11.sp,
            )
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3.w,
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
          ),
        ),
      ],
    );
  }

  Widget _buildSmallMacroPill(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSpecMacro(num? value, String label, Color color) {
    if (value == null) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "- ",
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: label,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontSize: 8.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }
    final String formattedValue = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: "$formattedValue ",
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 9.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontSize: 8.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Text(
        "|",
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.white.withValues(alpha: 0.1),
          fontSize: 8.sp,
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: isActive ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isActive ? AppColors.crimson.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.crimson : AppColors.textSecondary,
          size: 18.r,
        ),
      ),
    );
  }
}
