// lib/features/home/home_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/constants/dimensions.dart';
import 'package:heavy_duty/core/providers/ui_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../tracker/calorie/model/calorie_log.dart';
import '../tracker/calorie/model/saved_meal.dart';
import '../tracker/calorie/provider/calorie_provider.dart';
import '../tracker/hydration/provider/hydration_provider.dart';
import '../tracker/supplement/provider/supplement_provider.dart';
import '../tracker/supplement/model/supplement.dart';
import '../tracker/supplement/model/supplement_stack.dart';
import '../tracker/cycle_tracker/provider/cycle_provider.dart';
import '../tracker/cycle_tracker/model/workout.dart';
import '../tracker/cycle_tracker/exercise_list_screen.dart';
import '../tracker/cycle_tracker/cycle_tracking_screen.dart';

import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'widgets/welcome_header.dart';
import 'widgets/affirmation_card.dart';
import 'widgets/water_tracker_card.dart';
import 'widgets/cycle_status_card.dart';
import 'widgets/cycle_metric_tile.dart';
import 'widgets/workout_action_card.dart';
import 'widgets/meal%20quick%20log/meal_quick_log_card.dart';
import 'widgets/supplement quick log/quick_log_card.dart';
import 'widgets/stack%20quick%20log/stack_quick_log_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<UiProvider>(
      builder: (context, uiProvider, _) {
        // Filter out 'workout_action' from the layout list
        final List<String> sections = uiProvider.settings.homeLayout
            .where((s) => s != 'workout_action')
            .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final bool isCompact = width < kMobileBreakpoint;

            final double hPad = !isCompact 
                ? (width - kMaxContentWidth).clamp(40.0, double.infinity) / 2 
                : 20.w;

            return RefreshIndicator(
              onRefresh: _refreshData,
              color: AppColors.crimson,
              backgroundColor: AppColors.surface,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ── HEADER ──
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 10.h, hPad, 16.r),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const WelcomeHeader(),
                          SizedBox(height: 12.r),
                          const AffirmationCard(),
                        ],
                      ),
                    ),
                  ),

                  // ── REORDERABLE DASHBOARD SECTIONS ──
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    sliver: SliverReorderableList(
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(section),
                          index: index,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 16.r),
                            child: _HomeSectionBuilder(section: section),
                          ),
                        );
                      },
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final items = List<String>.from(sections);
                        final item = items.removeAt(oldIndex);
                        items.insert(newIndex, item);
                        uiProvider.updateHomeLayout(items);
                      },
                    ),
                  ),
                  
                  // Reduced bottom padding to only what's necessary
                  SliverToBoxAdapter(child: SizedBox(height: 16.r)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _refreshData() async {
    final cycleProv = context.read<CycleProvider>();
    final hydrationProv = context.read<HydrationProvider>();
    final calorieProv = context.read<CalorieProvider>();
    final supplementProv = context.read<SupplementProvider>();
    final uiProvider = context.read<UiProvider>();

    await Future.wait([
      cycleProv.forceRefresh(),
      hydrationProv.forceRefresh(),
      calorieProv.forceRefresh(),
      supplementProv.forceRefresh(),
      uiProvider.forceRefresh(),
    ]);
  }
}

class _HomeSectionBuilder extends StatelessWidget {
  final String section;
  const _HomeSectionBuilder({required this.section});

  @override
  Widget build(BuildContext context) {
    return Consumer<CycleProvider>(
      builder: (context, cycleProvider, _) {
        final activeCycle = cycleProvider.activeCycle;
        final workouts = activeCycle?.workouts ?? [];

        switch (section) {
          case 'meal_log': return const _MealLogSection();
          case 'supplement_log': return const _SupplementLogSection();
          case 'stack_log': return const _StackLogSection();
          case 'water':
            return Consumer<HydrationProvider>(
              builder: (context, provider, _) {
                if (!provider.settings.isPinnedToHome) return const SizedBox.shrink();
                return WaterTrackerCard(
                  currentMl: provider.todayIntake,
                  targetMl: provider.settings.dailyGoal,
                  addValueMl: provider.settings.addValue,
                  minusValueMl: provider.settings.minusValue,
                  useMetric: provider.settings.useMetric,
                  onAdjust: (amt) => provider.addWater(amt),
                );
              },
            );
          case 'cycle_status':
            return CycleStatusCard(
              activeCycle: activeCycle?.name ?? 'NO ACTIVE CYCLE',
              completedWorkouts: workouts.where((w) => w.status == WorkoutStatus.completed).length,
              totalWorkouts: workouts.length,
              workOutputGrowth: activeCycle != null ? cycleProvider.calculateCyclePerformance(activeCycle.id) : 0.0,
            );
          case 'metrics':
            return const _WorkoutMetricsPair();
          default: return const SizedBox.shrink();
        }
      },
    );
  }
}

class _WorkoutMetricsPair extends StatelessWidget {
  const _WorkoutMetricsPair();

  @override
  Widget build(BuildContext context) {
    return Consumer<CycleProvider>(
      builder: (context, cycleProvider, _) {
        final activeCycle = cycleProvider.activeCycle;
        final workouts = activeCycle?.workouts ?? [];
        
        final completed = workouts.where((w) => w.status == WorkoutStatus.completed).toList();
        if (completed.isNotEmpty) completed.sort((a, b) => (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
        
        final pending = workouts.where((w) => w.status == WorkoutStatus.pending).toList();
        if (pending.isNotEmpty) pending.sort((a, b) => a.order.compareTo(b.order));

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _WorkoutMetricTile(workout: completed.firstOrNull, activeCycle: activeCycle, isHistory: true)),
              SizedBox(width: 12.r),
              Expanded(child: _WorkoutMetricTile(workout: pending.firstOrNull, activeCycle: activeCycle, isHistory: false)),
            ],
          ),
        );
      },
    );
  }
}

class _WorkoutMetricTile extends StatelessWidget {
  final Workout? workout;
  final dynamic activeCycle;
  final bool isHistory;

  const _WorkoutMetricTile({this.workout, required this.activeCycle, required this.isHistory});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (workout != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ExerciseListScreen(workoutId: workout!.id, workoutName: workout!.name)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => CycleTrackingScreen(initialTabIndex: activeCycle == null ? 2 : 0)));
        }
      },
      child: CycleMetricTile(
        label: isHistory ? 'Last Workout' : 'Upcoming',
        value: workout?.name ?? (activeCycle == null ? 'Start Cycle' : (isHistory ? 'No History' : 'Cycle Complete')),
        icon: isHistory ? Icons.history : Icons.event_repeat_rounded,
        date: workout?.completedAt != null ? DateFormat('MMM dd, yyyy').format(workout!.completedAt!) : (!isHistory && workout != null ? 'Next Session' : null),
      ),
    );
  }
}

class _MealLogSection extends StatelessWidget {
  const _MealLogSection();
  @override
  Widget build(BuildContext context) {
    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        final pinned = provider.pinnedMeals;
        if (pinned.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("MEAL QUICK LOG", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 2.0, fontSize: 12.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 12.r),
            SizedBox(
              height: 155.r,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: pinned.length,
                itemBuilder: (context, index) => MealQuickLogCard(meal: pinned[index], onTap: () => _handleMealLog(context, pinned[index], provider)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleMealLog(BuildContext context, SavedMeal meal, CalorieProvider provider) async {
    final logId = const Uuid().v4();
    final supplementProvider = context.read<SupplementProvider>();
    
    if (meal.addedSupplementsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(meal.addedSupplementsJson!);
        for (var item in decoded) {
          final String id = (item is Map) ? item['id'] : item as String;
          final double amount = (item is Map) ? (item['amount'] as num).toDouble() : 1.0;
          final supp = supplementProvider.library.firstWhereOrNull((s) => s.id == id);
          if (supp == null) continue;
          await supplementProvider.recordEntry(supplement: supp, isIntake: true, isRestock: false, weightAdjustment: -(amount * supp.weightPerServing), historyDetails: "MEAL LOG: ${meal.name.toUpperCase()} | $amount ${supp.servingUnit.toUpperCase()}", timestamp: DateTime.now(), sourceId: logId);
        }
      } catch (_) {}
    }
    
    if (meal.addedStacksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(meal.addedStacksJson!);
        for (var item in decoded) {
          final String id = (item is Map) ? item['id'] : item as String;
          final Map<String, double>? itemAmounts = (item is Map) ? (item['itemAmounts'] as Map?)?.cast<String, dynamic>().map((k, v) => MapEntry(k, (v as num).toDouble())) : null;
          final stack = supplementProvider.supplementStacks.firstWhereOrNull((s) => s.id == id);
          if (stack == null) continue;
          for (var supplement in stack.items) {
            double amount = itemAmounts?[supplement.id] ?? 1.0;
            await supplementProvider.recordEntry(supplement: supplement, isIntake: true, isRestock: false, weightAdjustment: -(amount * supplement.weightPerServing), historyDetails: "MEAL LOG: ${meal.name.toUpperCase()} | $amount ${supplement.servingUnit.toUpperCase()}", timestamp: DateTime.now(), sourceId: logId);
          }
        }
      } catch (_) {}
    }

    provider.addLog(CalorieLog(
      id: logId, 
      mealName: meal.name, 
      foodItems: meal.foodItems,
      calories: meal.calories, 
      protein: meal.protein, 
      carbs: meal.carbs, 
      fats: meal.fats, 
      addedSupplementsJson: meal.addedSupplementsJson,
      addedStacksJson: meal.addedStacksJson,
      timestamp: DateTime.now()
    ));
    
    _showMealLogConfirmation(context, meal, provider, logId);
  }

  void _showMealLogConfirmation(BuildContext context, SavedMeal meal, CalorieProvider provider, String logId) {
    EliteSnackbar.show(
      context, 
      "${meal.name} LOGGED",
      onUndo: () {
        final supplementProvider = context.read<SupplementProvider>();
        final logsToRollback = supplementProvider.history.where((h) => h.sourceId == logId).toList();
        for (var entry in logsToRollback) { supplementProvider.removeSupplementItem(entry.id); }
        provider.deleteLog(logId);
      },
    );
  }
}

class _SupplementLogSection extends StatelessWidget {
  const _SupplementLogSection();
  @override
  Widget build(BuildContext context) {
    return Consumer<SupplementProvider>(
      builder: (context, provider, _) {
        final pinned = provider.pinnedSupplements;
        if (pinned.isEmpty) return const SizedBox.shrink();
        List<Widget> cards = [];
        for (var item in pinned) {
          if (item.pinnedIntakeAmount > 0) cards.add(QuickLogCard(item: item, isRestock: false, onTap: () {
            provider.quickLogIntakeOnly(item.id);
            EliteSnackbar.show(context, "${item.name} RECORDED", onUndo: () => provider.deleteLastEntry());
          }));
          if (item.pinnedRestockAmount > 0) cards.add(QuickLogCard(item: item, isRestock: true, onTap: () {
            provider.quickLogRestockOnly(item.id);
            EliteSnackbar.show(context, "${item.name} RESTOCKED", onUndo: () => provider.deleteLastEntry());
          }));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("SUPPLEMENT QUICK LOG", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 2.0, fontSize: 12.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 12.r),
            SizedBox(
              height: 160.r, 
              child: ListView(
                scrollDirection: Axis.horizontal, 
                physics: const ClampingScrollPhysics(),
                children: cards,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StackLogSection extends StatelessWidget {
  const _StackLogSection();
  @override
  Widget build(BuildContext context) {
    return Consumer<SupplementProvider>(
      builder: (context, provider, _) {
        final pinnedStacks = provider.pinnedStacks;
        if (pinnedStacks.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("STACK QUICK LOG", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 2.0, fontSize: 12.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 12.r),
            SizedBox(
              height: 165.r,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, 
                physics: const ClampingScrollPhysics(),
                itemCount: pinnedStacks.length, 
                itemBuilder: (context, index) => StackQuickLogCard(stack: pinnedStacks[index], onTap: () {
                  provider.quickLogStack(pinnedStacks[index].id);
                  EliteSnackbar.show(context, "${pinnedStacks[index].name} LOGGED", onUndo: () => provider.deleteLastEntry());
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}
