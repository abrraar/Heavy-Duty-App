// lib/features/tracker/supplement/presentation/screens/supplement_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/features/main_wrapper.dart';
import 'package:heavy_duty/features/tracker/supplement/widgets/cards/supplement_item_card.dart';
import 'package:heavy_duty/features/tracker/supplement/widgets/cards/library_card.dart';
import 'package:heavy_duty/features/tracker/supplement/widgets/cards/stacker_card.dart';
import 'package:heavy_duty/features/tracker/supplement/widgets/sheets/intake_sheet.dart';
import 'package:heavy_duty/features/tracker/supplement/widgets/sheets/notification_sheet.dart';
import 'package:heavy_duty/features/tracker/supplement/widgets/sheets/quick_log_sheet.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:heavy_duty/features/tracker/supplement/widgets/sheets/stack_form_sheet.dart';
import 'package:heavy_duty/features/tracker/supplement/widgets/sheets/supplement_form_sheet.dart';

import 'package:heavy_duty/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';

import '../calorie/provider/calorie_provider.dart';
import 'model/supplement.dart';
import 'provider/supplement_provider.dart';
import 'widgets/cards/tracker_card.dart';

class _HistoryFilter {
  bool isDescending;
  String searchQuery;
  String type; // "ALL", "INTAKE", "RESTOCK"
  Set<String> sources; // "MEAL", "QUICK", "STACK", "NOTIF", "MANUAL"

  _HistoryFilter({
    this.isDescending = true,
    this.searchQuery = "",
    this.type = "ALL",
    Set<String>? sources,
  }) : sources = sources ?? {"MEAL", "QUICK", "STACK", "NOTIF", "MANUAL"};

  bool get isInitial =>
      isDescending &&
      searchQuery.isEmpty &&
      type == "ALL" &&
      sources.length == 5;

  _HistoryFilter copyWith({
    bool? isDescending,
    String? searchQuery,
    String? type,
    Set<String>? sources,
  }) {
    return _HistoryFilter(
      isDescending: isDescending ?? this.isDescending,
      searchQuery: searchQuery ?? this.searchQuery,
      type: type ?? this.type,
      sources: sources ?? this.sources,
    );
  }
}

class SupplementScreen extends StatefulWidget {
  final int initialTabIndex;
  const SupplementScreen({super.key, this.initialTabIndex = 0});

  @override
  State<SupplementScreen> createState() => _SupplementScreenState();
}

class _SupplementScreenState extends State<SupplementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  final TextEditingController _searchController = TextEditingController();

  _HistoryFilter _historyFilter = _HistoryFilter();

  DateTime _selectedHistoryDate = DateTime.now();
  DateTime _displayedMonth = DateTime.now();
  bool _isCalendarExpanded = false;

  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "supplement";
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: null,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(left: 8.w, right: 8.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: IntrinsicHeight(
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
                            'SUPPLEMENT TRACKER',
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
                            icon: Icon(Icons.arrow_back_ios_new_rounded),
                            onPressed: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  indicatorColor: AppColors.crimson,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 3,
                  labelPadding: EdgeInsets.zero,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                  unselectedLabelColor: AppColors.textSecondary.withOpacity(
                    0.4,
                  ),
                  labelColor: AppColors.crimson,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: "TRACKER"),
                    Tab(text: "STACKER"),
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
                _buildStackerTab(),
                _buildLibraryTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB BUILDERS ---

  Widget _buildTrackerTab() {
    return Consumer<SupplementProvider>(
      builder: (context, provider, _) {
        final active = provider.activeSupplements;
        if (active.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.forceRefresh(),
            color: AppColors.crimson,
            backgroundColor: AppColors.surface,
            child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Container(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildEmptyState("NO ACTIVE SUPPLEMENTS"),
                          SizedBox(height: 16.h),
                          GestureDetector(
                            onTap: () => _tabController.animateTo(2),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24.w,
                                vertical: 12.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.crimson.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: AppColors.crimson),
                              ),
                              child: Text(
                                "OPEN LIBRARY",
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.crimson,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(20.r),
            itemCount: active.length,
            itemBuilder: (context, index) => TrackerCard(
              supplement: active[index],
              onLogTap: () => _openIntakeSheet(context, active[index]),
              onNotificationTap: () =>
                  _openNotificationSheet(context, active[index]),
              onQuickLogTap: () => _openQuickLogSheet(context, active[index]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStackerTab() {
    return Consumer<SupplementProvider>(
      builder: (context, provider, _) {
        final activeCount = provider.activeSupplements.length;
        final stacks = provider.supplementStacks;

        return RefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: Column(
            children: [
              Expanded(
                child: stacks.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Container(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.layers_rounded,
                                      size: 48.r,
                                      color: AppColors.textSecondary.withOpacity(0.3),
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      "SUPPLEMENT STACKING",
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.h3.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 40.w,
                                        vertical: 8.h,
                                      ),
                                      child: Text(
                                        activeCount < 2
                                            ? "Activate at least 2 supplements from your library to create a stack."
                                            : "Bundle your active supplements for faster logging.",
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.textSecondary.withOpacity(0.6),
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(20.r),
                        itemCount: stacks.length,
                        itemBuilder: (context, index) {
                          final stack = stacks[index];
                          return StackerCard(stack: stack);
                        },
                      ),
              ),
              if (activeCount >= 2)
                _buildActionBtn(
                  "CREATE NEW STACK",
                  () => _openStackFormSheet(context),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLibraryTab() {
    return Consumer<SupplementProvider>(
      builder: (context, provider, _) {
        if (provider.library.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.forceRefresh(),
            color: AppColors.crimson,
            backgroundColor: AppColors.surface,
            child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Container(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildEmptyState("YOUR LIBRARY IS EMPTY"),
                          SizedBox(height: 12.h),
                          Text(
                            "Click the button below to add your first supplement",
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary.withOpacity(0.6),
                              fontSize: 12.sp,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          Icon(
                            Icons.arrow_downward_rounded,
                            color: AppColors.crimson.withOpacity(0.5),
                            size: 24.r,
                          ),
                          _buildActionBtn(
                            "CREATE NEW SUPPLEMENT",
                            () => _openFormSheet(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(20.r),
                  itemCount: provider.library.length,
                  itemBuilder: (context, index) {
                    final item = provider.library[index];
                    return LibraryCard(
                      item: item,
                      provider: provider,
                      index: index,
                      onEdit: () {
                        _openFormSheet(context, existingItem: item, index: index);
                      },
                      onDelete: () async {
                        final confirmed = await _showDeletePrompt(
                          context,
                          item.name,
                        );
                        if (confirmed == true) {
                          final calorieProvider = context.read<CalorieProvider>();
                          provider.deleteSupplement(
                            item.id,
                            onDeactivated: (id, cals, pro, cho, fat) {
                              calorieProvider.removeSupplementFromAllMeals(id, cals, pro, cho, fat);
                            }
                          );
                        }
                      },
                    );
                  },
                ),
              ),
              _buildActionBtn(
                "CREATE NEW SUPPLEMENT",
                () => _openFormSheet(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return Consumer<SupplementProvider>(
      builder: (context, provider, _) {
        final Set<DateTime> dateSet = provider.history.map((h) => 
          DateTime(h.timestamp.year, h.timestamp.month, h.timestamp.day)
        ).toSet();
        
        final now = DateTime.now();
        dateSet.add(DateTime(now.year, now.month, now.day));

        var displayedHistory = provider.history.where((h) {
          final bool matchesDate = h.timestamp.year == _selectedHistoryDate.year &&
                 h.timestamp.month == _selectedHistoryDate.month &&
                 h.timestamp.day == _selectedHistoryDate.day;
          if (!matchesDate) return false;

          if (_historyFilter.searchQuery.isNotEmpty) {
            if (!h.supplementName.toLowerCase().contains(_historyFilter.searchQuery.toLowerCase())) {
              return false;
            }
          }

          if (_historyFilter.type != "ALL") {
            if (h.type.toUpperCase() != _historyFilter.type) return false;
          }

          final String details = h.details.toUpperCase();
          String source = "MANUAL";
          if (details.startsWith("MEAL LOG:")) source = "MEAL";
          else if (details.contains("NOTIFICATION")) source = "NOTIF";
          else if (details.contains("QUICK LOG") || details.contains("QUICK RESTOCK")) source = "QUICK";
          else if (details.contains("STACK LOG")) source = "STACK";

          if (!_historyFilter.sources.contains(source)) return false;

          return true;
        }).toList();

        displayedHistory.sort((a, b) {
          return _historyFilter.isDescending
              ? b.timestamp.compareTo(a.timestamp)
              : a.timestamp.compareTo(b.timestamp);
        });

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
              child: RefreshIndicator(
                onRefresh: () => provider.forceRefresh(),
                color: AppColors.crimson,
                backgroundColor: AppColors.surface,
                child: Column(
                  children: [
                    _buildHistoryHeader(provider),
                    Expanded(
                      child: displayedHistory.isEmpty
                          ? LayoutBuilder(
                              builder: (context, constraints) => ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  Container(
                                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                    child: Center(
                                      child: _buildEmptyState("No records for this date."),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.all(20.r),
                              itemCount: displayedHistory.length,
                              itemBuilder: (context, index) {
                                final entry = displayedHistory[index];
                                return Dismissible(
                                  key: Key("hist_${entry.id}"),
                                  direction: DismissDirection.endToStart,
                                  background: _buildSwipeBg(
                                    AppColors.error,
                                    Icons.delete_outline_rounded,
                                    Alignment.centerRight,
                                  ),
                                  confirmDismiss: (_) async {
                                    final bool? didConfirm = await _showDeletePrompt(
                                      context,
                                      "ENTRY: ${entry.supplementName.toUpperCase()}",
                                    );
                                    return didConfirm ?? false;
                                  },
                                  onDismissed: (_) {
                                    final calorieProvider = context.read<CalorieProvider>();
                                    
                                    provider.removeSupplementItem(
                                      entry.id, 
                                      onSourceRollback: (sourceId, suppId, amount) {
                                        final mealLogIndex = calorieProvider.logs.indexWhere((l) => l.id == sourceId);
                                        if (mealLogIndex != -1) {
                                          final log = calorieProvider.logs[mealLogIndex];
                                          final supplement = provider.library.firstWhere((s) => s.id == suppId, orElse: () => null as dynamic);
                                          
                                          if (supplement != null) {
                                            final bool isStandaloneLog = entry.details.contains("| SUPPLEMENT |");
                                            final bool isStackLog = entry.details.contains("| STACK: ");
                                            
                                            String? targetStackId;
                                            if (isStackLog) {
                                               final parts = entry.details.split('|');
                                               if (parts.length > 1) {
                                                  final stackName = parts[1].replaceAll("STACK:", "").trim();
                                                  try {
                                                     targetStackId = provider.supplementStacks.firstWhere(
                                                        (s) => s.name.toUpperCase() == stackName.toUpperCase()
                                                     ).id;
                                                  } catch (_) {}
                                               }
                                            }

                                            final double rollbackCals = ((supplement.caloriesPerUnit ?? 0.0) * amount);
                                            final double rollbackPro = (supplement.proteinPerUnit ?? 0.0) * amount;
                                            final double rollbackCho = (supplement.carbsPerUnit ?? 0.0) * amount;
                                            final double rollbackFat = (supplement.fatsPerUnit ?? 0.0) * amount;

                                            String? newSuppsJson = log.addedSupplementsJson;
                                            String? newStacksJson = log.addedStacksJson;

                                            if (isStandaloneLog && newSuppsJson != null) {
                                              try {
                                                List<dynamic> list = jsonDecode(newSuppsJson);
                                                list.removeWhere((item) => ((item is Map) ? item['id'] : item) == suppId);
                                                newSuppsJson = list.isEmpty ? null : jsonEncode(list);
                                              } catch (_) {}
                                            }

                                            if (isStackLog && newStacksJson != null) {
                                              try {
                                                List<dynamic> stacksList = jsonDecode(newStacksJson);
                                                final List<dynamic> updatedStacksList = [];

                                                for (var stackEntry in stacksList) {
                                                   if (stackEntry is Map && stackEntry['itemAmounts'] is Map) {
                                                      final String sId = stackEntry['id'];
                                                      if (targetStackId == null || sId == targetStackId) {
                                                         Map<String, dynamic> itemAmounts = Map<String, dynamic>.from(stackEntry['itemAmounts']);
                                                         if (itemAmounts.containsKey(suppId)) {
                                                            itemAmounts.remove(suppId);
                                                            if (itemAmounts.isNotEmpty) {
                                                               final newEntry = Map<String, dynamic>.from(stackEntry);
                                                               newEntry['itemAmounts'] = itemAmounts;
                                                               updatedStacksList.add(newEntry);
                                                            }
                                                            continue;
                                                         }
                                                      }
                                                   }
                                                   updatedStacksList.add(stackEntry);
                                                }
                                                newStacksJson = updatedStacksList.isEmpty ? null : jsonEncode(updatedStacksList);
                                              } catch (_) {}
                                            }

                                            final double? newPro = log.protein != null ? (log.protein! - rollbackPro).clamp(0, 1000) : null;
                                            final double? newCarbs = log.carbs != null ? (log.carbs! - rollbackCho).clamp(0, 1000) : null;
                                            final double? newFats = log.fats != null ? (log.fats! - rollbackFat).clamp(0, 1000) : null;

                                            calorieProvider.addLog(log.copyWith(
                                              calories: (log.calories - rollbackCals).clamp(0.0, 9999.999),
                                              protein: newPro != null && newPro > 0 ? newPro : null,
                                              carbs: newCarbs != null && newCarbs > 0 ? newCarbs : null,
                                              fats: newFats != null && newFats > 0 ? newFats : null,
                                              addedSupplementsJson: newSuppsJson,
                                              clearSupplements: newSuppsJson == null,
                                              addedStacksJson: newStacksJson,
                                              clearStacks: newStacksJson == null,
                                            ));
                                          }
                                        }
                                      }
                                    );
                                  },
                                  child: SupplementItemCard(entry: entry),
                                );
                              },
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

  // --- SHEET OPENERS ---

  void _openStackFormSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const StackFormSheet(),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openIntakeSheet(BuildContext context, Supplement supp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => IntakeSheet(
        supplement: supp,
        onConfirm:
            ({
              required bool recordIntake,
              required bool restockInventory,
              required double intakeVal,
              required double restockVal,
              required bool useServingsForIntake,
              required bool useServingsForRestock,
              required DateTime selectedTimestamp,
            }) {
              final provider = context.read<SupplementProvider>();

              double intakeWeight = useServingsForIntake
                  ? (intakeVal * supp.weightPerServing)
                  : intakeVal;

              double restockWeight = useServingsForRestock
                  ? (restockVal * supp.weightPerServing)
                  : restockVal;

              if (recordIntake) {
                provider.recordEntry(
                  supplement: supp,
                  isIntake: true,
                  isRestock: false,
                  weightAdjustment: -intakeWeight,
                  historyDetails:
                      "Intake: $intakeVal ${useServingsForIntake ? supp.servingUnit : supp.weightUnit}",
                  timestamp: selectedTimestamp,
                );
              }

              if (restockInventory) {
                provider.recordEntry(
                  supplement: supp,
                  isIntake: false,
                  isRestock: true,
                  weightAdjustment: restockWeight,
                  historyDetails:
                      "Restock: $restockVal ${useServingsForRestock ? supp.servingUnit : supp.weightUnit}",
                  timestamp: selectedTimestamp,
                );
              }

              if (mounted) {
                String msg = "${supp.name} RECORDED";
                if (restockInventory && !recordIntake) msg = "${supp.name} RESTOCKED";
                if (restockInventory && recordIntake) msg = "${supp.name} UPDATED";

                EliteSnackbar.show(
                  context, 
                  msg, 
                  onUndo: () => provider.deleteLastEntry()
                );
              }

              Navigator.pop(sheetContext);
            },
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openFormSheet(
    BuildContext context, {
    Supplement? existingItem,
    int? index,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SupplementFormSheet(
        existingItem: existingItem,
        index: index,
        onSave: (item, idx) => context
            .read<SupplementProvider>()
            .addOrUpdateSupplement(item, index: idx),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openNotificationSheet(BuildContext context, Supplement supp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => NotificationSheet(
        supplement: supp,
        initialReminders: supp.reminders,
        initialEnabled: supp.notificationsEnabled,
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openQuickLogSheet(BuildContext context, Supplement supp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (sheetContext) => QuickLogSheet(
        supplement: supp,
        onSave:
            ({
              required bool isPinned,
              required double intakeVal,
              required bool useServingsIntake,
              required double restockVal,
              required bool useServingsRestock,
            }) {
              context.read<SupplementProvider>().updateShortcutSettings(
                id: supp.id,
                isPinned: isPinned,
                intakeAmount: intakeVal,
                useServingsIntake: useServingsIntake,
                restockAmount: restockVal,
                useServingsRestock: useServingsRestock,
              );
            },
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  // --- SHARED UI HELPERS ---

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

  Widget _buildHistoryHeader(SupplementProvider provider) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.r, 0, 20.r, 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSectionHeader("SUPPLEMENT HISTORY"),
          IconButton(
            onPressed: () => _openFilterSheet(provider),
            icon: Icon(
              _historyFilter.isInitial 
                  ? Icons.filter_list_rounded 
                  : Icons.filter_list_off_rounded,
              color: _historyFilter.isInitial ? AppColors.crimson : Colors.orangeAccent,
              size: 20.r,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Filter History",
          ),
        ],
      ),
    );
  }

  void _openFilterSheet(SupplementProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SupplementHistoryFilterSheet(
        initialFilter: _historyFilter,
        onApply: (newFilter) => setState(() => _historyFilter = newFilter),
      ),
    );
  }

  Future<bool?> _showDeletePrompt(BuildContext context, String title) {
    return EliteConfirmDialog.show(
      context,
      title: "DELETE ${title.toUpperCase()}",
      message: "Are you sure you want to permanently delete this item? This action cannot be undone.",
    );
  }

  Widget _buildSwipeBg(Color c, IconData i, Alignment a) => Container(
    margin: EdgeInsets.only(bottom: 12.h),
    padding: EdgeInsets.symmetric(horizontal: 24.w),
    alignment: a,
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16.r),
    ),
    child: Icon(i, color: c, size: 28.r),
  );

  Widget _buildEmptyState(String m) => Center(
    child: Text(
      m,
      textAlign: TextAlign.center,
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textSecondary,
        fontSize: 14.sp,
      ),
    ),
  );

  Widget _buildActionBtn(String l, VoidCallback o) => Padding(
    padding: EdgeInsets.all(20.r),
    child: GestureDetector(
      onTap: o,
      child: Container(
        height: 56.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.crimson.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.crimson),
        ),
        alignment: Alignment.center,
        child: Text(
          l,
          style: AppTextStyles.buttonPrimary.copyWith(
            color: AppColors.crimson,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
}

class _SupplementHistoryFilterSheet extends StatefulWidget {
  final _HistoryFilter initialFilter;
  final Function(_HistoryFilter) onApply;

  const _SupplementHistoryFilterSheet({
    required this.initialFilter,
    required this.onApply,
  });

  @override
  State<_SupplementHistoryFilterSheet> createState() => _SupplementHistoryFilterSheetState();
}

class _SupplementHistoryFilterSheetState extends State<_SupplementHistoryFilterSheet> {
  late _HistoryFilter _currentFilter;

  @override
  void initState() {
    super.initState();
    _currentFilter = _HistoryFilter(
      isDescending: widget.initialFilter.isDescending,
      searchQuery: widget.initialFilter.searchQuery,
      type: widget.initialFilter.type,
      sources: Set<String>.from(widget.initialFilter.sources),
    );
  }

  void _updateFilter(_HistoryFilter newFilter) {
    setState(() => _currentFilter = newFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 40.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 24.h),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("HISTORY FILTERS", style: AppTextStyles.h3),
              TextButton(
                onPressed: () => setState(() => _currentFilter = _HistoryFilter()),
                child: Text(
                  "RESET",
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.crimson,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          _buildSectionLabel("SORT ORDER"),
          Row(
            children: [
              _buildToggleButton(
                label: "NEWEST FIRST",
                isSelected: _currentFilter.isDescending,
                onTap: () => _updateFilter(_currentFilter.copyWith(isDescending: true)),
              ),
              SizedBox(width: 12.w),
              _buildToggleButton(
                label: "OLDEST FIRST",
                isSelected: !_currentFilter.isDescending,
                onTap: () => _updateFilter(_currentFilter.copyWith(isDescending: false)),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          _buildSectionLabel("RECORD TYPE"),
          Row(
            children: [
              _buildToggleButton(
                label: "ALL",
                isSelected: _currentFilter.type == "ALL",
                onTap: () => _updateFilter(_currentFilter.copyWith(type: "ALL")),
              ),
              SizedBox(width: 8.w),
              _buildToggleButton(
                label: "INTAKE",
                isSelected: _currentFilter.type == "INTAKE",
                onTap: () => _updateFilter(_currentFilter.copyWith(type: "INTAKE")),
              ),
              SizedBox(width: 8.w),
              _buildToggleButton(
                label: "RESTOCK",
                isSelected: _currentFilter.type == "RESTOCK",
                onTap: () => _updateFilter(_currentFilter.copyWith(type: "RESTOCK")),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          _buildSectionLabel("SOURCE FILTERS"),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildSourceChip("MEAL", "MEAL LOGS"),
              _buildSourceChip("NOTIF", "NOTIFICATIONS"),
              _buildSourceChip("QUICK", "QUICK LOGS"),
              _buildSourceChip("STACK", "STACK LOGS"),
              _buildSourceChip("MANUAL", "MANUAL ENTRY"),
            ],
          ),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_currentFilter);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.crimson,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                "APPLY FILTERS",
                style: AppTextStyles.buttonPrimary.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary.withOpacity(0.5),
          letterSpacing: 1.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildToggleButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.crimson.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected ? AppColors.crimson : AppColors.white.withOpacity(0.1),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? AppColors.crimson : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceChip(String source, String label) {
    final bool isSelected = _currentFilter.sources.contains(source);
    return GestureDetector(
      onTap: () {
        final sources = Set<String>.from(_currentFilter.sources);
        if (isSelected) {
          sources.remove(source);
        } else {
          sources.add(source);
        }
        _updateFilter(_currentFilter.copyWith(sources: sources));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? AppColors.crimson : AppColors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: isSelected ? AppColors.crimson : AppColors.textSecondary,
            fontSize: 10.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
